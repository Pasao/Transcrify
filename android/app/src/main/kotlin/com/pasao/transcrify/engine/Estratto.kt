package com.pasao.transcrify.engine

import kotlin.math.ceil

/**
 * Il riassunto estrattivo: le tue frasi, scelte, senza scriverne di nuove.
 *
 * 1. Le frasi candidate ([Tagli]), pulite dai riempitivi per leggerle ([Parlato]); sotto [MIN_PAROLE]
 *    parole non si tengono.
 * 2. Il peso di ogni frase: metà quanto sta al centro del testo (coseno con la direzione media, da 0 a 1
 *    tra la meno e la più centrale), metà gli indizi del parlato ([Indizi]).
 * 3. La scelta ([Mmr]): pesanti e diverse tra loro, circa una ogni [OGNI] frasi, da 1 a [MASSIMO].
 *
 * Il modello serve solo per il senso delle frasi pulite (lo dà [senso], lunghi 1); il resto è puro calcolo.
 */
object Estratto {
    const val MIN_PAROLE = 5
    const val MASSIMO = 4
    const val OGNI = 2.2
    const val LAMBDA = 0.7f

    /** Le frasi che si possono scegliere: già pulite, quelle troppo corte no. */
    private fun candidate(text: String): List<Pulita> =
        Tagli.di(text).map { Parlato.pulisci(text, it) }.filter { parole(it.testo) >= MIN_PAROLE }

    /** Quante frasi si scelgono tra [n]. */
    fun quante(n: Int): Int = ceil(n / OGNI).toInt().coerceIn(1, MASSIMO)

    /** Il peso di ogni candidata: [vettori] dà la centralità, [originali] (le frasi come le hai dette) gli indizi. */
    private fun peso(vettori: List<FloatArray>, originali: List<String>): FloatArray {
        val centro = FloatArray(vettori[0].size)
        for (v in vettori) Vec.addTo(centro, v)
        val c = Vec.normalized(centro)
        val senso = FloatArray(vettori.size) { Vec.dot(vettori[it], c) }
        val min = senso.min()
        val ampio = (senso.max() - min).takeIf { it > 0f } ?: 1f
        return FloatArray(vettori.size) { 0.5f * (senso[it] - min) / ampio + 0.5f * Indizi.di(originali[it]) }
    }

    /** Le frasi scelte, nell'ordine del testo: dove stanno (per illuminarle) e come si leggono. */
    fun di(text: String, senso: (List<String>) -> List<FloatArray>): List<Pulita> {
        val cand = candidate(text)
        if (cand.isEmpty()) return emptyList()
        val vettori = senso(cand.map { it.testo })
        // Gli indizi si leggono sulla frase come l'hai detta (coi riempitivi in mezzo), non su quella pulita.
        val peso = peso(vettori, cand.map { it.span.of(text) })
        return Mmr.scegli(vettori, peso, quante(cand.size), LAMBDA).map { cand[it] }
    }

    private fun parole(s: String) = s.split(' ').count { it.isNotBlank() }
}
