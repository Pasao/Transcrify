package com.pasao.transcrify.engine.tokenize

/** Divide il testo già pulito in parole: il modello lavora su una parola alla volta. */
internal fun interface PreTokenizer {
    fun split(text: String, word: (String) -> Unit)
}

/**
 * Metaspace di SentencePiece (e5): gli spazi diventano «▁», uno si mette anche davanti,
 * e ogni «▁» comincia una parola nuova (va con quello che segue: «▁ciao», «▁mondo»).
 */
internal class Metaspace(private val replacement: Char, private val prepend: Boolean, private val split: Boolean) : PreTokenizer {
    override fun split(text: String, word: (String) -> Unit) {
        if (text.isEmpty()) return
        var t = text.replace(' ', replacement)
        if (prepend && t[0] != replacement) t = replacement + t
        if (!split) return word(t)
        var start = 0
        for (i in 1 until t.length) {
            if (t[i] == replacement) {
                word(t.substring(start, i))
                start = i
            }
        }
        word(t.substring(start))
    }
}

/** Divide su un testo fisso, che resta attaccato alla parola prima (Gemma: sullo spazio). */
internal class SplitMergedWithPrevious(private val delimiter: String) : PreTokenizer {
    override fun split(text: String, word: (String) -> Unit) {
        if (text.isEmpty()) return
        var start = 0
        while (true) {
            val at = text.indexOf(delimiter, start)
            if (at < 0) break
            val end = at + delimiter.length
            word(text.substring(start, end))
            start = end
        }
        if (start < text.length) word(text.substring(start))
    }
}

/**
 * I pezzi che il tokenizer riconosce interi, prima di ogni pulizia: «<s>», «<mask>», in Gemma
 * anche gli a-capo, le tabulazioni e qualche tag. Come Hugging Face si prende quello che comincia
 * più a sinistra e, a parità, il più lungo.
 */
internal class AddedTokens(tokens: List<Pair<String, Int>>) {
    private val table = PieceTable(maxOf(16, tokens.size))
    /** Solo da questi caratteri può cominciare un pezzo intero: gli altri si saltano subito. */
    private val firsts = java.util.BitSet()

    init {
        for ((content, id) in tokens) {
            if (content.isEmpty()) continue
            table.put(content, id)
            firsts.set(content[0].code)
        }
    }

    /** Il testo a pezzi: i tratti normali vanno a [text], i pezzi interi a [token] col loro id. */
    fun split(s: String, text: (String) -> Unit, token: (Int) -> Unit) {
        var from = 0
        var i = 0
        while (i < s.length) {
            if (!firsts.get(s[i].code)) {
                i++
                continue
            }
            var best = -1
            var bestEnd = -1
            var h = 0
            val limit = minOf(s.length, i + table.maxLength)
            for (end in i + 1..limit) {
                h = 31 * h + s[end - 1].code
                val id = table.get(s, i, end, h)
                if (id >= 0) {
                    best = id
                    bestEnd = end
                }
            }
            if (best < 0) {
                i++
                continue
            }
            if (i > from) text(s.substring(from, i))
            token(best)
            from = bestEnd
            i = bestEnd
        }
        if (from < s.length) text(s.substring(from))
    }
}
