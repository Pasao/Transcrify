package com.pasao.transcrify

/**
 * Le misure della forma sola fatta da carta, ponte e cassetto aperto ([CarteFuse]), a un punto dello scatto. Senza
 * Android: si provano. Tutto arriva dalle misure in dp convertite (e dalla carta misurata), quindi la forma scala uguale
 * su ogni telefono, densità e grandezza del testo.
 *
 * 7 nov, sua richiesta: il ponte parte dai BORDI del cassetto (tutta la sua larghezza) e si apre in curva, larga, nel
 * fondo della carta. Un valore solo ([p], lo scatto della carta) muove tutto: niente animazioni separate che si
 * rincorrono (era quello lo scatto a singhiozzo).
 */
data class FormaFusa(
    /** La carta: sinistra, destra, fondo (la cima è 0) e il raggio dei suoi angoli. */
    val cartaL: Float, val cartaR: Float, val cartaGiu: Float, val raggio: Float,
    /** Il cassetto: i suoi bordi, la sua cima e la sua metà (fin lì il ponte lo abbraccia). */
    val caretL: Float, val caretR: Float, val caretSu: Float, val caretMeta: Float,
    /** Le spalle del cassetto: il raggio della sua pillola da chiuso, 0 da aperto (lì il ponte parte dai suoi bordi). */
    val spalla: Float,
    /** Quanto il ponte si allarga in curva verso la carta, a sinistra e a destra (mai oltre gli angoli della carta). */
    val svasoL: Float, val svasoR: Float,
) {
    /** Dove il ponte poggia sul cassetto: da aperto, i suoi bordi. */
    val baseL get() = caretL + spalla
    val baseR get() = caretR - spalla

    /** Il fondo del cassetto: il contorno di «Stai rispondendo» lo abbraccia tutto. */
    val caretGiu get() = caretMeta * 2 - caretSu

    /** Quanto è alto il ponte tra la carta e il cassetto. */
    val varco get() = caretSu - cartaGiu
}

object PonteFuso {
    /** Quanto il ponte si allarga verso la carta, rispetto alla sua altezza: le curve crescono col varco. */
    const val SVASO = 1.6f

    /**
     * [p] lo scatto (0 chiusa, 1 aperta; la molla può passare l'1). [largo] la riga intera, [caretX] dove sta il cassetto,
     * [cartaH] l'altezza misurata della carta aperta, [ponteH] l'altezza del ponte da aperto. Tutto in px.
     */
    fun misure(
        p: Float, largo: Float, caretX: Float, caretW: Float, caretH: Float,
        cartaH: Float, ponteH: Float, raggioScheda: Float,
    ): FormaFusa {
        val pieno = p.coerceIn(0f, 1f)
        val q = p.coerceAtLeast(0f)
        fun lerp(a: Float, b: Float) = a + (b - a) * pieno
        val cartaL = lerp(caretX, 0f)
        val cartaR = lerp(caretX + caretW, largo)
        val cartaGiu = cartaH * q
        val raggio = minOf(lerp(caretH / 2, raggioScheda), cartaGiu / 2, (cartaR - cartaL) / 2)
        val caretSu = cartaGiu + ponteH * q
        val spalla = caretH / 2 * (1f - pieno)
        val svaso = (caretSu - cartaGiu) * SVASO
        return FormaFusa(
            cartaL, cartaR, cartaGiu, raggio,
            caretX, caretX + caretW, caretSu, caretSu + caretH / 2,
            spalla,
            svasoL = minOf(svaso, (caretX + spalla - (cartaL + raggio)).coerceAtLeast(0f)),
            svasoR = minOf(svaso, (cartaR - raggio - (caretX + caretW - spalla)).coerceAtLeast(0f)),
        )
    }
}
