package com.pasao.transcrify.engine

/**
 * Le espressioni «parola intera» che valgono uguali sul telefono e nei test.
 *
 * Android non usa il motore delle espressioni di Java ma quello di ICU: non conosce il segno `(?U)`
 * (le classi `\w`/`\b` in Unicode) e chi lo usa fa cadere tutto l'oggetto alla prima chiamata
 * (ExceptionInInitializerError). Sul computer `\w` e `\b` invece guardano solo le lettere inglesi.
 * Così i confini si scrivono a mano con le classi Unicode (`\p{L}`, `\p{N}`), che entrambi capiscono.
 * Le maiuscole si ignorano con [RegexOption.IGNORE_CASE] (Kotlin ci aggiunge le lettere accentate).
 */
object Confini {
    /** Una lettera o una cifra, in qualunque lingua. */
    const val LETTERA = """[\p{L}\p{N}]"""

    /** Nessuna lettera prima: qui comincia una parola. */
    const val INIZIO = "(?<!$LETTERA)"

    /** Nessuna lettera dopo: qui finisce una parola. */
    const val FINE = "(?!$LETTERA)"

    /** Una delle [alternative] dall'inizio di una parola; con [intera] anche fino alla sua fine. */
    fun parola(alternative: String, intera: Boolean = true): Regex =
        Regex("$INIZIO(?:$alternative)${if (intera) FINE else ""}", RegexOption.IGNORE_CASE)
}
