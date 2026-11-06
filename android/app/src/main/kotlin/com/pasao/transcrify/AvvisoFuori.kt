package com.pasao.transcrify

/**
 * La notifica mentre Transcri è fuori (Android la vuole per chi usa il microfono): cosa dice e i suoi tasti.
 * Android mette i tasti da sinistra a destra nell'ordine in cui si aggiungono: «Richiama» è sempre l'ultimo,
 * cioè il più a destra (6 nov, sua richiesta; con un tasto solo Android lo mette comunque a sinistra).
 */
object AvvisoFuori {
    const val TITOLO = "Transcrify"
    const val TESTO = "Per farlo rientrare, trascinalo nella sua casa in basso o tocca «Richiama»"

    /** Un tasto della notifica. [RICHIAMA]: torna a casa come col widget (e quello che stava sentendo si trascrive). */
    enum class Tasto(val etichetta: String) { RICHIAMA("Richiama") }

    /** I tasti nell'ordine in cui si aggiungono, da sinistra a destra: «Richiama» in fondo. */
    val tasti: List<Tasto> = Tasto.entries.sortedBy { it == Tasto.RICHIAMA }
}
