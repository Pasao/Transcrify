package com.pasao.transcrify

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InoltroVoceTest {
    private val prima = mapOf("phase" to "RECORDING", "level" to 0.2, "seconds" to 3)

    @Test
    fun `il solo volume al piu ogni tanto, un cambio di stato subito`() {
        assertTrue(InoltroVoce.daMandare(null, prima, 0))
        assertFalse(InoltroVoce.daMandare(prima, prima + ("level" to 0.5), Durate.VOCE_MS - 1))
        assertTrue(InoltroVoce.daMandare(prima, prima + ("level" to 0.5), Durate.VOCE_MS))
        assertTrue(InoltroVoce.daMandare(prima, prima + ("seconds" to 4), 0))
        assertTrue(InoltroVoce.daMandare(prima, prima + ("phase" to "PROCESSING"), 0))
    }
}
