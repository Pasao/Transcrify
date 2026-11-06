package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** «Detta qui»: la pillola si seppellisce nel bordo solo mentre detta nell'app, e rispunta in ogni altro caso. */
class DettaturaTest {
    @Test
    fun siSeppellisceMentreDettaETrascriveNellApp() {
        assertTrue(Dettatura.seppellisce(inApp = true, appDavanti = true, phase = Phase.RECORDING))
        assertTrue(Dettatura.seppellisce(inApp = true, appDavanti = true, phase = Phase.PROCESSING))
    }

    @Test
    fun rispuntaAFineDettatura() {
        for (fine in listOf(Phase.IDLE, Phase.SUCCESS, Phase.ERROR, Phase.LIMITED)) {
            assertFalse(fine.name, Dettatura.seppellisce(inApp = true, appDavanti = true, phase = fine))
        }
    }

    @Test
    fun rispuntaSeLAppVaViaOIlFoglioSiChiude() {
        assertFalse(Dettatura.seppellisce(inApp = true, appDavanti = false, phase = Phase.RECORDING))
        assertFalse(Dettatura.seppellisce(inApp = false, appDavanti = true, phase = Phase.RECORDING))
    }

    @Test
    fun sepoltaEsceTuttaVersoIlSuoBordo() {
        // Sepolta del tutto: spostata di tutta la sua finestra, fuori dallo schermo dal lato dove sta.
        assertEquals(120f, Dettatura.scostamento(1f, 120f, destra = true), 0f)
        assertEquals(-120f, Dettatura.scostamento(1f, 120f, destra = false), 0f)
        // A riposo resta dove stava (mezza fuori, come sempre: lo decide il suo sbirciare).
        assertEquals(0f, Dettatura.scostamento(0f, 120f, destra = true), 0f)
        // Il rimbalzo del ritorno la porta appena verso il centro, mai dal lato del bordo.
        assertTrue(Dettatura.scostamento(-0.1f, 120f, destra = true) < 0f)
        assertTrue(Dettatura.scostamento(-0.1f, 120f, destra = false) > 0f)
    }
}
