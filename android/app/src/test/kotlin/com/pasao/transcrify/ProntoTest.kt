package com.pasao.transcrify

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Il Condividi (10 nov, suo: «la prima volta, svelto, dà errore come se non fosse pronto; dopo va»): quello che non è
 * ancora pronto si aspetta, non fallisce; e nel Condividi c'è una voce sola, «Trascrivi».
 */
class ProntoTest {
    @Test
    fun `aspetta finche non e pronto, un poco di piu ogni volta`() {
        val attese = mutableListOf<Long>()
        var volte = 0
        val chiave = Pronto.attendi(dorme = { attese += it }) { if (++volte < 3) null else "gsk_chiave" }
        assertEquals("gsk_chiave", chiave)
        assertEquals(listOf(Durate.PRONTO_PAUSA, Durate.PRONTO_PAUSA * 2), attese)
    }

    @Test
    fun `un errore vale come non ancora pronto, e dopo i tentativi si arrende`() {
        var volte = 0
        val attese = mutableListOf<Long>()
        assertNull(Pronto.attendi(tentativi = 4, dorme = { attese += it }) { volte++; throw IllegalStateException("Keystore") })
        assertEquals(4, volte)
        // Niente attesa dopo l'ultimo tentativo.
        assertEquals(3, attese.size)
        assertEquals("subito", Pronto.attendi(dorme = { error("non deve aspettare") }) { "subito" })
    }

    @Test
    fun `il condividi mette in coda aspettando il file e la chiave`() {
        val share = File("src/main/kotlin/com/pasao/transcrify/ShareAudio.kt").readText()
        assertTrue(share.contains("Pronto.attendi { enqueue(uri, store, queue) }"))
        assertTrue(share.contains("val chiave = store.chiavePronta()"))
        assertFalse(share.contains("store.apiKey == null"))
        val coda = File("src/main/kotlin/com/pasao/transcrify/Queue.kt").readText()
        assertTrue(coda.contains("store.chiavePronta() ?: return Outcome.Failed"))
    }

    @Test
    fun `nel condividi solo Trascrivi, tra le app e come scorciatoia in cima`() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        assertEquals(1, Regex("""android.intent.action.SEND"""").findAll(manifest).count())
        assertTrue(manifest.contains("android:label=\"Trascrivi\""))
        // 11 nov, suo: anche la scorciatoia in cima (la condivisione diretta), ma solo «Trascrivi», niente «con la nota».
        assertTrue(manifest.contains("@xml/share_shortcuts"))
        val scorciatoie = File("src/main/res/xml/share_shortcuts.xml").readText()
        assertEquals(1, Regex("<share-target").findAll(scorciatoie).count())
        assertTrue(scorciatoie.contains("category.TRANSCRIPTION"))
        assertFalse(scorciatoie.contains("THOUGHT"))
        val codice = File("src/main/kotlin/com/pasao/transcrify/ShareShortcuts.kt").readText()
        assertTrue(codice.contains("setShortLabel(\"Trascrivi\")"))
        assertFalse(codice.contains("THOUGHT"))
    }
}
