package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Test

class TokenTest {
    private fun hex(c: Int) = "#%06X".format(c and 0xFFFFFF)

    /** Gli stessi valori di Figma (B2, B5) per il salmone del telefono #F1917F. */
    @Test
    fun `i token del salmone sono quelli di Figma`() {
        val t = Token.dal(0xFFF1917F.toInt(), scuro = false)
        assertEquals("#FFA582", hex(t.transcriA))
        assertEquals("#E87545", hex(t.transcriB))
        assertEquals("#B7220C", hex(t.errore))
        assertEquals("#8A5100", hex(t.attenzione))
        assertEquals("#FFF8F6", hex(t.pagina))
        assertEquals("#954739", hex(t.azione))
        assertEquals("#F1917F", hex(t.azioneTenue))
        assertEquals("#221A18", hex(t.floater))
        // Di notte l'isola è più chiara della pagina, non più scura.
        val n = Token.dal(0xFFF1917F.toInt(), scuro = true)
        assert((n.isola and 0xFF) > (n.pagina and 0xFF)) { "isola ${hex(n.isola)} non più chiara della pagina ${hex(n.pagina)}" }
        println("azioneFondo chiaro ${hex(t.azioneFondo)}/${hex(t.suAzioneFondo)} · scuro ${hex(n.azioneFondo)}/${hex(n.suAzioneFondo)}")
    }

    /** Il fondo del widget non è l'arancione di Transcri: di giorno più chiaro di lui, di notte scuro. */
    @Test
    fun `il fondo del widget stacca da Transcri`() {
        val luce = { c: Int -> com.google.android.material.color.utilities.Hct.fromInt(c).tone }
        val g = Token.dal(0xFFF1917F.toInt(), scuro = false)
        val n = Token.dal(0xFFF1917F.toInt(), scuro = true)
        assert(luce(g.azioneFondo) - luce(g.transcriA) >= 10) { "di giorno ${hex(g.azioneFondo)} troppo vicino a ${hex(g.transcriA)}" }
        assert(luce(n.transcriB) - luce(n.azioneFondo) >= 25) { "di notte ${hex(n.azioneFondo)} troppo vicino a ${hex(n.transcriB)}" }
    }
}
