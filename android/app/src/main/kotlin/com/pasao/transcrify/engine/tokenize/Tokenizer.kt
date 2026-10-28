package com.pasao.transcrify.engine.tokenize

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import java.io.File
import java.util.Base64
import java.util.Locale

/**
 * Dal testo ai numeri che il modello capisce, letto dal tokenizer.json di Hugging Face e rifatto
 * in Kotlin: nessuna libreria nativa, uguale sul telefono e nei test sul PC.
 *
 * Il percorso è quello di Hugging Face: i pezzi interi («<s>», gli a-capo di Gemma) si staccano
 * prima; il resto si pulisce (normalizer), si divide in parole (pre_tokenizer) e ogni parola
 * va al modello (Unigram o BPE); in fondo si aggiungono inizio e fine (post_processor).
 * Si leggono solo le forme che usano i nostri due modelli: con un'altra il caricamento si ferma
 * e dice cosa manca, invece di dare numeri sbagliati in silenzio.
 */
class Tokenizer internal constructor(
    private val added: AddedTokens,
    private val normalizer: Normalizer?,
    private val preTokenizer: PreTokenizer?,
    private val model: WordModel,
    private val prefix: IntArray,
    private val suffix: IntArray,
    /** L'id con cui si riempiono le frasi più corte in un gruppo. */
    val padId: Int,
) {
    /** Gli id della frase con inizio e fine, al massimo [maxTokens] in tutto: si taglia la coda. */
    fun encode(text: String, maxTokens: Int = Int.MAX_VALUE): IntArray {
        val body = IntList()
        added.split(
            text,
            text = { segment ->
                val clean = normalizer?.apply(segment) ?: segment
                if (preTokenizer == null) model.tokenize(clean, body)
                else preTokenizer.split(clean) { if (it.isNotEmpty()) model.tokenize(it, body) }
            },
            token = body::add,
        )
        body.truncate((maxTokens - prefix.size - suffix.size).coerceAtLeast(0))
        val out = IntArray(prefix.size + body.size + suffix.size)
        prefix.copyInto(out)
        for (i in 0 until body.size) out[prefix.size + i] = body[i]
        suffix.copyInto(out, prefix.size + body.size)
        return out
    }

    companion object {
        /** Legge un tokenizer.json (20 MB per Gemma): una volta sola, poi resta in memoria in forma compatta. */
        fun load(file: File): Tokenizer = JsonReader(file.bufferedReader(Charsets.UTF_8, 1 shl 16)).use { read(it) }

        private fun read(r: JsonReader): Tokenizer {
            var added = emptyList<Pair<String, Int>>()
            var normalizer: JsonElement? = null
            var preTokenizer: JsonElement? = null
            var post: JsonElement? = null
            var model: Pair<WordModel, PieceLookup>? = null
            var padding: JsonElement? = null
            r.beginObject()
            while (r.hasNext()) {
                when (r.nextName()) {
                    "added_tokens" -> added = readAdded(r)
                    "normalizer" -> normalizer = JsonParser.parseReader(r)
                    "pre_tokenizer" -> preTokenizer = JsonParser.parseReader(r)
                    "post_processor" -> post = JsonParser.parseReader(r)
                    "padding" -> padding = JsonParser.parseReader(r)
                    "model" -> model = readModel(r)
                    else -> r.skipValue()
                }
            }
            r.endObject()
            val (wordModel, lookup) = requireNotNull(model) { "tokenizer.json senza modello" }
            val idOf = { token: String -> added.firstOrNull { it.first == token }?.second ?: lookup(token) }
            val (prefix, suffix) = template(post, idOf)
            val pad = padding?.takeIf { it.isJsonObject }?.asJsonObject?.get("pad_id")?.asInt
                ?: idOf("<pad>").takeIf { it >= 0 } ?: 0
            return Tokenizer(AddedTokens(added), normalizer(normalizer), preTokenizer(preTokenizer), wordModel, prefix, suffix, pad)
        }

        private fun readAdded(r: JsonReader): List<Pair<String, Int>> {
            val out = ArrayList<Pair<String, Int>>()
            r.beginArray()
            while (r.hasNext()) {
                val o = JsonParser.parseReader(r).asJsonObject
                // Solo pezzi presi così come sono nel testo: è il caso dei nostri due modelli.
                for (flag in listOf("normalized", "lstrip", "rstrip", "single_word")) {
                    require(o.get(flag)?.asBoolean != true) { "pezzo aggiunto con $flag: non previsto" }
                }
                out.add(o.get("content").asString to o.get("id").asInt)
            }
            r.endArray()
            return out
        }

        // --- modello ---

        private fun readModel(r: JsonReader): Pair<WordModel, PieceLookup> {
            var type: String? = null
            var unkId: Int? = null
            var unkToken: String? = null
            var byteFallback = false
            var fuseUnk = false
            var unigram: Pair<PieceTable, DoubleArray>? = null
            var vocab: PieceTable? = null
            var merges: PairMap? = null
            r.beginObject()
            while (r.hasNext()) {
                when (r.nextName()) {
                    "type" -> type = r.nextString()
                    "unk_id" -> unkId = nullableInt(r)
                    "unk_token" -> unkToken = nullableString(r)
                    "byte_fallback" -> byteFallback = nullableBoolean(r)
                    "fuse_unk" -> fuseUnk = nullableBoolean(r)
                    "dropout" -> checkNoDropout(r)
                    "continuing_subword_prefix", "end_of_word_suffix" -> require(nullableString(r).isNullOrEmpty()) { "BPE con prefissi o suffissi: non previsto" }
                    "ignore_merges" -> require(!nullableBoolean(r)) { "BPE con ignore_merges: non previsto" }
                    "vocab" -> when (r.peek()) {
                        JsonToken.BEGIN_ARRAY -> unigram = readUnigramVocab(r)
                        else -> vocab = readBpeVocab(r)
                    }
                    "merges" -> merges = readMerges(r, requireNotNull(vocab) { "nel tokenizer.json le fusioni vengono prima del vocabolario" })
                    else -> r.skipValue()
                }
            }
            r.endObject()
            return when (type) {
                "Unigram" -> {
                    val (pieces, scores) = requireNotNull(unigram) { "Unigram senza vocabolario" }
                    require(!byteFallback) { "Unigram con byte_fallback: non previsto" }
                    Unigram(pieces, scores, requireNotNull(unkId) { "Unigram senza unk_id" }) to { t: String -> pieces.get(t) }
                }
                "BPE" -> {
                    val v = requireNotNull(vocab) { "BPE senza vocabolario" }
                    val unk = unkToken?.let { v.get(it) } ?: -1
                    val bytes = if (byteFallback) IntArray(256) { v.get(String.format(Locale.ROOT, "<0x%02X>", it)) } else null
                    Bpe(v, merges ?: PairMap(0), unk, fuseUnk, bytes) to { t: String -> v.get(t) }
                }
                else -> error("modello $type non previsto")
            }
        }

        private fun checkNoDropout(r: JsonReader) {
            if (r.peek() == JsonToken.NULL) r.nextNull() else require(r.nextDouble() == 0.0) { "BPE con dropout: non previsto" }
        }

        /** [[pezzo, punteggio], …]: l'id è la posizione. */
        private fun readUnigramVocab(r: JsonReader): Pair<PieceTable, DoubleArray> {
            val table = PieceTable(1 shl 18)
            var scores = DoubleArray(1 shl 18)
            var n = 0
            r.beginArray()
            while (r.hasNext()) {
                r.beginArray()
                val piece = r.nextString()
                val score = r.nextDouble()
                r.endArray()
                if (n == scores.size) scores = scores.copyOf(n * 2)
                scores[n] = score
                // Due voci uguali: Hugging Face tiene l'ultima.
                table.put(piece, n)
                n++
            }
            r.endArray()
            return table to scores.copyOf(n)
        }

        /** {pezzo: id, …} */
        private fun readBpeVocab(r: JsonReader): PieceTable {
            val table = PieceTable(1 shl 18)
            r.beginObject()
            while (r.hasNext()) {
                val piece = r.nextName()
                table.put(piece, r.nextInt())
            }
            r.endObject()
            return table
        }

        /** [[a, b], …] o, nel formato vecchio, ["a b", …]: il rango è la posizione. */
        private fun readMerges(r: JsonReader, vocab: PieceTable): PairMap {
            val map = PairMap(1 shl 19)
            var rank = 0
            r.beginArray()
            while (r.hasNext()) {
                val a: String
                val b: String
                if (r.peek() == JsonToken.BEGIN_ARRAY) {
                    r.beginArray()
                    a = r.nextString()
                    b = r.nextString()
                    r.endArray()
                } else {
                    val s = r.nextString()
                    val space = s.indexOf(' ')
                    require(space > 0) { "fusione senza spazio: $s" }
                    a = s.substring(0, space)
                    b = s.substring(space + 1)
                }
                val left = vocab.get(a)
                val right = vocab.get(b)
                val merged = vocab.get(a + b)
                require(left >= 0 && right >= 0 && merged >= 0) { "fusione fuori dal vocabolario: $a + $b" }
                map.put(left, right, rank++, merged)
            }
            r.endArray()
            return map
        }

        // --- i pezzi intorno al modello ---

        private fun normalizer(e: JsonElement?): Normalizer? {
            if (e == null || e.isJsonNull) return null
            val o = e.asJsonObject
            return when (val type = o.str("type")) {
                "Sequence" -> NormalizerSequence(o.getAsJsonArray("normalizers").map { requireNotNull(normalizer(it)) })
                "Precompiled" -> Precompiled(Base64.getDecoder().decode(o.str("precompiled_charsmap")))
                "Replace" -> {
                    val pattern = o.getAsJsonObject("pattern")
                    val to = o.str("content")
                    when {
                        pattern.has("String") -> ReplaceString(pattern.str("String"), to)
                        pattern.has("Regex") -> ReplaceRegex(pattern.str("Regex"), to)
                        else -> error("Replace senza schema")
                    }
                }
                else -> error("normalizer $type non previsto")
            }
        }

        private fun preTokenizer(e: JsonElement?): PreTokenizer? {
            if (e == null || e.isJsonNull) return null
            val o = e.asJsonObject
            return when (val type = o.str("type")) {
                "Metaspace" -> {
                    val replacement = o.str("replacement")
                    require(replacement.length == 1) { "Metaspace con più caratteri: non previsto" }
                    // Il formato vecchio dice add_prefix_space, il nuovo prepend_scheme.
                    val scheme = o.get("prepend_scheme")?.asString ?: if (o.get("add_prefix_space")?.asBoolean != false) "always" else "never"
                    require(scheme == "always" || scheme == "never") { "Metaspace con prepend_scheme $scheme: non previsto" }
                    Metaspace(replacement[0], scheme == "always", o.get("split")?.asBoolean ?: true)
                }
                "Split" -> {
                    val pattern = o.getAsJsonObject("pattern")
                    require(pattern.has("String") && o.str("behavior") == "MergedWithPrevious" && o.get("invert")?.asBoolean != true) { "Split non previsto: $o" }
                    SplitMergedWithPrevious(pattern.str("String"))
                }
                else -> error("pre_tokenizer $type non previsto")
            }
        }

        /** Gli id che vanno prima e dopo la frase, dallo schema «single» del TemplateProcessing. */
        private fun template(e: JsonElement?, idOf: (String) -> Int): Pair<IntArray, IntArray> {
            if (e == null || e.isJsonNull) return IntArray(0) to IntArray(0)
            val o = e.asJsonObject
            require(o.str("type") == "TemplateProcessing") { "post_processor ${o.str("type")} non previsto" }
            val special = o.getAsJsonObject("special_tokens")
            val before = ArrayList<Int>()
            val after = ArrayList<Int>()
            var seen = false
            for (item in o.getAsJsonArray("single")) {
                val it = item.asJsonObject
                when {
                    it.has("Sequence") -> seen = true
                    it.has("SpecialToken") -> {
                        val name = it.getAsJsonObject("SpecialToken").str("id")
                        val ids: JsonArray = special?.getAsJsonObject(name)?.getAsJsonArray("ids")
                            ?: JsonArray().apply { add(idOf(name)) }
                        for (id in ids) (if (seen) after else before).add(id.asInt)
                    }
                }
            }
            return before.toIntArray() to after.toIntArray()
        }

        private fun JsonObject.str(key: String): String = requireNotNull(get(key)?.takeIf { !it.isJsonNull }) { "manca $key" }.asString

        private fun nullableInt(r: JsonReader): Int? = if (r.peek() == JsonToken.NULL) null.also { r.nextNull() } else r.nextInt()
        private fun nullableString(r: JsonReader): String? = if (r.peek() == JsonToken.NULL) null.also { r.nextNull() } else r.nextString()
        private fun nullableBoolean(r: JsonReader): Boolean = if (r.peek() == JsonToken.NULL) false.also { r.nextNull() } else r.nextBoolean()
    }
}

/** Il vocabolario del modello visto da fuori: da pezzo a id, o -1. */
internal typealias PieceLookup = (String) -> Int
