package com.pasao.transcrify.engine

/** Un pezzo di testo, da [start] (compreso) a [end] (escluso): così più avanti si può illuminare proprio lì. */
data class Span(val start: Int, val end: Int) {
    fun of(text: String): String = text.substring(start, end)
}

/**
 * Divide un testo in frasi, pensando all'italiano e alla dettatura.
 *
 * - Punto, punto esclamativo, punto interrogativo e puntini chiudono la frase quando dopo viene
 *   uno spazio e poi una maiuscola, un numero, una virgoletta o la fine.
 * - Le abbreviazioni («ecc.», «dott.», «pag.») e le iniziali («A. Rossi») non la chiudono.
 * - L'a-capo la chiude sempre: elenchi e paragrafi sono già confini.
 * - Le frasi dettate senza punti possono essere lunghissime: oltre [MAX_CHARS] si spezzano
 *   nella virgola o nella congiunzione più vicina al limite, così nessuna frase mescola tre argomenti.
 *
 * Tutto in un passaggio solo sul testo: O(n).
 */
object Sentences {
    const val MAX_CHARS = 240

    /** [maxChars]: oltre, una frase si spezza ([MAX_CHARS] di base; il riassunto estrattivo ne usa un altro, vedi [Tagli]). */
    fun split(text: String, maxChars: Int = MAX_CHARS): List<Span> {
        val out = ArrayList<Span>()
        var start = 0
        var i = 0
        val n = text.length
        while (i < n) {
            val c = text[i]
            if (c == '\n') {
                add(text, start, i, maxChars, out)
                start = i + 1
            } else if (c == '.' || c == '!' || c == '?' || c == '…') {
                // I segni di fila («?!», «...») restano attaccati alla frase.
                var j = i + 1
                while (j < n && (text[j] == '.' || text[j] == '!' || text[j] == '?' || text[j] == '…' || text[j] == '»' || text[j] == '"' || text[j] == ')')) j++
                if (closes(text, i, j)) {
                    add(text, start, j, maxChars, out)
                    start = j
                }
                i = j - 1
            }
            i++
        }
        add(text, start, n, maxChars, out)
        return out
    }

    /** Il segno in [dot], seguito da [after], chiude davvero la frase? */
    private fun closes(text: String, dot: Int, after: Int): Boolean {
        if (after >= text.length) return true
        if (!text[after].isWhitespace()) return false
        var k = after
        while (k < text.length && text[k].isWhitespace() && text[k] != '\n') k++
        if (k >= text.length || text[k] == '\n') return true
        val next = text[k]
        if (!(next.isUpperCase() || next.isDigit() || next in "«\"“'(•-")) return false
        if (text[dot] != '.') return true
        // Un punto dopo un'abbreviazione o un'iniziale non chiude.
        var w = dot
        while (w > 0 && text[w - 1].isLetter()) w--
        val word = text.substring(w, dot)
        if (word.length == 1 && word[0].isUpperCase()) return false
        return word.lowercase() !in ABBREVIATIONS
    }

    private fun add(text: String, from: Int, to: Int, max: Int, out: MutableList<Span>) {
        var a = from
        var b = to
        while (a < b && text[a].isWhitespace()) a++
        while (b > a && text[b - 1].isWhitespace()) b--
        if (a >= b) return
        // Un pallino o un trattino da elenco non è testo: la frase comincia dopo.
        while (a < b && (text[a] == '•' || text[a] == '-' || text[a] == '*') ) {
            a++
            while (a < b && text[a].isWhitespace()) a++
        }
        if (a >= b) return
        if (b - a <= max) {
            out.add(Span(a, b))
            return
        }
        // Troppo lunga: si spezza nel punto buono più vicino al limite, e si continua col resto.
        val cut = breakPoint(text, a, a + max, max)
        add(text, a, cut, max, out)
        add(text, cut, b, max, out)
    }

    /** Il punto dove spezzare tra [from] e [limit]: una virgola, poi una congiunzione; se non c'è, l'ultimo spazio. */
    private fun breakPoint(text: String, from: Int, limit: Int, max: Int): Int {
        val min = from + max / 3
        for (k in limit - 1 downTo min) if (text[k] == ',' || text[k] == ';' || text[k] == ':') return k + 1
        for (k in limit - 1 downTo min) {
            if (text[k] != ' ') continue
            for (c in CONJUNCTIONS) if (text.startsWith(c, k + 1) && k + 1 + c.length < text.length && text[k + 1 + c.length] == ' ') return k + 1
        }
        for (k in limit - 1 downTo from + 1) if (text[k] == ' ') return k + 1
        return limit
    }

    private val ABBREVIATIONS = setOf(
        "ecc", "etc", "es", "sig", "sigg", "sig.ra", "dott", "dr", "prof", "ing", "avv", "arch", "geom",
        "pag", "pagg", "cap", "capp", "art", "artt", "n", "nr", "vol", "ed", "cfr", "fig", "tel", "ca",
        "p", "pp", "s", "ss", "c", "cit", "op", "rif", "tab", "lett", "mr", "mrs", "st", "vs", "min", "max",
    )
    private val CONJUNCTIONS = listOf("e", "ma", "però", "poi", "quindi", "perché", "mentre", "invece", "oppure", "comunque", "anche")
}
