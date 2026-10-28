package com.pasao.transcrify.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KeywordsTest {
    @Test
    fun phrasesKeepTheirWordsTogether() {
        val t = "Sono un product designer, e il portfolio deve mostrare l'idea: product designer vuol dire problemi veri."
        val p = Keywords.phrases(t).map { it.key }
        assertTrue(p.toString(), "product designer" in p)
        assertTrue(p.toString(), "portfolio" in p)
        assertTrue(p.toString(), "idea" in p)
        assertTrue(p.toString(), "mostrare" in p)
    }

    @Test
    fun aRepeatedPhraseWinsOverItsWords() {
        val k = Keywords()
        k.update("a", "Oggi la palestra e la spesa.")
        k.update("b", "Il quiz della patente, un quiz al giorno.")
        val t = "Il product designer pensa. Un product designer prova. Il portfolio del product designer."
        k.update("c", t)
        assertEquals("product designer", k.top(t, 1).first())
    }
}
