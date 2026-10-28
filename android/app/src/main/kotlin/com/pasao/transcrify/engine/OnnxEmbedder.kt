package com.pasao.transcrify.engine

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import com.pasao.transcrify.TopicModel
import com.pasao.transcrify.engine.tokenize.Tokenizer
import java.io.File
import java.nio.LongBuffer

/** Da dove viene il vettore di una frase, nell'uscita del modello. */
enum class Pooling(val output: String) {
    /** Il modello lo dà già fatto (Gemma: media, due strati densi e lunghezza 1). */
    READY("sentence_embedding"),
    /** Un vettore per pezzo di parola: si fa la media di quelli veri, senza il riempimento (e5). */
    MEAN("last_hidden_state"),
}

/** Come si usa un modello: cosa si mette davanti alla frase, cosa si legge, quanti numeri si tengono. */
class EmbeddingSpec(
    /** Il prefisso che dice al modello a cosa servono i vettori. */
    val prompt: String,
    val pooling: Pooling,
    /** Quanti numeri si tengono. Con Matryoshka (Gemma) i primi bastano: si taglia e si rinormalizza. */
    val dim: Int,
    /** Quante frasi per passata. 1 se il risultato di una frase cambierebbe con le altre nel gruppo. */
    val maxBatch: Int,
    /** Le nostre frasi stanno sotto i 240 caratteri: 256 pezzi bastano sempre, con margine. */
    val maxTokens: Int = 256,
)

/**
 * Il modello vero, sul telefono: ONNX Runtime sulla CPU, con il nostro tokenizer in Kotlin.
 *
 * Le frasi si ordinano per lunghezza e vanno a gruppi: nello stesso gruppo si riempie fino alla più
 * lunga, e così si riempie poco. Ogni vettore esce lungo 1. Va usato da un thread solo (quello
 * del lavoro in background); [close] libera la memoria del modello.
 */
class OnnxEmbedder(dir: File, model: TopicModel) : Embedder, AutoCloseable {
    private val spec = model.embedding
    // Niente dati d'uso a Microsoft: l'avvio automatico è già tolto dal manifest, qui si spegne il resto.
    private val env = OrtEnvironment.getEnvironment().apply { setTelemetry(false) }
    private val tokenizer = Tokenizer.load(File(dir, "tokenizer.json"))
    private val session: OrtSession = OrtSession.SessionOptions().use { options ->
        options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
        // Sui telefoni metà dei core sono piccoli: oltre 4 thread si aspetta i lenti.
        options.setIntraOpNumThreads(Runtime.getRuntime().availableProcessors().coerceIn(1, 4))
        // Tra una passata e l'altra i thread dormono invece di girare a vuoto: batteria.
        options.addConfigEntry("session.intra_op.allow_spinning", "0")
        env.createSession(File(dir, model.onnxFile).path, options)
    }
    private val typeIds = "token_type_ids" in session.inputNames

    override val dim = spec.dim

    override fun embed(sentences: List<String>): List<FloatArray> {
        val ids = sentences.map { tokenizer.encode(spec.prompt + it, spec.maxTokens) }
        val out = arrayOfNulls<FloatArray>(sentences.size)
        val order = ids.indices.sortedBy { ids[it].size }
        for (batch in order.chunked(spec.maxBatch)) run(batch, ids, out)
        return out.map { it!! }
    }

    private fun run(batch: List<Int>, ids: List<IntArray>, out: Array<FloatArray?>) {
        val rows = batch.size
        val len = batch.maxOf { ids[it].size }
        val input = LongArray(rows * len) { tokenizer.padId.toLong() }
        val mask = LongArray(rows * len)
        for ((r, i) in batch.withIndex()) {
            val s = ids[i]
            for (t in s.indices) {
                input[r * len + t] = s[t].toLong()
                mask[r * len + t] = 1
            }
        }
        val shape = longArrayOf(rows.toLong(), len.toLong())
        val tensors = LinkedHashMap<String, OnnxTensor>()
        try {
            tensors["input_ids"] = OnnxTensor.createTensor(env, LongBuffer.wrap(input), shape)
            tensors["attention_mask"] = OnnxTensor.createTensor(env, LongBuffer.wrap(mask), shape)
            if (typeIds) tensors["token_type_ids"] = OnnxTensor.createTensor(env, LongBuffer.wrap(LongArray(rows * len)), shape)
            session.run(tensors, setOf(spec.pooling.output)).use { result ->
                val t = result.get(0) as OnnxTensor
                val values = t.floatBuffer
                val width = t.info.shape.last().toInt()
                for ((r, i) in batch.withIndex()) {
                    val v = FloatArray(spec.dim)
                    when (spec.pooling) {
                        Pooling.READY -> for (d in 0 until spec.dim) v[d] = values[r * width + d]
                        Pooling.MEAN -> {
                            val real = ids[i].size
                            val base = r * len * width
                            for (tok in 0 until real) for (d in 0 until spec.dim) v[d] += values[base + tok * width + d]
                        }
                    }
                    // Per la media basta la direzione: dividere per il numero di pezzi lo fa già normalizzare.
                    out[i] = Vec.normalized(v)
                }
            }
        } finally {
            tensors.values.forEach { it.close() }
        }
    }

    override fun close() = session.close()
}
