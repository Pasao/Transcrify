package com.pasao.transcrify

import android.app.ActivityManager
import android.content.Context
import com.pasao.transcrify.engine.Categorie
import com.pasao.transcrify.engine.Embedder
import com.pasao.transcrify.engine.Engine
import com.pasao.transcrify.engine.Keywords
import com.pasao.transcrify.engine.OnnxEmbedder
import com.pasao.transcrify.engine.Parole
import com.pasao.transcrify.engine.Sentences
import com.pasao.transcrify.engine.Span
import com.pasao.transcrify.engine.Trovato
import com.pasao.transcrify.engine.SentenceStore
import com.pasao.transcrify.engine.XxHash64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

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
    // v4: parole chiave di più parole. I risultati di prima si rifanno.
    private val file = File(Sandbox.dir(app), "note_topics_v4.json")
    private val exec = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "argomenti").apply { priority = Thread.MIN_PRIORITY } }

    /** Il testo di ogni trascrizione già nella ricerca (per quale impronta): una cambiata si rifà. */
    private val trascrizioniFatte = HashMap<Long, Long>()

    /** Quando è arrivata l'ultima ricerca: il modello resta caricato un minuto, per le lettere che seguono. */
    @Volatile private var ultimaDomanda = 0L

    /** Le note in coda o in lavorazione. */
    private val pending: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** Chi vuole sapere quando una nota è pronta (l'app, per rileggere). */
    @Volatile var listener: (() -> Unit)? = null

    /** Il risultato di una nota: per quale testo e con quale modello, dove sono le frasi, le grane, le parole chiave. */
    private class Result(
        val model: String,
        val hash: Long,
        val spans: IntArray,
        val wide: IntArray,
        val medium: IntArray,
        val keys: IntArray,
        val keywords: IntArray,
    ) {
        fun toJson(): JSONObject = JSONObject()
            .put("model", model).put("hash", hash)
            .put("spans", JSONArray(spans.toList()))
            .put("wide", JSONArray(wide.toList()))
            .put("medium", JSONArray(medium.toList()))
            .put("keys", JSONArray(keys.toList()))
            .put("keywords", JSONArray(keywords.toList()))

        companion object {
            fun fromJson(j: JSONObject): Result {
                fun ints(name: String) = j.optJSONArray(name)?.let { a -> IntArray(a.length()) { a.getInt(it) } } ?: IntArray(0)
                return Result(j.getString("model"), j.getLong("hash"), ints("spans"), ints("wide"), ints("medium"), ints("keys"), ints("keywords"))
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
    @Volatile private var categorieSnapshot: List<Map<String, Any>> = emptyList()

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
        return mapOf(
            "spans" to r.spans.toList(),
            "wide" to r.wide.toList(),
            "medium" to r.medium.toList(),
            "keys" to r.keys.toList(),
            "keywords" to r.keywords.toList(),
        )
    }

    /** Gli album: argomenti che tornano in più pezzi, con un nome fatto delle loro parole chiave. */
    fun albums(): List<Map<String, Any>> = albumsSnapshot

    /** Le categorie fisse con le frasi chiave dei pezzi che ci stanno dentro, dalla più piena. */
    fun categorie(): List<Map<String, Any>> = categorieSnapshot

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

    /** Le trascrizioni nuove o cambiate entrano nella ricerca, quelle eliminate escono. In fondo, come le note. */
    fun requestTrascrizioni() {
        exec.execute { indicizzaTrascrizioni(); liberaSeFermo() }
    }

    /**
     * Cerca nelle note e nelle trascrizioni: prima quelle con tutte le parole, poi quelle vicine per senso.
     * Senza modello pronto, solo per parola. [risposta] arriva dal thread del lavoro.
     */
    fun cerca(testo: String, risposta: (List<Map<String, Any>>) -> Unit) {
        ultimaDomanda = System.currentTimeMillis()
        exec.execute {
            val out = try { trova(testo) } catch (_: Throwable) { emptyList() }
            risposta(out)
            exec.schedule({ liberaSeFermo() }, ATTESA_MODELLO, TimeUnit.MILLISECONDS)
        }
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

    private fun trova(testo: String): List<Map<String, Any>> {
        val parole = Parole.di(testo)
        if (parole.isEmpty()) return emptyList()
        val note = store.notes()
        val trascrizioni = store.history()
        val testi = HashMap<String, String>()
        for (n in note) testi[Engine.FONTE_NOTA + n.id] = n.title + "\n" + n.text
        for (t in trascrizioni) testi[Engine.FONTE_TRASCRIZIONE + t.at] = t.text
        // Per parola: dalla più recente, la frase dove compare la prima parola.
        val esatti = (note.map { Engine.FONTE_NOTA + it.id } + trascrizioni.map { Engine.FONTE_TRASCRIZIONE + it.at }).mapNotNull { f ->
            val t = testi.getValue(f)
            val i = Parole.trova(t, parole) ?: return@mapNotNull null
            Trovato(f, Sentences.split(t).firstOrNull { i < it.end } ?: Span(0, t.length), 1f, esatto = true)
        }
        val m = models.chosen
        val perSenso = if (m != null && models.ready(m)) {
            val e = engineFor(m)
            // Le trascrizioni nuove o cambiate da quando si è cercato l'ultima volta: di solito nessuna.
            indicizzaTrascrizioni()
            val visti = esatti.map { it.fonte }.toHashSet()
            e.ricerca.cerca(e.domanda(testo), RISULTATI, m.profile.cercaMinimo, m.profile.cercaBanda).filter { it.fonte !in visti }
        } else emptyList()
        return (esatti + perSenso).mapNotNull { r ->
            val t = testi[r.fonte] ?: return@mapNotNull null
            // Gli intervalli della nota sono sul testo senza titolo: il titolo è davanti, si toglie.
            val nota = r.fonte.startsWith(Engine.FONTE_NOTA)
            val spostamento = if (nota && r.esatto) t.indexOf('\n') + 1 else 0
            mapOf(
                "tipo" to if (nota) "nota" else "trascrizione",
                "id" to r.fonte.substringAfter(':'),
                "start" to (r.span.start - spostamento).coerceAtLeast(0),
                "end" to (r.span.end - spostamento).coerceAtLeast(0),
                "esatto" to r.esatto,
                "punteggio" to r.punteggio.toDouble(),
            )
        }
    }

    private fun indicizzaTrascrizioni() {
        val m = models.chosen ?: return
        if (!models.ready(m)) return
        val e = engineFor(m)
        val ora = store.history()
        val vive = ora.map { it.at }.toHashSet()
        for (at in trascrizioniFatte.keys.filter { it !in vive }) {
            trascrizioniFatte.remove(at)
            e.ricerca.togli(Engine.FONTE_TRASCRIZIONE + at)
        }
        for (t in ora) {
            val h = hash(t.text)
            if (trascrizioniFatte[t.at] == h) continue
            runCatching { e.indicizza(Engine.FONTE_TRASCRIZIONE + t.at, t.text) }.onSuccess { trascrizioniFatte[t.at] = h }
        }
    }

    /** Libera il modello se non c'è più niente da fare e nessuno sta cercando. */
    private fun liberaSeFermo() {
        if (pending.isEmpty() && System.currentTimeMillis() - ultimaDomanda >= ATTESA_MODELLO) release()
    }

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
        indicizzaTrascrizioni()
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
            val medium = t.segmentation.levelCuts(2, m.profile)
            results[id] = Result(m.id, h, spans, t.segmentation.levelCuts(1, m.profile), medium, t.keySentences(medium), keywords.ranges(note.text))
            save()
            snapshotAlbums()
        } catch (_: Throwable) {
            // Un modello che non si carica (memoria, file rovinato) non deve far cadere l'app: la nota resta senza argomenti.
        } finally {
            pending.remove(id)
            liberaSeFermo()
            listener?.invoke()
        }
    }

    /** Gli album da mostrare, con i loro pezzi come intervalli di caratteri nelle note. */
    private fun snapshotAlbums() {
        val e = engine ?: return run { albumsSnapshot = emptyList(); categorieSnapshot = emptyList() }
        categorieSnapshot = runCatching { snapshotCategorie(e) }.getOrDefault(emptyList())
        val notes = store.notes().associateBy { it.id }
        // Il grande concetto di ogni album (Argomenti a due livelli: concetto → sotto-argomenti).
        val concettoDi = HashMap<Long, Int>().apply { e.topics.concetti().forEachIndexed { i, g -> g.forEach { put(it, i) } } }
        val testoDi = HashMap<Long, String>()
        val albums = e.topics.shown().mapNotNull { (album, members) ->
            val pieces = members.mapNotNull { pid ->
                val (noteId, range) = e.piece(pid) ?: return@mapNotNull null
                val r = results[noteId] ?: return@mapNotNull null
                val note = notes[noteId] ?: return@mapNotNull null
                if (range.last * 2 + 1 >= r.spans.size) return@mapNotNull null
                Triple(note, r.spans[range.first * 2], r.spans[range.last * 2 + 1])
            }
            // Basta che un argomento torni tre volte, anche nella stessa nota: se ne hai parlato tanto, è un argomento.
            if (pieces.size < 3) return@mapNotNull null
            val text = pieces.joinToString("\n") { (n, a, b) -> n.text.substring(a, b) }
            testoDi[album] = text
            val name = keywords.top(text, 2).joinToString(" · ") { it.replaceFirstChar(Char::uppercase) }
            mapOf(
                "id" to album,
                "name" to name.ifEmpty { "Senza nome" },
                "concetto" to (concettoDi[album] ?: -1),
                "pieces" to pieces.map { (n, a, b) -> mapOf("note" to n.id, "start" to a, "end" to b) },
            )
        }
        // Il nome di ogni concetto: l'espressione che conta di più nel testo di tutti i suoi album.
        val nomeConcetto = albums.filter { (it["concetto"] as Int) >= 0 }.groupBy { it["concetto"] as Int }.mapValues { (_, gruppo) ->
            keywords.top(gruppo.joinToString("\n") { testoDi[it["id"] as Long].orEmpty() }, 1).firstOrNull()?.replaceFirstChar(Char::uppercase)
        }
        albumsSnapshot = albums.map { a -> a + ("concettoNome" to (nomeConcetto[a["concetto"] as Int] ?: (a["name"] as String))) }
    }

    private fun snapshotCategorie(e: Engine): List<Map<String, Any>> {
        val m = engineModel ?: return emptyList()
        val vettori = Categorie.tutte.map { e.frase(Categorie.testo(it)) }
        val note = store.notes().associateBy { it.id }
        val dentro = Array(Categorie.tutte.size) { mutableListOf<Triple<Note, Int, Int>>() }
        for ((pid, posto) in e.pezzi) {
            val (noteId, frasi) = posto
            val n = note[noteId] ?: continue
            val r = results[noteId] ?: continue
            val v = e.topics.vettore(pid)?.toFloats() ?: continue
            val c = Categorie.di(v, vettori, m.profile.cercaMinimo, m.profile.categoriaScarto)
            if (c < 0) continue
            // La frase chiave del pezzo: è il riassunto, toccandola si apre la nota.
            val k = r.keys.firstOrNull { it in frasi } ?: frasi.first
            if (k * 2 + 1 >= r.spans.size) continue
            dentro[c].add(Triple(n, r.spans[k * 2], r.spans[k * 2 + 1]))
        }
        return Categorie.tutte.indices.filter { dentro[it].isNotEmpty() }.sortedByDescending { dentro[it].size }.map { i ->
            mapOf(
                "nome" to Categorie.tutte[i].nome,
                "pieces" to dentro[i].sortedByDescending { it.first.updated }.map { (n, a, b) -> mapOf("note" to n.id, "start" to a, "end" to b) },
            )
        }
    }

    /** Il motore del modello scelto, con le sue frasi su disco. Se il modello cambia si ricomincia: i vettori di modelli diversi non si mescolano. */
    private fun engineFor(m: TopicModel): Engine {
        engine?.takeIf { engineModel == m }?.let { return it }
        release()
        // Un motore nuovo ha la ricerca vuota: le trascrizioni si rifanno col suo modello.
        trascrizioniFatte.clear()
        val disk = SentenceStore(File(if (Sandbox.on(app)) Sandbox.dir(app) else models.dir(m), "frasi.bin"), m.embedding.dim)
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
        val tmp = File(file.parentFile, "note_topics_v4.tmp")
        tmp.writeText(j.toString())
        tmp.renameTo(file)
    }

    companion object {
        private const val ATTESA_MODELLO = 60_000L
        private const val RISULTATI = 20

        @Volatile private var instance: NoteTopicsWorker? = null

        fun get(context: Context): NoteTopicsWorker =
            instance ?: synchronized(this) { instance ?: NoteTopicsWorker(context).also { instance = it } }
    }
}
