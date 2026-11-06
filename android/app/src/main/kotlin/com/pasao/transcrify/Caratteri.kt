package com.pasao.transcrify

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Gli stili di testo del design system (Figma B3, `lib/ui/ds/testo.dart`) per la parte nativa (Floater):
 * le stesse grandezze e gli stessi pesi, coi nomi di Figma. Il colore lo mette chi li usa.
 */
object Caratteri {
    /** 28 · il titolo di una pagina. */
    val titoloPagina = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold)

    /** 15 · un titolo piccolo. */
    val titoloScheda = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold)

    /** 14 · il testo. */
    val testo = TextStyle(fontSize = 14.sp)

    /** 16 · leggere: il testo di un vocale. */
    val testoGrande = TextStyle(fontSize = 16.sp, lineHeight = 23.sp)

    /** 13 · i titoletti, le voci. */
    val etichetta = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold)

    /** 13 · il tempo che scorre mentre registri: le cifre tutte larghe uguali («tnum»), così non ballano (come `Testo.orario`). */
    val tempo = etichetta.copy(fontFeatureSettings = "tnum")

    /** 12 · le scritte piccole («Copia ultima»). */
    val piccolo = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium)

    /** 11 · gli avvisi sotto i tasti, i modi. */
    val orario = TextStyle(fontSize = 11.sp, lineHeight = 14.sp)
}
