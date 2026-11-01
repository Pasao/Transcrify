package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WordGuardTest {
    private val text = "Domani vado a Lucca con gli amici e poi torno a casa la sera perché devo lavorare presto"

    @Test
    fun stessoTestoNonHaErrori() = assertEquals(0.0, WordGuard.wer(text, text), 0.0)

    @Test
    fun punteggiaturaEMaiuscoleNonContano() = assertEquals(0.0, WordGuard.wer("ciao, come stai?", "Ciao come stai"), 0.0)

    @Test
    fun unaCorrezioneCostaPoco() {
        val fixed = text.replace("Lucca", "Luca")
        assertEquals(1.0 / 18, WordGuard.wer(text, fixed), 1e-9)
    }

    @Test
    fun metaTestoTagliatoSiVede() {
        val half = text.split(" ").take(9).joinToString(" ")
        assertEquals(0.5, WordGuard.wer(text, half), 1e-9)
    }

    @Test
    fun unRiassuntoSuperaLaSoglia() = assertTrue(WordGuard.wer(text, "Vado a Lucca domani") > Store.GUARD_CLEAN)

    @Test
    fun vuoti() {
        assertEquals(0.0, WordGuard.wer("", ""), 0.0)
        assertEquals(1.0, WordGuard.wer("", "ciao"), 0.0)
        assertEquals(1.0, WordGuard.wer("ciao", ""), 0.0)
    }
}
