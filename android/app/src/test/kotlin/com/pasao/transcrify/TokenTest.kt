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

    /** Il contrasto tra due colori (WCAG): da 1 a 21. */
    private fun contrasto(a: Int, b: Int): Double {
        fun lum(c: Int): Double {
            fun ch(v: Int): Double = (v / 255.0).let { if (it <= 0.03928) it / 12.92 else Math.pow((it + 0.055) / 1.055, 2.4) }
            return 0.2126 * ch(c shr 16 and 0xFF) + 0.7152 * ch(c shr 8 and 0xFF) + 0.0722 * ch(c and 0xFF)
        }
        val (x, y) = lum(a) to lum(b)
        return (maxOf(x, y) + 0.05) / (minOf(x, y) + 0.05)
    }

    /**
     * Il rosso del pericolo (`errore`) si legge dappertutto dove sta, con qualunque colore del telefono (6 nov: «il rosso
     * nella barra si legge male»): nell'app sulla pagina, sulle schede, sulle isole e sul fondo del cestino armato
     * (`erroreTenue`), nel chiaro e nello scuro; sul floater (sempre scuro: la barra delle scelte, la pillola) quello
     * del tema scuro, come fa `Palette`.
     */
    @Test
    fun `il rosso del pericolo si legge su ogni fondo, con ogni colore del telefono`() {
        val semi = listOf(0xFFF1917F, 0xFF3F6FD8, 0xFF2E9E5B, 0xFF8E44AD, 0xFFE5C100, 0xFF808080, 0xFFD32F2F, 0xFF00897B).map { it.toInt() }
        for (seme in semi) for (scuro in listOf(false, true)) {
            val t = Token.dal(seme, scuro)
            for ((nome, fondo) in listOf("pagina" to t.pagina, "scheda" to t.scheda, "isola" to t.isola, "erroreTenue" to t.erroreTenue)) {
                val k = contrasto(t.errore, fondo)
                assert(k >= 4.5) { "seme ${hex(seme)} scuro=$scuro: errore ${hex(t.errore)} su $nome ${hex(fondo)} = $k" }
            }
            val sospeso = Token.dal(seme, scuro = true)
            val k = contrasto(sospeso.errore, t.floater)
            assert(k >= 4.5) { "seme ${hex(seme)}: errore ${hex(sospeso.errore)} sul floater ${hex(t.floater)} = $k" }
        }
    }

    /**
     * Le schede staccano dalla pagina (6 nov, giro 7: «sembrano molto simili»): almeno 1,25:1, con ogni colore del
     * telefono, nel chiaro e nello scuro; e il testo (anche quello secondario) ci si legge sopra.
     */
    @Test
    fun `le schede staccano dalla pagina, con ogni colore del telefono`() {
        val semi = listOf(0xFFF1917F, 0xFF3F6FD8, 0xFF2E9E5B, 0xFF8E44AD, 0xFFE5C100, 0xFF808080, 0xFFD32F2F, 0xFF00897B).map { it.toInt() }
        for (seme in semi) for (scuro in listOf(false, true)) {
            val t = Token.dal(seme, scuro)
            val k = contrasto(t.scheda, t.pagina)
            assert(k >= 1.25) { "seme ${hex(seme)} scuro=$scuro: scheda ${hex(t.scheda)} su pagina ${hex(t.pagina)} = $k" }
            assert(contrasto(t.testo, t.scheda) >= 7) { "seme ${hex(seme)} scuro=$scuro: testo sulla scheda" }
            assert(contrasto(t.testoSecondario, t.scheda) >= 4.5) { "seme ${hex(seme)} scuro=$scuro: testo secondario sulla scheda" }
        }
        // I valori del salmone, da copiare nel Flutter (Colori._salmone*: il primo istante, prima che il telefono risponda).
        println("scheda salmone chiaro ${hex(Token.dal(0xFFF1917F.toInt(), false).scheda)} · scuro ${hex(Token.dal(0xFFF1917F.toInt(), true).scheda)}")
    }
}
