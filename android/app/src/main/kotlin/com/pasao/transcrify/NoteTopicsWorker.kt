package com.pasao.transcrify

import android.app.ActivityManager
import android.content.Context
import com.pasao.transcrify.engine.Embedder
import com.pasao.transcrify.engine.Engine
import com.pasao.transcrify.engine.Keywords
import com.pasao.transcrify.engine.OnnxEmbedder
import com.pasao.transcrify.engine.SentenceStore
import com.pasao.transcrify.engine.XxHash64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Gli argomenti delle note, calcolati sul telefono. Un thread solo, in fondo, mai sull'interfaccia.
 *
 * Una nota si elabora quando la salvi (il tuo «commit»), e tutte quelle non ancora fatte quando
 * il modello è pronto. Il risultato si ricorda con l'impronta del testo: se la nota non è cambiata
 * non si rifà niente; se è cambiata, al modello vanno solo le frasi nuove (le altre sono su disco).
 *
 * Il modello si carica quando serve e si libera appena la coda è vuota: occupa memoria solo
 * mentre lavora. Gli album tra le note si ricostruiscono all'avvio dalle frasi già capite, senza modello.
 */
class NoteTopicsWorker private constructor(context: Context) {
    private val app = context.applicationContext
    private val store = Store(app)
    private val models = TopicModels(app)
    // v2: con le grane relative e le parole chiave. I risultati di prima si rifanno.
    private val file = File(app.filesDir, "note_topics_v2.json")
    private val exec = Executors.newSingleThreadExecutor { r -> Thread(r, "argomenti").apply { priority = Thread.MIN_PRIORITY } }

    /** Le note in coda o in lavorazione. */
    private val pending: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** Chi vuole sapere quando una nota è pronta (l'app, per rileggere). */
    @Volatile var listener: (() -> Unit)? = null

    /** Il risultato di una nota: per quale testo e con quale modello, dove sono le frasi, le grane, le parole chiave. */
    private class Result(val model: String, val hash: Long, val spans: IntArray, val wide: IntArray, val medium: IntArray, val keywords: IntArray) {
        fun toJson(): JSONObject = JSONObject()
            .put("model", model).put("hash", hash)
            .put("spans", JSONArray(spans.toList()))
            .put("wide", JSONArray(wide.toList()))
            .put("medium", JSONArray(medium.toList()))
            .put("keywords", JSONArray(keywords.toList()))

        companion object {
            fun fromJson(j: JSONObject): Result {
                fun ints(name: String) = j.optJSONArray(name)?.let { a -> IntArray(a.length()) { a.getInt(it) } } ?: IntArray(0)
                return Result(j.getString("model"), j.getLong("hash"), ints("spans"), ints("wide"), ints("medium"), ints("keywords"))
            }
        }
    }

    private val results: MutableMap<String, Result> = ConcurrentHashMap(load())

    // Tutto quello che segue vive nel thread del lavoro.
    private var engine: Engine? = null
    private var engineModel: TopicModel? = null
    private var embedder: OnnxEmbedder? = null
    private val keywords = Keywords()

    /** Gli album pronti da mostrare (copiati dal thread del lavoro: l'app li legge quando vuole). */
    @Volatile private var albumsSnapshot: List<Map<String, Any>> = emptyList()

    init {
        // Appena un modello finisce di scaricarsi, si fanno le note che aspettano.
        TopicModels.onReady = { requestAll() }
        // All'avvio: le parole e gli album delle note già fatte, dalle frasi su disco.
        exec.execute { warm() }
    }

    /** Quanta memoria ha il telefono, in GB: sotto i 6 il modello più preciso può essere lento. */
    val ramGb: Double by lazy {
        val info = ActivityManager.MemoryInfo()
        (app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info)
        info.totalMem / 1e9
    }

    /** Come sta la nota, per l'indicatore nella lista: "off", "pending", "ready" o "stale" (cambiata, da rifare). */
    fun state(id: String, text: String): String {
        val m = models.chosen ?: return "off"
        if (!models.ready(m)) return "off"
        if (id in pending) return "pending"
        val r = results[id] ?: return "stale"
        return if (r.model == m.id && r.hash == hash(text)) "ready" else "stale"
    }

    /** Gli argomenti di una nota per l'app. null se non sono pronti per il testo che ha adesso. */
    fun topics(id: String): Map<String, Any>? {
        val note = store.notes().firstOrNull { it.id == id } ?: return null
        if (state(id, note.text) != "ready") return null
        val r = results.getValue(id)
        return mapOf("spans" to r.spans.toList(), "wide" to r.wide.toList(), "medium" to r.medium.toList(), "keywords" to r.keywords.toList())
    }

    /** Gli album: argomenti che tornano in più pezzi, con un nome fatto delle loro parole chiave. */
    fun albums(): List<Map<String, Any>> = albumsSnapshot

    fun request(id: String) {
        if (!pending.add(id)) return
        exec.execute { work(id) }
    }

    /** Tutte le note non ancora fatte (o cambiate): dopo aver scelto il modello, o all'avvio. */
    fun requestAll() {
        val m = models.chosen ?: return
        if (!models.ready(m)) return
        for (n in store.notes()) if (state(n.id, n.text) == "stale") request(n.id)
    }

    fun forget(id: String) {
        exec.execute {
            engine?.forget(id)
            keywords.forget(id)
            if (results.remove(id) != null) save()
            snapshotAlbums()
            listener?.invoke()
        }
    }

    // --- nel thread del lavoro ---

    private fun warm() {
        val m = models.chosen ?: return
        if (!models.ready(m)) return
        for (n in store.notes()) {
            val r = results[n.id] ?: continue
            if (r.model != m.id || r.hash != hash(n.text)) continue
            keywords.update(n.id, n.text)
            // Le frasi sono già su disco: niente modello, solo somme e confini.
            runCatching { engineFor(m).commit(n.id, n.text) }
        }
        release()
        snapshotAlbums()
        listener?.invoke()
    }

    private fun work(id: String) {
        try {
            val m = models.chosen ?: return
            if (!models.ready(m)) return
            val note = store.notes().firstOrNull { it.id == id } ?: return
            val h = hash(note.text)
            val old = results[id]
            if (old != null && old.model == m.id && old.hash == h) return
            val t = engineFor(m).commit(id, note.text)
            keywords.update(id, note.text)
            val spans = IntArray(t.sentences.size * 2).also { a -> t.sentences.forEachIndexed { i, s -> a[2 * i] = s.start; a[2 * i + 1] = s.end } }
            results[id] = Result(m.id, h, spans, t.segmentation.levelCuts(1, m.profile), t.segmentation.levelCuts(2, m.profile), keywords.ranges(note.text))
            save()
            snapshotAlbums()
        } catch (_: Throwable) {
            // Un modello che non si carica (memoria, file rovinato) non deve far cadere l'app: la nota resta senza argomenti.
        } finally {
            pending.remove(id)
            if (pending.isEmpty()) release()
            listener?.invoke()
        }
    }

    /** Gli album da mostrare, con i loro pezzi come intervalli di caratteri nelle note. */
    private fun snapshotAlbums() {
        val e = engine ?: return run { albumsSnapshot = emptyList() }
        val notes = store.notes().associateBy { it.id }
        albumsSnapshot = e.topics.shown().mapNotNull { (album, members) ->
            val pieces = members.mapNotNull { pid ->
                val (noteId, range) = e.piece(pid) ?: return@mapNotNull null
                val r = results[noteId] ?: return@mapNotNull null
                val note = notes[noteId] ?: return@mapNotNull null
                if (range.last * 2 + 1 >= r.spans.size) return@mapNotNull null
                Triple(note, r.spans[range.first * 2], r.spans[range.last * 2 + 1])
            }
            // Un album fatto di pezzi di una nota sola non è «ne hai parlato tre volte»: è una nota lunga.
            if (pieces.map { it.first.id }.distinct().size < 2) return@mapNotNull null
            val text = pieces.joinToString("\n") { (n, a, b) -> n.text.substring(a, b) }
            val name = keywords.top(text, 2).joinToString(" · ") { it.replaceFirstChar(Char::uppercase) }
            mapOf(
                "id" to album,
                "name" to name.ifEmpty { "Senza nome" },
                "pieces" to pieces.map { (n, a, b) -> mapOf("note" to n.id, "start" to a, "end" to b) },
            )
        }
    }

    /** Il motore del modello scelto, con le sue frasi su disco. Se il modello cambia si ricomincia: i vettori di modelli diversi non si mescolano. */
    private fun engineFor(m: TopicModel): Engine {
        engine?.takeIf { engineModel == m }?.let { return it }
        release()
        val disk = SentenceStore(File(models.dir(m), "frasi.bin"), m.embedding.dim)
        val lazy = object : Embedder {
            override val dim = m.embedding.dim
            override fun embed(sentences: List<String>): List<FloatArray> =
                (embedder ?: OnnxEmbedder(models.dir(m), m).also { embedder = it }).embed(sentences)
        }
        return Engine(lazy, m.profile, memory = disk.load(), learned = disk::append).also {
            engine = it
            engineModel = m
        }
    }

    /** Libera il modello (la memoria grande); il motore resta, con le frasi già capite. */
    private fun release() {
        embedder?.close()
        embedder = null
    }

    private fun hash(text: String) = XxHash64.hash(text.toByteArray(Charsets.UTF_8), 7)

    private fun load(): Map<String, Result> = try {
        val j = JSONObject(file.readText())
        j.keys().asSequence().associateWith { Result.fromJson(j.getJSONObject(it)) }
    } catch (_: Exception) {
        emptyMap()
    }

    private fun save() {
        val j = JSONObject()
        for ((id, r) in results) j.put(id, r.toJson())
        val tmp = File(file.parentFile, "note_topics_v2.tmp")
        tmp.writeText(j.toString())
        tmp.renameTo(file)
    }

    companion object {
        @Volatile private var instance: NoteTopicsWorker? = null

        fun get(context: Context): NoteTopicsWorker =
            instance ?: synchronized(this) { instance ?: NoteTopicsWorker(context).also { instance = it } }
    }
}
