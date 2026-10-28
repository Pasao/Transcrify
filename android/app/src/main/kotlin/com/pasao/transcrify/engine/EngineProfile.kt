package com.pasao.transcrify.engine

/**
 * Le soglie del motore per un modello. Ogni modello ha la sua scala di somiglianze (e5 mette
 * quasi tutto tra 0,8 e 0,95, Gemma usa un tratto più largo): le stesse soglie per tutti
 * vorrebbero dire confini e album sbagliati per uno dei due. Si tarano una volta per modello.
 */
data class EngineProfile(
    /**
     * Quanto si allarga la profondità dei confini prima di salvarla in un byte: 1 / la profondità
     * che per questo modello è già un cambio netto. Così i 256 gradini servono tutti.
     */
    val depthScale: Float,
    /** Le soglie delle tre grane sulla profondità (0–255), dalla larga alla fine. */
    val coarse: Int,
    val medium: Int,
    val fine: Int,
    /** Quanto devono somigliarsi in media due pezzi per stare nello stesso album. */
    val pair: Float,
    /** Sotto questa coesione un album grande si spezza. */
    val split: Float,
) {
    init {
        require(coarse >= medium && medium >= fine) { "le grane vanno dalla larga alla fine" }
        require(split <= pair) { "un album appena unito non deve spezzarsi subito" }
    }

    fun threshold(grain: Grain): Int = when (grain) {
        Grain.COARSE -> coarse
        Grain.MEDIUM -> medium
        Grain.FINE -> fine
    }

    companion object {
        /** Per i vettori finti dei test (coseno ≈ 0,5 tra frasi vicine): non per un modello vero. */
        val DEFAULT = EngineProfile(depthScale = 1f, coarse = 90, medium = 50, fine = 24, pair = 0.38f, split = 0.26f)
    }
}
