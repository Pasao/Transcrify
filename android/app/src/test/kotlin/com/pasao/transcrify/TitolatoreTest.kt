package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TitolatoreTest {
    private val storia = listOf(
        Transcription("Privata.", 50, false, privata = true),
        Transcription("Rinominata e poi svuotata.", 40, false, titoloChiesto = true, titoloUtente = true),
        Transcription("Senza titolo, la più nuova.", 30, false),
        Transcription("Con il suo titolo.", 20, false, titolo = "Il mio"),
        Transcription("Senza titolo, vecchia.", 10, false),
    )

    /** Come lo Store: il titolo si scrive sulla voce col suo «at» (Titolatore.passo). */
    private fun scrivi(l: List<Transcription>, t: Transcription, titolo: String) =
        segna(l, setOf(t.at)) { TitoliRegole.scrivi(it, titolo, t.text) }

    @Test
    fun `una volta sola, dalla più recente, anche le private, mai quelle toccate da te`() {
        // 7 nov sera: anche le private hanno il titolo (aiuta a orientarsi).
        assertEquals(50L, TitoliRegole.prossima(storia)?.at)
        var l = scrivi(storia, storia[0], "Il segreto")
        assertEquals(30L, TitoliRegole.prossima(l)?.at)
        l = scrivi(l, l[2], "Un titolo")
        assertEquals(10L, TitoliRegole.prossima(l)?.at)
        l = scrivi(l, l[4], "Altro")
        assertNull(TitoliRegole.prossima(l))
        // Una saltata in questo giro non torna subito.
        assertEquals(10L, TitoliRegole.prossima(storia, setOf(50L, 30L))?.at)
    }

    @Test
    fun `un titolo tuo arrivato nel frattempo non si tocca`() {
        val tua = Transcription("Testo.", 1, false, titolo = "Tuo", titoloChiesto = true, titoloUtente = true)
        assertEquals(tua, TitoliRegole.scrivi(tua, "Di Groq", "Testo."))
        // Una risposta vuota: segnata, senza titolo, e non si richiede.
        val vuota = TitoliRegole.scrivi(Transcription("Testo.", 1, false), "  ", "Testo.")
        assertNull(vuota.titolo)
        assertFalse(TitoliRegole.daFare(vuota))
    }

    @Test
    fun `ogni titolo finisce sulla sua trascrizione anche se intanto la lista cambia`() {
        // Si chiede il titolo di una, e mentre Groq risponde la lista cambia: ne arrivano di nuove in cima, una si
        // elimina, due si uniscono, un «Annulla» rimette com'era. Il titolo (qui: dal testo stesso) va sempre al suo.
        var l = (1..6).map { Transcription("Testo $it", it * 10L, false) }.sortedByDescending { it.at }
        val cambi = listOf<(List<Transcription>) -> List<Transcription>>(
            { listOf(Transcription("Nuova A", 100, false)) + it },
            { it.filter { t -> t.at != 20L } },
            { unisci(it, listOf(30L, 40L))!!.first },
            { rimetti(it, listOf(Transcription("Testo 3", 30, false), Transcription("Testo 4", 40, false))) },
            { listOf(Transcription("Nuova B", 110, false)) + it },
        )
        var giri = 0
        while (true) {
            val chiesta = TitoliRegole.prossima(l) ?: break
            l = cambi.getOrNull(giri++)?.invoke(l) ?: l
            l = scrivi(l, chiesta, "Titolo di «${chiesta.text}»")
            check(giri < 40)
        }
        // Tutte (quelle ancora lì) hanno il titolo del loro testo, nessuna quello di un'altra.
        for (t in l) assertEquals("${t.at}", "Titolo di «${t.text}»", t.titolo)
    }

    @Test
    fun `un titolo per un testo cambiato nel frattempo non si scrive`() {
        val prima = Transcription("Prima versione.", 1, false)
        val cambiata = prima.copy(text = "Seconda versione, tutta diversa.")
        assertEquals(cambiata, TitoliRegole.scrivi(cambiata, "Titolo vecchio", prima.text))
        assertTrue(TitoliRegole.daFare(cambiata))
    }

    @Test
    fun `unite, il titolo di Groq se ne va e si rifà, il tuo resta`() {
        val l = listOf(
            Transcription("Uno.", 2, false, titolo = "Di Groq", titoloChiesto = true),
            Transcription("Due.", 1, false, titolo = "Altro", titoloChiesto = true),
        )
        val fusa = unisci(l, listOf(2L, 1L))!!.second
        assertNull(fusa.titolo)
        assertTrue(TitoliRegole.daFare(fusa))
        val tua = unisci(l.map { if (it.at == 2L) it.copy(titoloUtente = true) else it }, listOf(2L, 1L))!!.second
        assertEquals("Di Groq", tua.titolo)
    }

    @Test
    fun `rifai i titoli toglie solo quelli di Groq`() {
        val groq = Transcription("A.", 1, false, titolo = "Di Groq", titoloChiesto = true)
        val tuo = Transcription("B.", 2, false, titolo = "Mio", titoloChiesto = true, titoloUtente = true)
        val senza = Transcription("C.", 3, false)
        assertTrue(TitoliRegole.daFare(TitoliRegole.rifai(groq)))
        assertNull(TitoliRegole.rifai(groq).titolo)
        assertEquals(tuo, TitoliRegole.rifai(tuo))
        assertEquals(senza, TitoliRegole.rifai(senza))
        // Rinominato da te: il titolo è tuo per sempre.
        val segnata = RegoleColori.segna(groq, Segno(titolo = true, nuovoTitolo = " Nuovo "), emptyMap())
        assertEquals("Nuovo", segnata.titolo)
        assertTrue(segnata.titoloUtente)
        assertEquals(segnata, TitoliRegole.rifai(segnata))
    }

    @Test
    fun `il ritmo, la pausa e le saltate`() {
        assertEquals(TitoliRegole.Passo(true, TitoliRegole.RITMO), TitoliRegole.dopo(TitoliRegole.Esito.Fatto("Ciao")))
        val limite = TitoliRegole.dopo(TitoliRegole.Esito.Errore(GroqError("Limite", codice = 429)))
        assertEquals(TitoliRegole.Passo(false, TitoliRegole.PAUSA_LIMITE), limite)
        assertTrue(TitoliRegole.PAUSA_LIMITE > TitoliRegole.RITMO)
        // Senza rete: si riprova da solo più avanti (prima si fermava fino alla prossima trascrizione).
        assertEquals(TitoliRegole.Passo(false, TitoliRegole.PAUSA_LIMITE), TitoliRegole.dopo(TitoliRegole.Esito.Errore(GroqError("Rete", offline = true))))
        assertEquals(TitoliRegole.Passo(false, null), TitoliRegole.dopo(TitoliRegole.Esito.Errore(GroqError("Chiave", codice = 401))))
        // «Groq si è fermato a 40»: una risposta tagliata o vuota non segna più la trascrizione per sempre.
        for (e in listOf("Risposta vuota", "Risposta tagliata")) {
            assertEquals(TitoliRegole.Passo(false, TitoliRegole.RITMO, salta = true), TitoliRegole.dopo(TitoliRegole.Esito.Errore(GroqError(e))))
        }
    }

    @Test
    fun `la rete non ferma mai i titoli con un errore`() {
        assertTrue(TitoliRegole.inRete { true })
        assertEquals(false, TitoliRegole.inRete { false })
        // Android non sa dirlo, o si rifiuta (il SecurityException senza permesso): si prova lo stesso.
        assertTrue(TitoliRegole.inRete { null })
        assertTrue(TitoliRegole.inRete { throw SecurityException("connectivity service neither user 10030") })
    }

    @Test
    fun `a Groq va l'inizio e un poco della fine`() {
        assertEquals("Corto.", TitoliRegole.perTitolo("  Corto.  "))
        val mandato = TitoliRegole.perTitolo("a".repeat(3000) + "FINE")
        assertTrue(mandato.startsWith("a".repeat(TitoliRegole.INIZIO)))
        assertTrue(mandato.endsWith("FINE"))
        assertTrue(mandato.length <= TitoliRegole.INIZIO + TitoliRegole.FINE + 3)
        // I modelli che ragionano: ragionamento corto, così la risposta non arriva tagliata.
        assertEquals(mapOf("reasoning_effort" to "low"), Groq.ragionamentoCorto("openai/gpt-oss-120b"))
        assertEquals(emptyMap<String, Any>(), Groq.ragionamentoCorto("llama-3.3-70b-versatile"))
    }

    @Test
    fun `la risposta ridotta al titolo`() {
        assertEquals("La spesa di sabato", Groq.pulisciTitolo("\n«La spesa di sabato.»\nAltro"))
        assertEquals("Idea per il regalo", Groq.pulisciTitolo("Titolo: \"Idea per il regalo\""))
        assertEquals("uno due tre quattro cinque sei sette otto", Groq.pulisciTitolo("uno due tre quattro cinque sei sette otto nove dieci"))
        assertEquals("", Groq.pulisciTitolo("  ...  "))
    }

    @Test
    fun `la riga delle Prove conta tutte e dice perché si ferma`() {
        // Anche le private contano; delle cinque, una ha il titolo.
        assertEquals(1 to 5, TitoliRegole.conta(storia))
        assertEquals("senza rete, riprova tra 10 minuti", TitoliRegole.motivo(GroqError("x", offline = true)))
        assertEquals("chiave non valida", TitoliRegole.motivo(GroqError("x", codice = 401)))
        assertNull(TitoliRegole.motivo(GroqError("Risposta tagliata")))
    }

    @Test
    fun `le private hanno il titolo per prime`() {
        // 10 nov: la scheda di una privata mostra solo il titolo; senza, un segnaposto. Passano davanti alle più nuove.
        val l = listOf(
            Transcription("Nuova.", 90, false),
            Transcription("Privata vecchia.", 5, false, privata = true),
            Transcription("Privata.", 40, false, privata = true),
        )
        assertEquals(40L, TitoliRegole.prossima(l)?.at)
        assertEquals(5L, TitoliRegole.prossima(l, setOf(40L))?.at)
        assertEquals(90L, TitoliRegole.prossima(l, setOf(40L, 5L))?.at)
    }
}
