package com.pasao.transcrify.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RicercaTest {
    private fun v(vararg x: Float) = Int8Vec.of(Vec.normalized(x))

    @Test
    fun laFraseMiglioreDiOgniFonteDallaPiuVicina() {
        val r = Ricerca()
        r.metti("n:a", listOf(Span(0, 5) to v(1f, 0f, 0f), Span(6, 9) to v(0.8f, 0.6f, 0f)))
        r.metti("t:1", listOf(Span(0, 4) to v(0f, 1f, 0f)))
        r.metti("t:2", listOf(Span(0, 4) to v(0f, 0f, 1f)))
        val trovati = r.cerca(Vec.normalized(floatArrayOf(0.7f, 0.7f, 0f)), quante = 10, minimo = 0.5f, banda = 0.3f)
        assertEquals(listOf("n:a", "t:1"), trovati.map { it.fonte })
        assertEquals(Span(6, 9), trovati.first().span)
    }

    @Test
    fun unaFonteVuotaEsceDallaRicerca() {
        val r = Ricerca()
        r.metti("n:a", listOf(Span(0, 1) to v(1f, 0f)))
        r.metti("n:a", emptyList())
        assertEquals(emptySet<String>(), r.fonti)
    }

    @Test
    fun perParolaSenzaMaiuscoleNeAccenti() {
        val t = "Domani chiamo il Dentista. Poi caffè"
        assertEquals(t.indexOf("Dentista"), Parole.trova(t, Parole.di("dentista CAFFE")))
        assertNull(Parole.trova(t, Parole.di("dentista pane")))
    }

    @Test
    fun perParolaPrimaLaPiuRecenteTraNoteETrascrizioni() {
        val fonti = listOf(
            Parole.Fonte("n:vecchia", "Il dentista domani", quando = 10),
            Parole.Fonte("n:altro", "Niente qui", quando = 50),
            Parole.Fonte("t:30", "Chiamare il dentista. Poi pane", quando = 30),
            Parole.Fonte("t:40", "Prima frase. Dal dentista alle tre", quando = 40),
        )
        val trovati = Parole.esatti(fonti, Parole.di("dentista"))
        assertEquals(listOf("t:40", "t:30", "n:vecchia"), trovati.map { it.fonte })
        assertEquals(true, trovati.first().span.of(fonti[3].testo).contains("Dal dentista"))
    }
}
