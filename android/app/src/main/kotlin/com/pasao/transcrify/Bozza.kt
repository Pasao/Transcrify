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
        /** Quanto della bozza si vede: la fine, dove eri arrivato. */
        const val CODA = 160

        fun coda(testo: String): String = if (testo.length <= CODA) testo else "…" + testo.takeLast(CODA).trimStart()
    }
}
