package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/** «Proponi etichette» e la regola di un'etichetta nuova (10 nov). Groq qui è finto: si sceglie lui cosa risponde. */
class ProposteTest {
    @Test
    fun `a Groq vanno solo i titoli, una volta sola`() {
        assertEquals("Cena con Marta\nPreventivo bagno", Proposte.perGroq(listOf(" Cena con Marta ", "", "cena con marta", "Preventivo bagno")))
        assertEquals(Proposte.TITOLI, Proposte.perGroq((1..500).map { "Titolo $it" }).lines().size)
    }

    @Test
    fun `le etichette che hai vanno a Groq, perché non le doppi`() {
        val testo = Proposte.perGroq(listOf("Cena con Marta"), listOf("Lavoro", " Casa "))
        assertEquals("Cena con Marta\n\nEtichette che ho già, da non riproporre: Lavoro, Casa", testo)
        assertEquals("Cena con Marta", Proposte.perGroq(listOf("Cena con Marta"), listOf(" ")))
    }

    @Test
    fun `proponi regole - solo i titoli e le etichette, e torna una regola per quelle che hai`() {
        assertEquals(
            "Cena con Marta\n\nEtichette:\nLavoro: Lavoro\nCasa: spesa",
            Proposte.perRegole(listOf("Cena con Marta"), mapOf("Lavoro" to "Lavoro", "Casa" to "spesa")),
        )
        val risposta = """
            - **lavoro**: preventivi, clienti, riunioni.
            Casa: spesa, bollette, pulizie
            Viaggi: treni, alberghi
        """.trimIndent()
        // «Viaggi» non è tua: non si propone; il nome resta com'è tuo.
        assertEquals(
            mapOf("Lavoro" to "preventivi, clienti, riunioni", "Casa" to "spesa, bollette, pulizie"),
            Proposte.leggiRegole(risposta, listOf("Lavoro", "Casa")),
        )
        // Tante etichette: nessuna tagliata dal massimo delle proposte nuove.
        val tante = (1..12).map { "E$it" }
        assertEquals(12, Proposte.leggiRegole(tante.joinToString("\n") { "$it: a, b" }, tante).size)
    }

    @Test
    fun `la risposta diventa etichette, senza doppioni e senza quelle che hai`() {
        val risposta = """
            Ecco le etichette:
            1. **relazioni**: amore, dolore, sentimenti, emozioni.
            - Lavoro: clienti, preventivi, cantiere
            • «Casa»: spesa, bollette
            Relazioni: di nuovo
            salute: medico, palestra
            idee: progetti, app
        """.trimIndent()
        val proposte = Proposte.leggi(risposta, esistenti = listOf("idee"))
        assertEquals(listOf("Relazioni", "Lavoro", "Casa", "Salute"), proposte.map { it.nome })
        assertEquals("amore, dolore, sentimenti, emozioni", proposte[0].regola)
        // Mai più di otto.
        assertEquals(Proposte.MASSIMO, Proposte.leggi((1..12).joinToString("\n") { "nome$it: cosa $it" }).size)
    }

    @Test
    fun `una risposta tagliata non si accetta mai`() {
        val tetti = mutableListOf<Int>()
        // Tagliata al primo tetto: si riprova col più largo, e si prende quella intera.
        val intera = Risposta.primaIntera(listOf(1200, 4000)) { tetto ->
            tetti += tetto
            if (tetto < 4000) Risposta("relazioni: amo", "length") else Risposta("relazioni: amore, dolore", "stop")
        }
        assertEquals(listOf(1200, 4000), tetti)
        assertEquals("relazioni: amore, dolore", intera.testo)
        // Sempre tagliata (o vuota): un errore, mai la metà.
        assertThrows(GroqError::class.java) { Risposta.primaIntera(listOf(1200, 4000)) { Risposta("metà", "length") } }
        assertThrows(GroqError::class.java) { Risposta.primaIntera(listOf(1200)) { Risposta("  ", "stop") } }
    }

    @Test
    fun `la regola proposta si scrive solo se non l'hai scritta tu`() {
        assertEquals("amore, dolore, sentimenti", Proposte.regola("Regola: «amore, dolore, sentimenti.»\naltro"))
        assertEquals(RegolaColore("amore, dolore"), Proposte.daSalvare("amore, dolore", null, "Relazioni", "Relazioni"))
        // «Offusca sempre» acceso resta.
        assertEquals(RegolaColore("amore", true), Proposte.daSalvare("amore", RegolaColore("", true), "Relazioni", "Relazioni"))
        // L'hai scritta tu nel frattempo, o hai cambiato nome, o Groq non ha detto niente: non si tocca.
        assertNull(Proposte.daSalvare("amore", RegolaColore("mia"), "Relazioni", "Relazioni"))
        assertNull(Proposte.daSalvare("amore", null, "Relazioni", "Amori"))
        assertNull(Proposte.daSalvare(" ", null, "Relazioni", "Relazioni"))
    }
}
