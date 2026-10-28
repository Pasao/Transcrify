package com.pasao.transcrify.engine

import com.google.gson.JsonParser
import com.pasao.transcrify.TopicModel
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

/**
 * Il modello vero sul PC, con ONNX Runtime per desktop (la stessa versione del telefono).
 *
 * Servono i modelli scaricati come li scarica l'app, nella cartella TRANSCRIFY_MODELS
 * (vedi [TestModels]), e `embedding-reference.json`: i vettori delle stesse frasi calcolati
 * in Python con onnxruntime e i tokenizer di Hugging Face (prefisso, media e taglio uguali).
 * Senza, si salta.
 */
class OnnxEmbedderTest {
    @Test
    fun preciseMatchesPython() = parity(TopicModel.PRECISE)

    @Test
    fun lightMatchesPython() = parity(TopicModel.LIGHT)

    private fun parity(model: TopicModel) {
        val dir = File(TestModels.dir, model.id)
        val refFile = File(TestModels.dir, "embedding-reference.json")
        assumeTrue("mancano il modello o i riferimenti in ${dir.parentFile}", File(dir, model.onnxFile).exists() && refFile.exists())
        TestModels.assumeOnnxRuntimeLoads()
        val rows = refFile.bufferedReader().use { JsonParser.parseReader(it).asJsonObject.getAsJsonArray(model.id) }
        val texts = rows.map { it.asJsonObject.get("text").asString }
        val want = rows.map { r -> r.asJsonObject.getAsJsonArray("vec").map { it.asFloat }.toFloatArray() }

        val t0 = System.nanoTime()
        OnnxEmbedder(dir, model).use { emb ->
            val load = (System.nanoTime() - t0) / 1e6
            // Tutte insieme: per Gemma vanno a gruppi, ed esce lo stesso che una alla volta.
            val got = emb.embed(texts)
            val cosines = texts.indices.map { Vec.dot(got[it], want[it]) }
            val worst = cosines.min()

            // Le ultime 9 frasi: 3 argomenti × 3 frasi.
            val topical = got.takeLast(9)
            var same = 0f
            var other = 0f
            var nSame = 0
            var nOther = 0
            for (i in 0 until 9) for (j in i + 1 until 9) {
                val s = Vec.dot(topical[i], topical[j])
                if (i / 3 == j / 3) { same += s; nSame++ } else { other += s; nOther++ }
            }

            val single = texts.takeLast(9)
            emb.embed(single.take(3)) // riscaldamento
            val t1 = System.nanoTime()
            for (s in single) emb.embed(listOf(s))
            val oneByOne = (System.nanoTime() - t1) / 1e6 / single.size
            val t2 = System.nanoTime()
            emb.embed(texts)
            val grouped = (System.nanoTime() - t2) / 1e6 / texts.size

            println(
                "${model.id}: caricato in ${"%.0f".format(load)} ms; coseno con Python minimo ${"%.7f".format(worst)} su ${texts.size} frasi; " +
                    "stesso argomento ${"%.3f".format(same / nSame)}, diversi ${"%.3f".format(other / nOther)}; " +
                    "${"%.1f".format(oneByOne)} ms a frase da sola, ${"%.1f".format(grouped)} ms a frase tutte insieme",
            )
            assertTrue("coseno minimo $worst", worst >= 0.999f)
            assertTrue("stesso argomento ${same / nSame} contro diversi ${other / nOther}", same / nSame > other / nOther + 0.03f)
        }
    }
}
