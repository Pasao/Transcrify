package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 10 nov, sua richiesta: una pulizia non arriva mai tagliata. Groq qui è finto: si sceglie lui quando taglia. */
class PulituraTest {
    /** Le chiamate fatte: (testo, modello, tetto). */
    private val chiamate = mutableListOf<Triple<String, String, Int>>()

    /** Un Groq finto: pulisce mettendo il testo in maiuscolo; [taglia] decide quando si ferma a metà. */
    private fun finto(taglia: (testo: String, modello: String, tetto: Int) -> Boolean) = { testo: String, modello: String, tetto: Int ->
        chiamate += Triple(testo, modello, tetto)
        if (taglia(testo, modello, tetto)) Risposta(testo.uppercase().take(testo.length / 2), "length") else Risposta(testo.uppercase(), "stop")
    }

    private fun frasi(n: Int, lunga: Int = 60) = (1..n).joinToString(" ") { i -> "Frase numero $i " + "parola ".repeat(lunga / 7) + "fine." }

    @Test
    fun `una risposta tagliata non si accetta mai`() {
        val p = Pulitura("openai/gpt-oss-120b", chiedi = finto { _, _, _ -> true })
        val testo = "Una frase corta. E un'altra."
        // Tagliata sempre: restano le parole dette, intere (mai la metà pulita).
        assertEquals(testo, p.pulisci(testo))
        // Una risposta vuota vale come tagliata.
        assertFalse(Risposta("  ", "stop").intera)
        assertFalse(Risposta("metà", "length").intera)
        assertTrue(Risposta("tutto", "stop").intera)
    }

    @Test
    fun `tagliata, si riprova una volta col tetto doppio, alla riserva che non ragiona`() {
        val p = Pulitura("openai/gpt-oss-120b", "llama-3.3-70b-versatile", finto { _, modello, _ -> modello.contains("gpt-oss") })
        assertEquals("CIAO A TUTTI.", p.pulisci("Ciao a tutti."))
        assertEquals(2, chiamate.size)
        assertEquals("llama-3.3-70b-versatile", chiamate[1].second)
        assertEquals(Pulitura.tetto("Ciao a tutti.", "llama-3.3-70b-versatile") * 2, chiamate[1].third)
        // Senza riserva si riprova lo stesso modello, col tetto doppio.
        chiamate.clear()
        var prima = true
        Pulitura("openai/gpt-oss-120b", chiedi = finto { _, _, _ -> prima.also { prima = false } }).pulisci("Ciao.")
        assertEquals(listOf("openai/gpt-oss-120b", "openai/gpt-oss-120b"), chiamate.map { it.second })
        assertEquals(chiamate[0].third * 2, chiamate[1].third)
    }

    @Test
    fun `ancora tagliata, il pezzo si divide e si rifà a metà, senza perdere niente`() {
        val testo = frasi(150)
        assertTrue(testo.length > Pulitura.PEZZO)
        // Il finto taglia i pezzi lunghi più di 3000 caratteri: quelli da 8000 si dividono fino a stare sotto.
        val p = Pulitura("openai/gpt-oss-120b", chiedi = finto { t, _, _ -> t.length > 3000 })
        val fuori = p.pulisci(testo)
        assertEquals(testo.uppercase().split(Regex("""\s+""")), fuori.split(Regex("""\s+""")))
        assertTrue(chiamate.any { it.first.length <= 3000 })
    }

    @Test
    fun `l'ultima strada sono le parole dette, solo del pezzo che non riesce`() {
        val testo = frasi(60)
        // Un solo pezzo (quello con la frase 7) si taglia sempre, a qualunque misura.
        val p = Pulitura("openai/gpt-oss-120b", chiedi = finto { t, _, _ -> t.contains("numero 7 ") })
        val fuori = p.pulisci(testo)
        assertTrue(fuori.contains("Frase numero 7 parola"))
        assertTrue(fuori.contains("FRASE NUMERO 50 PAROLA"))
        assertEquals(testo.split(Regex("""\s+""")).size, fuori.split(Regex("""\s+""")).size)
    }

    @Test
    fun `il tetto cresce col testo e lascia posto al ragionamento`() {
        val corto = Pulitura.tetto("ciao", "llama-3.3-70b-versatile")
        val lungo = Pulitura.tetto("a".repeat(8000), "llama-3.3-70b-versatile")
        val ragiona = Pulitura.tetto("a".repeat(8000), "openai/gpt-oss-120b")
        assertEquals(512, corto)
        // 8000 caratteri ≈ 2286 token, × 1.6, più il ragionamento.
        assertEquals(3657 + 300, lungo)
        assertEquals(3657 + 2000, ragiona)
    }

    @Test
    fun `la riserva è un modello che non ragiona, solo se quello scelto ragiona`() {
        val offerti = listOf("llama-3.3-70b-versatile", "openai/gpt-oss-120b", "whisper-large-v3")
        assertEquals("llama-3.3-70b-versatile", Pulitura.riserva("openai/gpt-oss-120b", offerti))
        assertNull(Pulitura.riserva("llama-3.3-70b-versatile", offerti))
        assertNull(Pulitura.riserva("openai/gpt-oss-120b", listOf("whisper-large-v3")))
        assertTrue(Pulitura.NON_RAGIONANO.none(Pulitura::ragiona))
    }

    @Test
    fun `i pezzi si tagliano tra le frasi, una frase troppo lunga tra le parole`() {
        val lunga = "parola ".repeat(50).trim()
        val pezzi = Pulitura.pezzi("Prima. $lunga. Ultima.", 100)
        assertTrue(pezzi.all { it.length <= 100 })
        assertEquals("Prima. $lunga. Ultima.".split(' '), pezzi.joinToString(" ").split(' '))
    }

    @Test
    fun `un pezzo d'audio che non arriva si riprova, poi fa fallire tutto, mai saltato`() {
        var tentativi = 0
        val testo = Groq.tuttiIPezzi(listOf("a", "b", "c")) { p ->
            if (p == "b" && tentativi++ == 0) throw GroqError("Errore Groq (502)", codice = 502)
            p.uppercase()
        }
        assertEquals("A B C", testo)
        // Un errore che non passa (la chiave) o che si ripete: fallisce tutto, non esce un testo senza un pezzo.
        val chiave = runCatching { Groq.tuttiIPezzi(listOf("a", "b")) { p -> if (p == "b") throw GroqError("x", codice = 401) else p } }
        assertTrue(chiave.exceptionOrNull() is GroqError)
        val sempre = runCatching { Groq.tuttiIPezzi(listOf("a", "b")) { p -> if (p == "b") throw GroqError("x", codice = 503) else p } }
        assertTrue(sempre.exceptionOrNull() is GroqError)
        assertFalse(Groq.passeggero(GroqError("x", offline = true)))
    }
}
