package com.pasao.transcrify.engine

/**
 * Gli indizi del parlato che dicono «questa frase conta»: scadenze, doveri, decisioni, giorni, ore,
 * numeri, nomi di persone e posti. Nel riassunto estrattivo pesano quanto il senso ([Estratto]).
 */
object Indizi {
    /** Oltre tanti indizi una frase non conta di più: tre bastano per dire «questa è importante». */
    const val MASSIMO = 3

    private val LISTA = listOf(
        "entro", "devo", "dobbiamo", "va sistemat", "serve", "decisione", "importante", "il punto", "il problema",
        "ricordar", "lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica|domani",
        "\\d+", "alle (?:una|due|tre|quattro|cinque|sei|sette|otto|nove|dieci|undici|dodici|\\d)", "fammi sapere",
        "se piove|se no${Confini.FINE}", "vorrei|sarebbe",
    ).map { Confini.parola(it, intera = false) }

    /** Un nome proprio a metà frase: una maiuscola dopo una parola e uno spazio. */
    private val NOME = Regex("(?<=${Confini.LETTERA} )\\p{Lu}\\p{Ll}+")

    /** Da 0 a 1: quanti indizi ha la frase, fino a [MASSIMO]. */
    fun di(frase: String): Float {
        val n = LISTA.count { it.containsMatchIn(frase) } + NOME.findAll(frase).count()
        return minOf(n, MASSIMO).toFloat() / MASSIMO
    }
}
