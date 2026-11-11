package com.pasao.transcrify

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** «Colora da sola» propone, non cambia (10 nov): le proposte, rifiutate che non tornano, accettate col colore. */
class ProposteColoreTest {
    private val regole = mapOf("2:4" to RegolaColore("lavoro", offuscaSempre = true), "5:4" to RegolaColore("spesa"))

    @Test
    fun `le proposte nuove si aggiungono, mai una rifiutata`() {
        val rifiutate = setOf(ProposteColore.chiave(3, "5:4"))
        assertEquals(mapOf(1L to "2:4", 2L to "5:4"), ProposteColore.aggiorna(mapOf(1L to "2:4"), mapOf(2L to "5:4", 3L to "5:4"), rifiutate, tutte = false))
        // Rifiutata con un colore, con un altro si può proporre.
        assertEquals(mapOf(3L to "2:4"), ProposteColore.aggiorna(emptyMap(), mapOf(3L to "2:4"), rifiutate, tutte = false))
        // Ricalcolate tutte (le regole sono cambiate): quelle di prima che non tornano se ne vanno.
        assertEquals(mapOf(2L to "5:4"), ProposteColore.aggiorna(mapOf(1L to "2:4"), mapOf(2L to "5:4"), emptySet(), tutte = true))
    }

    @Test
    fun `valgono solo per quelle ancora senza colore e in vista`() {
        val storia = listOf(
            Transcription("A.", 1, false),
            Transcription("B.", 2, false, colore = "5:4"),
            Transcription("C.", 3, false, privata = true),
        )
        assertEquals(mapOf(1L to "2:4"), ProposteColore.valide(mapOf(1L to "2:4", 2L to "2:4", 3L to "2:4", 4L to "2:4"), storia))
    }

    @Test
    fun `rifiutata esce e si ricorda`() {
        val (proposte, rifiutate) = ProposteColore.rifiuta(mapOf(1L to "2:4", 2L to "5:4"), emptySet(), 1)
        assertEquals(mapOf(2L to "5:4"), proposte)
        assertEquals(setOf("1=2:4"), rifiutate)
        assertEquals(rifiutate, ProposteColore.rifiuta(proposte, rifiutate, 9).second)
    }

    @Test
    fun `scarta tutte le rifiuta tutte, e non tornano`() {
        val (proposte, rifiutate) = ProposteColore.rifiutaTutte(mapOf(1L to "2:4", 2L to "5:4"), setOf("9=0:4"))
        assertTrue(proposte.isEmpty())
        assertEquals(setOf("9=0:4", ProposteColore.chiave(1, "2:4"), ProposteColore.chiave(2, "5:4")), rifiutate)
    }

    @Test
    fun `accettata prende il colore come tuo, e offusca sempre la rende privata`() {
        val t = Transcription("A.", 1, false)
        val lavoro = ProposteColore.accetta(t, "2:4", regole)
        assertEquals("2:4", lavoro.colore)
        assertTrue(lavoro.privata)
        assertFalse(lavoro.coloreAuto)
        assertFalse(ProposteColore.accetta(t, "5:4", regole).privata)
        // Nel frattempo l'hai colorata tu: resta com'è.
        val tua = t.copy(colore = "5:4")
        assertEquals(tua, ProposteColore.accetta(tua, "2:4", regole))
    }

    @Test
    fun `il nativo non colora piu da solo, propone`() {
        val lavoro = File("src/main/kotlin/com/pasao/transcrify/NoteTopicsWorker.kt").readText()
        val proponi = lavoro.substring(lavoro.indexOf("private fun proponi("), lavoro.indexOf("fun coloraRetro("))
        assertFalse(proponi.contains("store.cambia("))
        assertTrue(proponi.contains("store.proposteColore = dopo"))
        val app = File("src/main/kotlin/com/pasao/transcrify/MainActivity.kt").readText()
        for (metodo in listOf("\"proposteColore\"", "\"accettaProposta\"", "\"rifiutaProposta\"", "\"accettaTutte\"")) assertTrue(metodo, app.contains("$metodo ->"))
        assertFalse(app.contains("coloratiRetro"))
    }
}
