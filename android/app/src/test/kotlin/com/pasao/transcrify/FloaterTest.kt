package com.pasao.transcrify

import androidx.compose.animation.core.spring
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Il Floater: la carta esce con lo stesso scatto della pillola, e la notifica ha «Richiama» a destra. */
class FloaterTest {
    private val pillUi = File("src/main/kotlin/com/pasao/transcrify/PillUi.kt").readText()

    @Test
    fun loScattoEUnaMollaSolaCheSuperaAppena() {
        assertEquals(spring<Float>(0.68f, 400f), Scatto.molla<Float>())
        assertTrue("deve rimbalzare un poco", Durate.SCATTO_SMORZAMENTO < 1f)
    }

    @Test
    fun laPillolaELaCartaUsanoLoStessoScatto() {
        // La pillola che diventa pannello, e il pannello che cresce scoprendo la carta: la stessa molla.
        assertTrue(pillUi.contains("t.animateTo(1f, Scatto.molla())"))
        assertTrue(pillUi.contains("alto.animateTo(voluto, Scatto.molla())"))
        // Nessuna molla copiata a mano al posto dello scatto, e la carta non cresce più da sola (due molle in fila).
        assertFalse(pillUi.contains("dampingRatio = 0.68f"))
        assertFalse(pillUi.contains("expandVertically"))
    }

    @Test
    fun laNotificaHaRichiamaInFondo() {
        assertEquals(AvvisoFuori.Tasto.RICHIAMA, AvvisoFuori.tasti.last())
        assertEquals("Richiama", AvvisoFuori.Tasto.RICHIAMA.etichetta)
        assertFalse(AvvisoFuori.TESTO.contains("Chiudi"))
        assertTrue(AvvisoFuori.TESTO.contains("Richiama"))
    }
}
