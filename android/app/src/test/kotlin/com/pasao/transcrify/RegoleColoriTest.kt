package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RegoleColoriTest {
    private val regole = mapOf("2:4" to RegolaColore("lavoro, preventivi, clienti", offuscaSempre = true), "5:4" to RegolaColore("spesa"))

    @Test
    fun `le regole vuote se ne vanno`() {
        // (Il JSON qui non c'è: org.json è di Android.)
        assertEquals(emptyMap<String, RegolaColore>(), RegoleColori.daJson(null))
        val tolta = RegoleColori.salva(regole, "5:4", RegolaColore("  "))
        assertFalse("5:4" in tolta)
        assertEquals(RegolaColore("casa"), RegoleColori.salva(regole, "7:4", RegolaColore("  casa ")).getValue("7:4"))
    }

    @Test
    fun `colorata da sola con offusca sempre diventa privata, mai sopra un colore tuo`() {
        val libera = Transcription("Il preventivo per il cliente.", 1, false)
        assertEquals(libera.copy(colore = "2:4", coloreAuto = true, privata = true), libera.colorataDaSola("2:4", offusca = true))
        assertEquals(libera.copy(colore = "5:4", coloreAuto = true), libera.colorataDaSola("5:4"))
        assertNull(libera.copy(colore = "5:4").colorataDaSola("2:4"))
        assertNull(libera.copy(privata = true).colorataDaSola("2:4"))
    }

    @Test
    fun `il colore messo da te con offusca sempre la rende privata`() {
        val t = Transcription("Testo.", 1, false)
        val messa = RegoleColori.segna(t, Segno(colore = true, nuovoColore = "2:4"), regole)
        assertTrue(messa.privata)
        assertFalse(messa.coloreAuto)
        // Un colore senza «offusca sempre» non la tocca; e se dici tu «non privata», vale quello.
        assertFalse(RegoleColori.segna(t, Segno(colore = true, nuovoColore = "5:4"), regole).privata)
        assertFalse(RegoleColori.segna(t, Segno(colore = true, nuovoColore = "2:4", privata = false), regole).privata)
    }

    @Test
    fun `annullare il colore messo da sola toglie anche la privata che aveva messo`() {
        val auto = Transcription("Testo.", 1, false).colorataDaSola("2:4", offusca = true)!!
        val annullata = RegoleColori.segna(auto, Segno(colore = true, nuovoColore = null), regole)
        assertNull(annullata.colore)
        assertFalse(annullata.privata)
        // Un colore tuo tolto: la privata resta com'era (l'avevi decisa tu).
        val tua = RegoleColori.segna(Transcription("Testo.", 1, false), Segno(colore = true, nuovoColore = "2:4"), regole)
        assertTrue(RegoleColori.segna(tua, Segno(colore = true, nuovoColore = null), regole).privata)
    }

    @Test
    fun `cambiare solo la privata non tocca il colore`() {
        val t = Transcription("Testo.", 1, false, colore = "5:4", coloreAuto = true)
        val s = RegoleColori.segna(t, Segno(privata = true), regole)
        assertEquals(t.copy(privata = true), s)
    }

    @Test
    fun `senza una regola scritta, la regola è il nome`() {
        val nomi = mapOf("5:4" to "Casa", "7:4" to " Palestra ", "9:4" to "Lavoro")
        val scritte = regole + ("9:4" to RegolaColore("", offuscaSempre = true))
        val e = RegoleColori.effettive(scritte, nomi)
        assertEquals("spesa", e.getValue("5:4").regola)
        assertEquals("Palestra", e.getValue("7:4").regola)
        assertEquals(RegolaColore("Lavoro", offuscaSempre = true), e.getValue("9:4"))
        assertEquals("lavoro, preventivi, clienti", e.getValue("2:4").regola)
    }

    @Test
    fun `offusca sempre vale anche per quelle che hanno già il colore, accesa e spenta`() {
        val storia = listOf(
            Transcription("A.", 1, false, colore = "2:4"),
            Transcription("B.", 2, false, colore = "2:4", privata = true),
            Transcription("C.", 3, false, colore = "5:4"),
            Transcription("D.", 4, false),
        )
        assertEquals(setOf(1L), RegoleColori.daCambiare(storia, "2:4", privata = true))
        // Spenta, tornano in vista tutte quelle di quel colore (anche quelle di prima).
        assertEquals(setOf(2L), RegoleColori.daCambiare(storia, "2:4", privata = false))
    }

    @Test
    fun `colora le sue di prima, e l'annulla torna esattamente com'era`() {
        val storia = listOf(
            Transcription("Il preventivo.", 1, false),
            Transcription("La spesa.", 2, false),
            Transcription("Il cliente, già blu.", 3, false, colore = "5:4"),
            Transcription("Il preventivo privato.", 4, false, privata = true),
            Transcription("Il preventivo nuovo.", 5, false),
        )
        // La regola rigida (qui finta) decide; prende solo quelle senza colore e non private.
        val decidi = { t: Transcription -> if (t.text.contains("preventivo") || t.text.contains("cliente")) "2:4" else "5:4" }
        val ats = RegoleColori.daColorare(storia, "2:4", decidi)
        assertEquals(listOf(1L, 5L), ats)
        val colorate = segna(storia, ats.toSet()) { it.colorataDaSola("2:4", offusca = true)!! }
        assertEquals(Transcription("Il preventivo.", 1, false, colore = "2:4", coloreAuto = true, privata = true), colorate[0])
        // Annulla: com'erano; una che nel frattempo hai ricolorato tu resta tua.
        val toccata = segna(colorate, setOf(5L)) { RegoleColori.segna(it, Segno(colore = true, nuovoColore = "7:4"), emptyMap()) }
        val annullate = segna(toccata, ats.toSet()) { RegoleColori.annullaColorata(it, offusca = true) }
        assertEquals(storia[0], annullate[0])
        assertEquals("7:4", annullate[4].colore)
        assertEquals(storia.subList(1, 4), annullate.subList(1, 4))
    }
}
