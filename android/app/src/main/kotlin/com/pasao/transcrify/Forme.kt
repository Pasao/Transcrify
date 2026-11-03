package com.pasao.transcrify

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** I raggi del design system (Figma B3, `lib/ui/ds/misure.dart` «Raggio») per la parte nativa. */
object Forme {
    /** raggio/pillola: le cose a capsula (righe, tasti, la barra dei modi). */
    val pillola = RoundedCornerShape(percent = 50)

    /** raggio/scheda (18): le schede (il vocale nel pannello). */
    val scheda = RoundedCornerShape(18.dp)

    /** raggio/foglio (28): i riquadri grandi. */
    val foglio = RoundedCornerShape(28.dp)
}
