package com.pasao.transcrify

/**
 * Le regole dei cassetti del Floater (6 nov, sua richiesta: «fino a 3–4 caret»), senza disegno: quali ci sono,
 * quale è aperto. Ognuno apre la sua carta fondendosi con lei; uno solo aperto alla volta.
 * L'ordine è il suo: l'ultima trascrizione, il vocale che aspetta, la pausa.
 */
object Cassettiera {
    fun quali(haUltima: Boolean, vocali: Boolean, inPausa: Boolean): List<Carta> = buildList {
        if (haUltima) add(Carta.ULTIMA)
        if (vocali) add(Carta.VOCALI)
        if (inPausa) add(Carta.PAUSA)
    }

    /** Tocchi un cassetto: se era aperto si chiude, altrimenti si apre lui (e quello aperto prima si chiude). */
    fun tocca(aperta: Carta?, quale: Carta): Carta? = if (aperta == quale) null else quale

    /** Ferma da [ms]: oltre [Durate.PAUSA_SI_APRE] la pausa è lunga, e il suo cassetto si apre da solo. */
    fun pausaLunga(ms: Long): Boolean = ms >= Durate.PAUSA_SI_APRE

    /**
     * La pausa decide da sola: lunga, il suo cassetto si apre (al posto di quello aperto); ripreso, si chiude e
     * sparisce. Gli altri cassetti non li tocca.
     */
    fun pausa(aperta: Carta?, lunga: Boolean, inPausa: Boolean): Carta? = when {
        inPausa && lunga -> Carta.PAUSA
        !inPausa && aperta == Carta.PAUSA -> null
        else -> aperta
    }

    /** Quella aperta, se il suo cassetto c'è ancora (finiti i vocali, ripreso a parlare…). */
    fun aperta(aperta: Carta?, quali: List<Carta>): Carta? = aperta?.takeIf { it in quali }
}
