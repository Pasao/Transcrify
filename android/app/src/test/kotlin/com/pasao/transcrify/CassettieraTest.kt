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
        assertEquals("…breve", Bozza.coda("breve"))
        // Da una parola intera, mai a metà.
        assertEquals("…fine", Bozza.coda("inizio " + "y".repeat(Bozza.CODA - 5) + " fine"))
    }

    @Test
    fun laFusioneUsaLoScatto() {
        assertTrue(fuso.contains("t.animateTo(1f, Scatto.molla())"))
        assertTrue(fuso.contains("t.animateTo(0f, Scatto.svelto())"))
        assertFalse("nessuna molla copiata", Regex("""\bspring\(|\btween\(""").containsMatchIn(fuso))
    }

    @Test
    fun unValoreSoloMuoveTutto() {
        // Carta, ponte, colore e freccia dallo stesso scatto: nessun'altra animazione che possa restare indietro.
        // Lo scatto non è più suo: arriva dal pannello (Coreografia), che ne prende anche la larghezza.
        assertEquals(0, Regex("""animate\w*AsState|Animatable\(""").findAll(fuso).count())
        assertTrue(fuso.contains("PonteFuso.misure("))
    }

    // Una carta aperta col cassetto in mezzo alla riga, in dp; [scala] = i px per dp del telefono.
    private fun forma(p: Float, scala: Float = 1f) =
        PonteFuso.misure(p, 300f * scala, 122f * scala, 56f * scala, 28f * scala, 200f * scala, 12f * scala, 24f * scala)

    private fun FormaFusa.numeri() =
        listOf(cartaL, cartaR, cartaGiu, raggio, caretL, caretR, caretSu, caretMeta, spalla, svasoL, svasoR)

    @Test
    fun ilPonteParteDaiBordiDelCassettoESiAllargaInCurva() {
        val f = forma(1f)
        assertEquals(122f, f.baseL, 0.01f)
        assertEquals(178f, f.baseR, 0.01f)
        assertEquals(12f, f.varco, 0.01f)
        // Le curve crescono col varco: più larghe del ponte alto.
        assertEquals(12f * PonteFuso.SVASO, f.svasoL, 0.01f)
        assertEquals(12f * PonteFuso.SVASO, f.svasoR, 0.01f)
        // Chiusa: niente carta, niente ponte, le spalle tonde del cassetto.
        val chiusa = forma(0f)
        assertEquals(0f, chiusa.varco, 0.01f)
        assertEquals(0f, chiusa.cartaGiu, 0.01f)
        assertEquals(14f, chiusa.spalla, 0.01f)
    }

    @Test
    fun laFormaScalaConLaDensita() {
        // Un telefono col doppio dei pixel per dp: tutto il doppio, la stessa forma (anche nel rimbalzo oltre l'1).
        for (p in listOf(0.3f, 0.7f, 1f, 1.08f)) {
            forma(p).numeri().zip(forma(p, 2f).numeri()).forEach { (a, b) -> assertEquals(a * 2, b, 0.01f) }
        }
    }
}
