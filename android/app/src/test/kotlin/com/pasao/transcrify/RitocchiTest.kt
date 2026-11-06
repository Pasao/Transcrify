package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RitocchiTest {
    private val storia = listOf(
        Transcription("Tre.", 30, true, "pulita", colore = "0:4", privata = true, titolo = "Il treno"),
        Transcription("Due.", 20, false, "fedele", source = "whatsapp"),
        Transcription("Uno.", 10, true, "riassunto", colore = "3:4"),
        Transcription("Fuori.", 5, false),
    )

    @Test
    fun uneNellOrdineSceltoConUnaRigaVuota() {
        val (resto, fusa) = unisci(storia, listOf(20, 30, 10))!!
        assertEquals("Due.\n\nTre.\n\nUno.", fusa.text)
        assertEquals(listOf(10L, 5L), resto.map { it.at })
    }

    @Test
    fun tieneIlGiornoDellaPiuVecchiaEIlRestoDellaPrima() {
        val (_, fusa) = unisci(storia, listOf(30, 10))!!
        assertEquals(10L, fusa.at)
        assertEquals("0:4", fusa.colore)
        assertEquals(true, fusa.privata)
        assertEquals("pulita", fusa.mode)
    }

    @Test
    fun unaSolaNonSiUnisce() = assertNull(unisci(storia, listOf(20, 99)))

    @Test
    fun annullaRimetteTuttoComEra() {
        val (resto, _) = unisci(storia, listOf(20, 30, 10))!!
        assertEquals(storia, rimetti(resto, storia.take(3)))
    }

    @Test
    fun ilTitoloVaEVieneDallApp() {
        // Andata e ritorno come col canale: il titolo resta; quelle di prima dei titoli arrivano senza.
        assertEquals(storia, storia.map { Transcription.fromMap(it.toMap()) })
        assertEquals("Il treno", storia.first().toMap()["titolo"])
        assertNull(Transcription.fromMap(mapOf("text" to "Vecchia.", "at" to 1L, "purified" to false)).titolo)
    }

    @Test
    fun lUnitaTieneIlTitoloDellaPrima() {
        val (_, fusa) = unisci(storia, listOf(30, 20))!!
        assertEquals("Il treno", fusa.titolo)
        assertNull(unisci(storia, listOf(20, 30))!!.second.titolo)
    }

    @Test
    fun segnaCambiaSoloQuelleScelte() {
        val dopo = segna(storia, setOf(20L, 5L)) { it.copy(colore = "6:1") }
        assertEquals(listOf("0:4", "6:1", "3:4", "6:1"), dopo.map { it.colore })
    }
}
