package com.pasao.transcrify.engine

/** Una frase pulita per leggerla: [testo] da mostrare, [span] dove sta nel testo originale (senza i riempitivi ai bordi). */
data class Pulita(val span: Span, val testo: String)

/**
 * Toglie i riempitivi del parlato («cioè», «tipo», «boh»…) da una frase, SOLO per mostrarla: si toglie,
 * non si inventa niente, e la frase resta legata al testo originale ([Pulita.span]) per illuminarla lì.
 *
 * Due liste, per non cambiare il senso:
 * - [SEMPRE]: suoni e intercalari che non dicono niente in nessun posto («eh», «boh», «cioè»).
 * - [SE_SCIOLTI]: parole che a volte sono intercalari e a volte no («non ho capito niente», «dai miei»,
 *   «è praticamente finito»): si tolgono solo se stanno da sole, in apertura o tra due segni («, dai,»).
 */
object Parlato {
    private val SEMPRE = listOf("ah", "ehi", "eh", "cioè", "insomma", "boh", "vabbè", "aspetta che la dico bene")
    private val SE_SCIOLTI = listOf("tipo", "capito", "niente", "allora", "praticamente", "comunque", "ecco", "dai", "ok")

    private val sempre = Confini.parola(SEMPRE.joinToString("|"))
    private val seSciolti = Confini.parola(SE_SCIOLTI.joinToString("|"))

    /** I segni intorno a un riempitivo: lo dicono «sciolto» («, dai,»). */
    private const val SEGNI = ",.?!;:"

    /** Quelli che si porta via, se li ha subito dopo («boh,», «capito?»). Il punto no: chiude la frase, resta. */
    private const val SUOI = ",?!;:"

    fun pulisci(text: String, frase: Span): Pulita {
        val via = riempitivi(text, frase)
        val sb = StringBuilder()
        var primo = -1
        var ultimo = -1
        var i = frase.start
        var v = 0
        while (i < frase.end) {
            if (v < via.size && i == via[v].first) {
                i = via[v++].last + 1
                continue
            }
            val c = text[i]
            if (c.isLetterOrDigit()) {
                if (primo < 0) primo = i
                ultimo = i
            } else if (c in "?!" && primo >= 0) ultimo = i
            sb.append(c)
            i++
        }
        if (primo < 0) return Pulita(Span(frase.start, frase.start), "")
        val pulito = sb.replace(Regex("\\s{2,}"), " ").replace(Regex("\\s+([,.?!;:])"), "$1")
            .replace(Regex("[,;:]+([.?!])"), "$1").trim(' ', ',', ';', ':', '\n')
        return Pulita(Span(primo, ultimo + 1), pulito.replaceFirstChar { it.uppercase() })
    }

    /** Gli intervalli da togliere (riempitivo + il segno e gli spazi che lo seguono), in ordine. */
    private fun riempitivi(text: String, frase: Span): List<IntRange> {
        val out = ArrayList<IntRange>()
        for (m in sempre.findAll(text.substring(frase.start, frase.end))) out.add(coda(text, frase, m.range))
        for (m in seSciolti.findAll(text.substring(frase.start, frase.end))) {
            val r = coda(text, frase, m.range)
            if (sciolto(text, frase, m.range, out)) out.add(r)
        }
        out.sortBy { it.first }
        return out
    }

    /** Il riempitivo [r] (relativo alla frase) e quello che gli va dietro, in posizioni del testo. */
    private fun coda(text: String, frase: Span, r: IntRange): IntRange {
        var e = frase.start + r.last + 1
        if (e < frase.end && text[e] in SUOI) e++
        while (e < frase.end && text[e].isWhitespace()) e++
        return (frase.start + r.first) until e
    }

    /** Sta da solo? In apertura (prima solo segni o riempitivi già tolti), oppure tra due segni. */
    private fun sciolto(text: String, frase: Span, r: IntRange, via: List<IntRange>): Boolean {
        var a = frase.start + r.first - 1
        while (a >= frase.start) {
            val c = text[a]
            val tolto = via.firstOrNull { a in it }
            when {
                tolto != null -> a = tolto.first - 1
                c.isWhitespace() -> a--
                else -> break
            }
        }
        if (a < frase.start) return true
        val dopo = frase.start + r.last + 1
        return text[a] in SEGNI && (dopo >= frase.end || text[dopo] in SEGNI)
    }
}
