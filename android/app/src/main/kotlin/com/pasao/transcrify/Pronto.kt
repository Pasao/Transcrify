package com.pasao.transcrify

/**
 * Aspettare che una cosa sia pronta invece di fallire (10 nov, suo: «la prima volta che tocco Transcrify nel
 * Condividi, svelto, dà errore come se non fosse pronto; dopo va»). Con l'app appena svegliata dal Condividi il
 * Keystore può non rispondere al primo colpo (la chiave Groq sembra mancare) e l'app che condivide può non aver
 * ancora pronto il file: si riprova [tentativi] volte, aspettando un poco di più ogni volta, e solo dopo si arrende.
 * Senza Android: si prova.
 */
object Pronto {
    const val TENTATIVI = 6

    /** Il primo valore non nullo (e senza eccezioni) di [prova]; null se non arriva mai. [dorme] aspetta tra un tentativo e l'altro. */
    fun <T : Any> attendi(
        tentativi: Int = TENTATIVI,
        pausaMs: Long = Durate.PRONTO_PAUSA,
        dorme: (Long) -> Unit = { Thread.sleep(it) },
        prova: () -> T?,
    ): T? {
        for (i in 0 until tentativi) {
            runCatching(prova).getOrNull()?.let { return it }
            if (i < tentativi - 1) dorme(pausaMs * (i + 1))
        }
        return null
    }
}
