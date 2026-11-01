package com.pasao.transcrify

import org.junit.Assert.assertEquals
import org.junit.Test

class InsertPieceTest {
    @Test
    fun senzaCursoreVaInFondo() = assertEquals("Ciao.\n\nNuovo.", insertPiece("Ciao.", "Nuovo.", -1))

    @Test
    fun colCursoreInFondoVaInFondo() = assertEquals("Ciao.\n\nNuovo.", insertPiece("Ciao.", "Nuovo.", 5))

    @Test
    fun spaziFinaliNonContano() = assertEquals("Ciao.\n\nNuovo.", insertPiece("Ciao.  \n", "Nuovo.", 8))

    @Test
    fun allInizioMetteLoSpazioDopo() = assertEquals("Nuovo. Ciao.", insertPiece("Ciao.", "Nuovo.", 0))

    @Test
    fun inMezzoAUnaParolaLaSepara() = assertEquals("Ci Nuovo ao", insertPiece("Ciao", "Nuovo", 2))

    @Test
    fun dopoUnoSpazioNonNeAggiungeUnAltro() = assertEquals("Una Nuovo due", insertPiece("Una due", "Nuovo", 4))

    @Test
    fun cursoreVecchioOltreIlTesto() = assertEquals("Ciao\n\nNuovo", insertPiece("Ciao", "Nuovo", 99))

    @Test
    fun testoVuoto() = assertEquals("Nuovo", insertPiece("", "Nuovo", 0))
}
