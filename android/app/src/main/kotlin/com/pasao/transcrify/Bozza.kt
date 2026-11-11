package com.pasao.transcrify

import java.io.File

/**
 * Dove eri arrivato, in pausa: il testo dei pezzi già registrati, chiesto a Groq una volta sola per pezzo
 * (ogni pausa lunga chiude un pezzo: [di] chiede solo quelli nuovi, mai due volte lo stesso). Se un pezzo non
 * arriva (niente rete) la bozza non c'è, e il cassetto mostra solo il tempo; alla pausa dopo si riprova.
 * Serve solo a far vedere: alla fine si trascrive tutto come sempre.
 */
class Bozza(private val trascrivi: (File) -> String?) {
    private val testi = mutableMapOf<String, String>()

    /** Quante richieste ha fatto: lo guardano le prove. */
    var richieste = 0
        private set

    @Synchronized
    fun di(pezzi: List<File>): String? {
        for (p in pezzi) {
            if (p.path in testi) continue
            richieste++
            testi[p.path] = trascrivi(p) ?: return null
        }
        return pezzi.joinToString(" ") { testi.getValue(it.path) }.trim().ifEmpty { null }
    }

    @Synchronized
    fun svuota() = testi.clear()

    companion object {
        /**
         * Quanto della bozza si vede: la fine, dove eri arrivato. 11 nov, suo: «…» e gli ultimi 5 secondi circa (si
         * parla a due parole e mezzo al secondo, sei lettere l'una: un'ottantina di caratteri).
         */
        const val CODA = 80

        /** «…» e la fine di [testo], da una parola intera; sempre coi puntini, è un pezzo di quello che hai detto. */
        fun coda(testo: String): String {
            val t = testo.trim()
            if (t.length <= CODA) return "…$t"
            val fine = t.takeLast(CODA)
            return "…" + fine.substringAfter(' ', fine).trimStart()
        }
    }
}
