package com.pasao.transcrify

/** I tempi del design system (Figma B3, `lib/ui/ds/misure.dart` «Durata») per la parte nativa, in millisecondi. */
object Durate {
    /** durata/veloce: aprire e chiudere i pannelli. */
    const val VELOCE = 150

    /** Quanto resta la conferma di un gesto (la ✓ di «Copiata»). */
    const val CONFERMA = 1400L

    /** Quanto resta armato il cestino dopo il primo tocco. */
    const val ARMATO = 2200L

    /**
     * Il successo «l'ultimo respiro» (Figma D2, riga 1 · B): smette di ondulare e si stringe, respira
     * (si gonfia) diventando verde, torna calmo. Movimento di Transcri, qui perché lo usano pillola e cerchio.
     */
    const val RESPIRO_STRINGE = 150
    const val RESPIRO_GONFIA = 200
    const val RESPIRO_POSA = 150

    /**
     * «Detta qui»: la pillola si seppellisce nel bordo (curva che rallenta in fondo) e, finita la dettatura, ne
     * rispunta con un piccolo rimbalzo ([RIMBALZO_RISPUNTA], quanto supera il riposo prima di posarsi).
     */
    const val SEPPELLISCE = 260
    const val RISPUNTA = 420
    const val RIMBALZO_RISPUNTA = 2.2f

    /**
     * Lo scatto del Floater (la molla con cui il pannello si apre dalla pillola): svelto, supera appena e si posa.
     * [SCATTO_SMORZAMENTO] sotto 1 = il piccolo rimbalzo; [SCATTO_RIGIDITA] = quanto è svelto. Lo usa [Scatto].
     */
    const val SCATTO_SMORZAMENTO = 0.68f
    const val SCATTO_RIGIDITA = 400f

    /**
     * La pausa del Floater: ferma da più di così, il suo cassetto si apre da solo e mostra dove eri arrivato
     * (le ultime parole, trascritte una volta sola per pausa). Lo usano [Session] e [Cassettiera].
     */
    const val PAUSA_SI_APRE = 3000L
}
