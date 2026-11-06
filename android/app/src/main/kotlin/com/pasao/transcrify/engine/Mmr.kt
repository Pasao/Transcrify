package com.pasao.transcrify.engine

/**
 * La scelta MMR (Maximal Marginal Relevance, Carbonell e Goldstein 1998): una alla volta, la frase che
 * pesa di più tolta quanto somiglia a quelle già scelte. Così il riassunto non dice due volte la stessa cosa.
 */
object Mmr {
    /**
     * Gli indici di [k] frasi, nell'ordine del testo. [vettori] lunghi 1; [peso] quanto conta ogni frase;
     * [lambda] quanto conta il peso rispetto alla diversità (1 = solo il peso).
     */
    fun scegli(vettori: List<FloatArray>, peso: FloatArray, k: Int, lambda: Float): List<Int> {
        val scelte = ArrayList<Int>()
        while (scelte.size < minOf(k, vettori.size)) {
            var migliore = -1
            var valore = Float.NEGATIVE_INFINITY
            for (j in vettori.indices) {
                if (j in scelte) continue
                val simile = scelte.maxOfOrNull { Vec.dot(vettori[j], vettori[it]) } ?: 0f
                val v = lambda * peso[j] - (1 - lambda) * simile
                if (v > valore) {
                    migliore = j
                    valore = v
                }
            }
            scelte.add(migliore)
        }
        return scelte.sorted()
    }
}
