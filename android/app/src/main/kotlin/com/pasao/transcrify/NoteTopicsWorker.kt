package com.pasao.transcrify

import android.content.Context
import android.util.Base64
import com.pasao.transcrify.engine.Embedder
import com.pasao.transcrify.engine.Engine
import com.pasao.transcrify.engine.Grain
import com.pasao.transcrify.engine.OnnxEmbedder
import com.pasao.transcrify.engine.Segmentation
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
 * non si rifà niente; se è cambiata, il motore manda al modello solo le frasi nuove.
 *
 * Il modello si carica quando serve e si libera appena la coda è vuota: occupa memoria solo
 * mentre lavora (un secondo per caricarlo, poi millisecondi per frase).
 */
class NoteTopicsWorker private constructor(context: Context) {
    private val app = context.applicationContext
    private val store = Store(app)
    private val models = TopicModels(app)
    private val file = File(app.filesDir, "note_topics.json")
    private val exec = Executors.newSingleThreadExecutor { r -> Thread(r, "argomenti").apply { priority = Thread.MIN_PRIORITY } }

    /** Le note in coda o in lavorazione. */
    private val pending: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /** Chi vuole sapere quando una nota è pronta (l'app, per rileggere). */
    @Volatile var listener: (() -> Unit)? = null

    /** Il risultato di una nota: per quale testo e con quale modello, dove sono le frasi, i confini per grana. */
    private class Result(val model: String, val hash: Long, val spans: IntArray, val depth: ByteArray, val cuts: Map<Grain, IntArray>) {
        fun toJson(): JSONObject = JSONObject()
            .put("model", model).put("hash", hash)
            .put("spans", JSONArray(spans.toList()))
            .put("depth", Base64.encodeToString(depth, Base64.NO_WRAP))
            .put("cuts", JSONObject().apply { for ((g, c) in cuts) put(g.name, JSONArray(c.toList())) })

        companion object {
            fun fromJson(j: JSONObject): Result {
                fun ints(a: JSONArray) = IntArray(a.length()) { a.getInt(it) }
                val cuts = j.getJSONObject("cuts")
                return Result(
                    j.getString("model"), j.getLong("hash"), ints(j.getJSONArray("spans")),
                    Base64.decode(j.getString("depth"), Base64.NO_WRAP),
                    Grain.entries.associateWith { ints(cuts.getJSONArray(it.name)) },
                )
            }
        }
    }

    private val results: MutableMap<String, Result> = ConcurrentHashMap(load())

    init {
        // Appena un modello finisce di scaricarsi, si fanno le note che aspettano.
        TopicModels.onReady = { requestAll() }
    }

    // Il motore e il modello caricato: solo nel thread del lavoro.
    private var engine: Engine? = null
    private var engineModel: TopicModel? = null
    private var embedder: OnnxEmbedder? = null

    /** Come sta la nota, per l'indicatore nella lista: "off", "pending", "ready" o "stale" (cambiata, da rifare). */
    fun state(id: String, text: String): String {
        val m = models.chosen ?: return "off"
        if (!models.ready(m)) return "off"
        if (id in pending) return "pending"
        val r = results[id] ?: return "stale"
        return if (r.model == m.id && r.hash == hash(text)) "ready" else "stale"
    }

    /** Gli argomenti di una nota per l'app: dove sono le frasi e i confini di ogni grana. null se non sono pronti. */
    fun topics(id: String): Map<String, Any>? {
        val note = store.notes().firstOrNull { it.id == id } ?: return null
        if (state(id, note.text) != "ready") return null
        val r = results.getValue(id)
        return mapOf(
            "spans" to r.spans.toList(),
            "coarse" to r.cuts.getValue(Grain.COARSE).toList(),
            "medium" to r.cuts.getValue(Grain.MEDIUM).toList(),
            "fine" to r.cuts.getValue(Grain.FINE).toList(),
        )
    }

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
            if (results.remove(id) != null) save()
        }
    }

    private fun work(id: String) {
        try {
            val m = models.chosen ?: return
            if (!models.ready(m)) return
            val note = store.notes().firstOrNull { it.id == id } ?: return
            val h = hash(note.text)
            val old = results[id]
            if (old != null && old.model == m.id && old.hash == h) return
            val e = engineFor(m)
            val t = e.commit(id, note.text)
            val spans = IntArray(t.sentences.size * 2).also { a -> t.sentences.forEachIndexed { i, s -> a[2 * i] = s.start; a[2 * i + 1] = s.end } }
            results[id] = Result(m.id, h, spans, t.segmentation.depth, cutsOf(t.segmentation, m))
            save()
        } catch (_: Throwable) {
            // Un modello che non si carica (memoria, file rovinato) non deve far cadere l'app: la nota resta senza argomenti.
        } finally {
            pending.remove(id)
            if (pending.isEmpty()) release()
            listener?.invoke()
        }
    }

    private fun cutsOf(seg: Segmentation, m: TopicModel) = Grain.entries.associateWith { seg.cuts(it, m.profile) }

    /** Il motore del modello scelto. Se il modello cambia, si ricomincia: i vettori di modelli diversi non si mescolano. */
    private fun engineFor(m: TopicModel): Engine {
        engine?.takeIf { engineModel == m }?.let { return it }
        release()
        val lazy = object : Embedder {
            override val dim = m.embedding.dim
            override fun embed(sentences: List<String>): List<FloatArray> =
                (embedder ?: OnnxEmbedder(models.dir(m), m).also { embedder = it }).embed(sentences)
        }
        return Engine(lazy, m.profile).also {
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
        val tmp = File(file.parentFile, "note_topics.tmp")
        tmp.writeText(j.toString())
        tmp.renameTo(file)
    }

    companion object {
        @Volatile private var instance: NoteTopicsWorker? = null

        fun get(context: Context): NoteTopicsWorker =
            instance ?: synchronized(this) { instance ?: NoteTopicsWorker(context).also { instance = it } }
    }
}
