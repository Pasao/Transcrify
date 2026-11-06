package com.pasao.transcrify.engine

import com.google.gson.JsonParser
import com.pasao.transcrify.TopicModel
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

/**
 * Il riassunto estrattivo col modello vero sul banco di prova (`estratto-banco.json`: trascrizioni finte,
 * parlate, con le frasi che si sceglierebbero a mano). Deve fare almeno come la prova in Python:
 * precisione 0,64 (quante scelte contengono un'ideale) e copertura 0,69 (quante ideali sono state prese).
 * Senza i modelli (vedi [TestModels]) si salta.
 */
class EstrattoBancoTest {
    @Test
    fun almenoComeInPython() {
        val model = TopicModel.PRECISE
        val dir = File(TestModels.dir, model.id)
        assumeTrue("manca il modello in $dir", File(dir, model.onnxFile).exists())
        TestModels.assumeOnnxRuntimeLoads()
        val banco = javaClass.getResourceAsStream("/estratto-banco.json")!!.bufferedReader().use {
            JsonParser.parseReader(it).asJsonObject.getAsJsonArray("banco")
        }
        var precisione = 0.0
        var copertura = 0.0
        OnnxEmbedder(dir, model).use { emb ->
            for (c in banco.map { it.asJsonObject }) {
                val testo = c.get("testo").asString
                val ideali = c.getAsJsonArray("ideali").map { it.asString.lowercase() }
                val scelte = Estratto.di(testo, emb::embed).map { it.testo.lowercase() }
                val p = scelte.count { s -> ideali.any { it in s } }.toDouble() / maxOf(1, scelte.size)
                val r = ideali.count { i -> scelte.any { i in it } }.toDouble() / ideali.size
                println("${c.get("nome").asString}: precisione ${"%.2f".format(p)}, copertura ${"%.2f".format(r)}\n  " + scelte.joinToString("\n  "))
                precisione += p
                copertura += r
            }
        }
        precisione /= banco.size()
        copertura /= banco.size()
        println("MEDIA precisione ${"%.2f".format(precisione)}, copertura ${"%.2f".format(copertura)}")
        assertTrue("precisione $precisione", precisione >= PRECISIONE_PYTHON)
        assertTrue("copertura $copertura", copertura >= COPERTURA_PYTHON)
    }

    private companion object {
        // I numeri della prova in Python, arrotondati per difetto: Kotlin deve fare almeno così.
        const val PRECISIONE_PYTHON = 0.64 - 0.005
        const val COPERTURA_PYTHON = 0.69 - 0.005
    }
}
