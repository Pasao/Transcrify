package com.pasao.transcrify.engine.tokenize

import com.google.gson.JsonObject
import com.pasao.transcrify.engine.TestModels
import com.google.gson.JsonParser
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File

/**
 * I nostri tokenizer contro quelli ufficiali di Hugging Face (la libreria `tokenizers` in Python).
 *
 * I tokenizer.json (17 e 20 MB) non stanno nel repo: vedi [TestModels] (TRANSCRIFY_MODELS).
 * Senza, questi test si saltano.
 *
 * Le risposte giuste stanno in `src/test/resources/tokenizer-reference.json` (36 frasi, con e senza
 * il prefisso del modello); se nella cartella c'è anche `tokenizer-reference-extra.json` (migliaia di
 * testi a caso, fatto con lo stesso script) si controlla pure quello.
 */
class TokenizerTest {
    @Test
    fun preciseMatchesHuggingFace() = check("preciso")

    @Test
    fun lightMatchesHuggingFace() = check("leggero")

    @Test
    fun truncatesKeepingStartAndEnd() {
        val tok = load("leggero")
        val ids = tok.encode("parola ".repeat(400), maxTokens = 16)
        assertEquals(16, ids.size)
        assertEquals(0, ids.first())
        assertEquals(2, ids.last())
    }

    private fun check(model: String) {
        val tok = load(model)
        val reference = javaClass.getResourceAsStream("/tokenizer-reference.json")!!.bufferedReader().use { JsonParser.parseReader(it).asJsonObject }
        val checked = compare(tok, reference, model)
        val extra = File(TestModels.dir, "tokenizer-reference-extra.json")
        val more = if (extra.exists()) extra.bufferedReader().use { compare(tok, JsonParser.parseReader(it).asJsonObject, model) } else 0
        println("$model: $checked frasi del repo + $more a caso, tutte uguali a Hugging Face")
    }

    private fun compare(tok: Tokenizer, reference: JsonObject, model: String): Int {
        val rows = reference.getAsJsonArray(model)
        val wrong = ArrayList<String>()
        for (row in rows) {
            val o = row.asJsonObject
            val text = o.get("text").asString
            val want = o.getAsJsonArray("ids").map { it.asInt }.toIntArray()
            val got = tok.encode(text)
            if (!want.contentEquals(got)) wrong.add("${text.take(60)}\n  hf: ${want.toList()}\n  noi: ${got.toList()}")
        }
        assertArrayEquals("diversi da Hugging Face (${wrong.size} su ${rows.size()}):\n" + wrong.take(5).joinToString("\n"), emptyArray<String>(), wrong.toTypedArray())
        return rows.size()
    }

    private fun load(model: String): Tokenizer {
        val file = File(TestModels.dir, "$model/tokenizer.json")
        assumeTrue("manca $file: si salta (vedi TRANSCRIFY_MODELS)", file.exists())
        val t0 = System.nanoTime()
        return Tokenizer.load(file).also { println("$model: tokenizer letto in ${(System.nanoTime() - t0) / 1_000_000} ms") }
    }
}
