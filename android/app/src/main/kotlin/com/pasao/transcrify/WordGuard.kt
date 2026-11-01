package com.pasao.transcrify

/**
 * Controlla che la pulizia non abbia schiacciato il testo: confronta le parole prima e dopo.
 * Il tasso d'errore sulle parole (WER) è quante parole bisogna cambiare, togliere o aggiungere
 * per passare da un testo all'altro, diviso le parole di partenza. Correggere qualche errore lo
 * alza poco; tagliare un pezzo o riassumere lo alza molto.
 */
object WordGuard {
    private val WORD = Regex("""[\p{L}\p{N}]+""")

    private fun words(text: String) = WORD.findAll(text.lowercase()).map { it.value }.toList()

    /** Distanza di edit sulle parole, con due sole righe di memoria. */
    fun wer(before: String, after: String): Double {
        val a = words(before)
        val b = words(after)
        if (a.isEmpty()) return if (b.isEmpty()) 0.0 else 1.0
        var previous = IntArray(b.size + 1) { it }
        var current = IntArray(b.size + 1)
        for (i in a.indices) {
            current[0] = i + 1
            for (j in b.indices) {
                current[j + 1] = minOf(previous[j + 1] + 1, current[j] + 1, previous[j] + if (a[i] == b[j]) 0 else 1)
            }
            val swap = previous
            previous = current
            current = swap
        }
        return previous[b.size].toDouble() / a.size
    }
}
