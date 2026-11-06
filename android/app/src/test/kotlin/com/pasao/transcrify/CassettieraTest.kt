package com.pasao.transcrify

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** I cassetti del Floater: quali ci sono, uno solo aperto, la pausa che si apre e si chiude da sola. */
class CassettieraTest {
    private val fuso = File("src/main/kotlin/com/pasao/transcrify/CaretFuso.kt").readText()

    @Test
    fun quali() {
        assertEquals(emptyList<Carta>(), Cassettiera.quali(haUltima = false, vocali = false, inPausa = false))
        assertEquals(listOf(Carta.ULTIMA), Cassettiera.quali(haUltima = true, vocali = false, inPausa = false))
        assertEquals(listOf(Carta.ULTIMA, Carta.VOCALI, Carta.PAUSA), Cassettiera.quali(haUltima = true, vocali = true, inPausa = true))
        assertEquals(listOf(Carta.PAUSA), Cassettiera.quali(haUltima = false, vocali = false, inPausa = true))
    }

    @Test
    fun unoSoloAperto() {
        assertEquals(Carta.ULTIMA, Cassettiera.tocca(null, Carta.ULTIMA))
        assertNull(Cassettiera.tocca(Carta.ULTIMA, Carta.ULTIMA))
        // Aprendone un altro, quello aperto si chiude.
        assertEquals(Carta.VOCALI, Cassettiera.tocca(Carta.ULTIMA, Carta.VOCALI))
        // Un cassetto sparito non resta aperto.
        assertNull(Cassettiera.aperta(Carta.PAUSA, listOf(Carta.ULTIMA)))
    }

    @Test
    fun laPausaSiApreDaSolaDopoIlSuoTempo() {
        assertFalse(Cassettiera.pausaLunga(Durate.PAUSA_SI_APRE - 1))
        assertTrue(Cassettiera.pausaLunga(Durate.PAUSA_SI_APRE))
        assertEquals(Carta.ULTIMA, Cassettiera.pausa(Carta.ULTIMA, lunga = false, inPausa = true))
        assertEquals(Carta.PAUSA, Cassettiera.pausa(Carta.ULTIMA, lunga = true, inPausa = true))
    }

    @Test
    fun ripresoSiChiudeELasciaStareGliAltri() {
        assertNull(Cassettiera.pausa(Carta.PAUSA, lunga = false, inPausa = false))
        assertEquals(Carta.VOCALI, Cassettiera.pausa(Carta.VOCALI, lunga = false, inPausa = false))
    }

    @Test
    fun laBozzaSiChiedeUnaVoltaSolaPerPausa() {
        val chiesti = mutableListOf<String>()
        val bozza = Bozza { chiesti += it.name; "detto ${it.name}" }
        val a = File("a.m4a")
        val b = File("b.m4a")
        assertEquals("detto a.m4a", bozza.di(listOf(a)))
        assertEquals("detto a.m4a", bozza.di(listOf(a)))
        // La pausa dopo: solo il pezzo nuovo.
        assertEquals("detto a.m4a detto b.m4a", bozza.di(listOf(a, b)))
        assertEquals(listOf("a.m4a", "b.m4a"), chiesti)
        assertEquals(2, bozza.richieste)
    }

    @Test
    fun senzaReteNienteBozzaESiRiprovaAllaPausaDopo() {
        var rete = false
        val bozza = Bozza { if (rete) "ciao" else null }
        assertNull(bozza.di(listOf(File("a.m4a"))))
        rete = true
        assertEquals("ciao", bozza.di(listOf(File("a.m4a"))))
        assertEquals(2, bozza.richieste)
    }

    @Test
    fun laCodaMostraLaFine() {
        val lungo = "x".repeat(Bozza.CODA) + " fine"
        assertTrue(Bozza.coda(lungo).startsWith("…"))
        assertTrue(Bozza.coda(lungo).endsWith("fine"))
        assertEquals("breve", Bozza.coda("breve"))
    }

    @Test
    fun laFusioneUsaLoScatto() {
        assertTrue(fuso.contains("t.animateTo(1f, Scatto.molla())"))
        assertTrue(fuso.contains("t.animateTo(0f, Scatto.svelto())"))
        assertFalse("nessuna molla copiata", Regex("""\bspring\(|\btween\(""").containsMatchIn(fuso))
    }
}
