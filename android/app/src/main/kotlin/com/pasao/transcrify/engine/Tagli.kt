package com.pasao.transcrify.engine

/**
 * Le frasi candidate del riassunto estrattivo. Prima i punti ([Sentences]), poi le frasi lunghe dettate
 * senza punti si tagliano prima delle parole che aprono un pensiero nuovo («poi», «perché», «però»…):
 * «e poi» resta insieme (si taglia prima della «e»), e ogni taglio ha almeno [MIN_PAROLE] parole.
 */
object Tagli {
    /** Oltre questa lunghezza una frase si guarda per tagliarla nei pensieri. */
    const val LUNGA = 160

    /** Un taglio ha almeno tante parole: niente pezzetti. */
    const val MIN_PAROLE = 8

    private val APRE = setOf("poi", "perché", "però", "se", "ma", "quindi", "invece", "anche")
    private val PAROLA = Regex("\\S+")

    fun di(text: String): List<Span> = Sentences.split(text, Int.MAX_VALUE).flatMap { f ->
        if (f.end - f.start <= LUNGA) listOf(f) else pensieri(text, f).flatMap { troppoLunga(text, it) }
    }

    private fun pensieri(text: String, frase: Span): List<Span> {
        val parole = PAROLA.findAll(text.substring(frase.start, frase.end)).map { it.range }.toList()
        fun nuda(i: Int) = text.substring(frase.start + parole[i].first, frase.start + parole[i].last + 1)
            .lowercase().trim { !it.isLetter() }
        val out = ArrayList<Span>()
        var da = 0
        for (i in parole.indices) {
            val w = nuda(i)
            val apre = w in APRE || (w == "e" && i + 1 < parole.size && nuda(i + 1) in APRE)
            val dopoE = w in APRE && i > da && nuda(i - 1) == "e"
            if (apre && !dopoE && i - da >= MIN_PAROLE) {
                out.add(Span(frase.start + parole[da].first, frase.start + parole[i - 1].last + 1))
                da = i
            }
        }
        if (parole.isNotEmpty()) out.add(Span(frase.start + parole[da].first, frase.start + parole.last().last + 1))
        return out
    }

    /** Un pensiero ancora troppo lungo (nessuna parola che apre): lo spezza [Sentences] come sempre. */
    private fun troppoLunga(text: String, s: Span): List<Span> =
        if (s.end - s.start <= Sentences.MAX_CHARS) listOf(s)
        else Sentences.split(s.of(text)).map { Span(s.start + it.start, s.start + it.end) }
}
