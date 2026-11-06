package com.pasao.transcrify.engine

import com.pasao.transcrify.perLeggere
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le espressioni del motore devono valere anche su Android (ICU), non solo qui (Java). Robolectric non c'è:
 * si fa partire ogni oggetto (così un'espressione che non compila esplode qui) e si cercano nei sorgenti
 * i segni che ICU non conosce. Era la causa di «ExceptionInInitializerError» nella prova del riassunto.
 */
class AndroidRegexTest {
    @Test
    fun gliOggettiDelRiassuntoPartono() {
        val t = "Allora, domani devo chiamare Marco alle otto. Cioè, il problema è il lavandino che perde ancora."
        assertTrue(Indizi.di(t) > 0f)
        assertTrue(Parlato.pulisci(t, Span(0, t.length)).testo.isNotEmpty())
        assertTrue(Tagli.di(t).isNotEmpty())
        assertEquals(1, Estratto.quante(1))
        assertEquals(listOf(0), Mmr.scegli(listOf(floatArrayOf(1f)), floatArrayOf(1f), 1, Estratto.LAMBDA))
    }

    @Test
    fun iConfiniValgonoAncheConGliAccenti() {
        // «cioè» finisce con una lettera accentata: con `\b` di Java (senza `(?U)`) non si troverebbe.
        assertTrue(Confini.parola("cioè").containsMatchIn("va bene, cioè, no"))
        assertTrue(Confini.parola("cioè").containsMatchIn("CIOÈ"))
        assertTrue(!Confini.parola("dai").containsMatchIn("andaiamo"))
        assertTrue(Indizi.di("ci vediamo lunedì") > 0f)
    }

    /** I segni di Java che ICU rifiuta o legge diversamente. */
    private val VIETATI = listOf(
        Regex("""\(\?[a-zA-Z]*[Uu][a-zA-Z]*[):]""") to "il segno (?U)/(?u): ICU non lo conosce",
        Regex("""UNICODE_CHARACTER_CLASS""") to "UNICODE_CHARACTER_CLASS: Android non lo accetta",
        Regex("""\\p\{(?:Is|In)?java""") to "le classi javaXxx esistono solo in Java",
        Regex("""[*+?]\+""") to "i quantificatori possessivi (*+, ++, ?+)",
    )

    @Test
    fun nessunSegnoCheAndroidNonCapisce() {
        val radice = File("src/main/kotlin")
        val sorgenti = radice.walk().filter { it.extension == "kt" }.toList()
        assertTrue("non trovo i sorgenti in ${radice.absolutePath}", sorgenti.isNotEmpty())
        val errori = sorgenti.flatMap { f ->
            f.readLines().withIndex().filter { "Regex(" in it.value || "toRegex" in it.value || "Pattern" in it.value }.flatMap { (i, riga) ->
                VIETATI.filter { (re, _) -> re.containsMatchIn(riga) }.map { (_, perché) -> "${f.name}:${i + 1}: $perché" }
            }
        }
        assertTrue(errori.joinToString("\n"), errori.isEmpty())
    }

    @Test
    fun lErroreSiLeggeFinoAllaCausa() {
        val e = ExceptionInInitializerError(IllegalArgumentException("Unsupported flags: 256"))
        assertEquals("ExceptionInInitializerError ← IllegalArgumentException: Unsupported flags: 256", e.perLeggere())
    }
}
