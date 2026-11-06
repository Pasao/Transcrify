package com.pasao.transcrify

/**
 * «Detta qui» in una trascrizione aperta (5 nov, sua richiesta): la barra dell'app ha già i comandi, quindi la pillola
 * sul bordo si seppellisce del tutto dentro il bordo («sono due cose diverse»): ci scivola dentro con un piccolo
 * movimento, e finché è sepolta non si tocca. A dettatura finita (mandata e trascritta, buttata, errore) rispunta fuori
 * dove stava a riposo, con un piccolo rimbalzo. Rispunta anche se l'app va via (servono i suoi comandi) o se il foglio
 * si chiude a metà.
 */
object Dettatura {
    /** Sta ancora dettando (o trascrivendo) quella voce. */
    fun inCorso(phase: Phase) = phase == Phase.RECORDING || phase == Phase.PROCESSING

    /** [inApp]: la dettatura è partita da «Detta qui» e il foglio è ancora aperto; [appDavanti]: l'app si vede. */
    fun seppellisce(inApp: Boolean, appDavanti: Boolean, phase: Phase) = inApp && appDavanti && inCorso(phase)

    /**
     * Di quanto la pillola entra nel bordo (px): [quanto] 0 a riposo, 1 sepolta del tutto (oltre l'1 nel rimbalzo
     * si va sotto lo 0). [larghezza] è la sua finestra: spostata di tanto, verso il suo bordo, è tutta fuori schermo.
     */
    fun scostamento(quanto: Float, larghezza: Float, destra: Boolean) = (if (destra) 1f else -1f) * quanto * larghezza
}
