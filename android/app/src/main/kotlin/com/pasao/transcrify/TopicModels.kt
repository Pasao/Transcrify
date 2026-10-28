package com.pasao.transcrify

import android.content.Context
import java.io.File
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * I modelli che danno il senso alle frasi, per gli argomenti nelle note. Non sono nell'app:
 * si scaricano solo se li scegli, una volta, e restano sul telefono. All'utente si dice
 * «più preciso» o «più leggero»; il nome vero sta scritto piccolo sotto, per chi lo conosce.
 */
enum class TopicModel(
    val id: String,
    val label: String,
    val modelName: String,
    /** Quanto pesa, più o meno, prima di sapere il numero esatto dal server. */
    val approxMb: Int,
    private val repo: String,
    /** I file da scaricare, col loro nome: il modello ONNX cerca i suoi dati esterni proprio con quel nome. */
    val files: List<String>,
) {
    PRECISE(
        "preciso", "Più preciso", "EmbeddingGemma 300M", 218, "onnx-community/embeddinggemma-300m-ONNX",
        listOf("onnx/model_q4.onnx", "onnx/model_q4.onnx_data", "tokenizer.json"),
    ),
    LIGHT(
        "leggero", "Più leggero", "multilingual-e5-small", 136, "Xenova/multilingual-e5-small",
        listOf("onnx/model_quantized.onnx", "tokenizer.json"),
    );

    fun url(file: String) = "https://huggingface.co/$repo/resolve/main/$file"

    companion object {
        fun of(id: String?) = entries.firstOrNull { it.id == id }
    }
}

/**
 * Scaricare un modello: un file alla volta, in un «.part» che si riprende da dove era arrivato
 * (Range) se la rete cade o chiudi l'app. Solo quando un file è intero prende il suo nome:
 * un modello a metà non viene mai usato.
 */
class TopicModels(context: Context) {
    private val root = File(context.filesDir, "models")
    private val prefs = context.getSharedPreferences("transcrify", Context.MODE_PRIVATE)

    sealed interface Status {
        data object Missing : Status
        data class Downloading(val done: Long, val total: Long) : Status
        data object Ready : Status
        data class Failed(val reason: String) : Status
    }

    /** Il modello scelto per gli argomenti; null = argomenti spenti. */
    var chosen: TopicModel?
        get() = TopicModel.of(prefs.getString("topics_model", null))
        set(v) = prefs.edit().putString("topics_model", v?.id).apply()

    fun dir(m: TopicModel) = File(root, m.id)
    fun file(m: TopicModel, name: String) = File(dir(m), name.substringAfterLast('/'))

    fun status(m: TopicModel): Status = running[m]?.status ?: if (ready(m)) Status.Ready else failed[m] ?: Status.Missing

    fun ready(m: TopicModel) = m.files.all { file(m, it).exists() }

    fun download(m: TopicModel) {
        if (running[m] != null || ready(m)) return
        failed.remove(m)
        val job = Job()
        running[m] = job
        thread(name = "scarica-${m.id}") {
            try {
                val sizes = m.files.map { size(m.url(it)) }
                val total = sizes.sum()
                var before = 0L
                for ((i, name) in m.files.withIndex()) {
                    if (job.cancelled) break
                    val out = file(m, name)
                    if (!out.exists()) fetch(m.url(name), out, job) { got -> job.status = Status.Downloading(before + got, total) }
                    before += sizes[i]
                }
            } catch (e: Exception) {
                failed[m] = Status.Failed(if (e is java.io.IOException) "Manca la rete, o si è interrotta. Riprova." else (e.message ?: "Qualcosa non va."))
            } finally {
                running.remove(m)
            }
        }
    }

    fun cancel(m: TopicModel) {
        running[m]?.cancelled = true
    }

    /** Toglie il modello dal telefono (e i pezzi a metà). */
    fun delete(m: TopicModel) {
        cancel(m)
        dir(m).deleteRecursively()
        failed.remove(m)
        if (chosen == m) chosen = null
    }

    private class Job {
        @Volatile var cancelled = false
        @Volatile var status: Status = Status.Downloading(0, 0)
    }

    private fun size(url: String): Long {
        val c = open(url) { it.requestMethod = "HEAD" }
        try {
            return c.contentLengthLong.coerceAtLeast(0)
        } finally {
            c.disconnect()
        }
    }

    private fun fetch(url: String, out: File, job: Job, progress: (Long) -> Unit) {
        out.parentFile?.mkdirs()
        val part = File(out.path + ".part")
        var have = if (part.exists()) part.length() else 0L
        val c = open(url) { if (have > 0) it.setRequestProperty("Range", "bytes=$have-") }
        try {
            // Il server può ignorare la ripresa: allora si ricomincia da capo.
            if (have > 0 && c.responseCode != HttpURLConnection.HTTP_PARTIAL) have = 0
            if (c.responseCode !in 200..299) throw java.io.IOException("HTTP ${c.responseCode}")
            RandomAccessFile(part, "rw").use { raf ->
                raf.setLength(have)
                raf.seek(have)
                val buf = ByteArray(1 shl 16)
                c.inputStream.use { input ->
                    var last = 0L
                    while (!job.cancelled) {
                        val n = input.read(buf)
                        if (n < 0) break
                        raf.write(buf, 0, n)
                        have += n
                        if (have - last > (1 shl 20)) {
                            progress(have)
                            last = have
                        }
                    }
                }
            }
            progress(have)
            if (!job.cancelled) check(part.renameTo(out)) { "Non riesco a salvare il modello." }
        } finally {
            c.disconnect()
        }
    }

    /** Hugging Face rimanda a un altro indirizzo (CDN): si seguono i rimandi anche tra domini. */
    private fun open(url: String, setup: (HttpURLConnection) -> Unit): HttpURLConnection {
        var u = URL(url)
        repeat(5) {
            val c = u.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 20_000
            c.readTimeout = 30_000
            setup(c)
            val code = c.responseCode
            if (code in 300..399) {
                val next = c.getHeaderField("Location") ?: throw java.io.IOException("Rimando senza indirizzo")
                c.disconnect()
                u = URL(u, next)
            } else return c
        }
        throw java.io.IOException("Troppi rimandi")
    }

    companion object {
        // Uno solo per processo: lo scaricamento continua anche se esci dalle impostazioni.
        private val running = java.util.concurrent.ConcurrentHashMap<TopicModel, Job>()
        private val failed = java.util.concurrent.ConcurrentHashMap<TopicModel, Status.Failed>()
    }
}
