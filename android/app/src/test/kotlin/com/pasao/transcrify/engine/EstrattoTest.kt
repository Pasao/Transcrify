package com.pasao.transcrify.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Il riassunto estrattivo senza modello: tagli, pulizia, indizi, scelta. Col modello vero: [EstrattoBancoTest]. */
class EstrattoTest {
    private fun pulita(t: String) = Parlato.pulisci(t, Span(0, t.length))

    @Test
    fun iRiempitiviSpariscono() {
        val t = "Allora, cioè, oggi giornata lunga, tipo sono uscito alle otto."
        val p = pulita(t)
        assertEquals("Oggi giornata lunga, tipo sono uscito alle otto.", p.testo)
        // La frase resta legata al testo: comincia a «oggi», finisce prima del punto.
        assertEquals("oggi giornata lunga, tipo sono uscito alle otto", p.span.of(t))
    }

    @Test
    fun leParoleDoppieRestanoQuandoHannoUnSenso() {
        assertEquals("Non ho capito niente di quello che ha detto.", pulita("Non ho capito niente di quello che ha detto, boh.").testo)
        assertEquals("È praticamente finito, porta il vino.", pulita("È praticamente finito, eh, porta il vino, dai.").testo)
        assertEquals("Vengo dai miei domani", pulita("Vengo dai miei domani").testo)
    }

    @Test
    fun soloRiempitiviRestaVuota() {
        val p = pulita("Boh, insomma, capito?")
        assertEquals("", p.testo)
    }

    @Test
    fun ilDettatoSenzaPuntiSiTagliaNeiPensieri() {
        val t = "allora praticamente domani devo passare in comune per i documenti della carta d'identità che scade a dicembre " +
            "e poi tipo chiamare l'idraulico perché il lavandino perde ancora e insomma se ho tempo passo anche in ferramenta"
        val pezzi = Tagli.di(t).map { it.of(t) }
        assertTrue(pezzi.toString(), pezzi.size >= 3)
        // «e poi» resta insieme, all'inizio del pezzo nuovo.
        assertTrue(pezzi.toString(), pezzi.any { it.startsWith("e poi tipo chiamare") })
        // Ogni taglio ha almeno 8 parole, tranne al più l'ultimo.
        assertTrue(pezzi.toString(), pezzi.dropLast(1).all { it.split(' ').size >= Tagli.MIN_PAROLE })
        // I pezzi sono il testo, in ordine, senza buchi tranne gli spazi.
        assertEquals(t.replace(" ", ""), pezzi.joinToString("").replace(" ", ""))
    }

    @Test
    fun leFrasiCortePuntateNonSiTagliano() {
        val t = "Domani vado al mare. Poi se piove resto a casa."
        assertEquals(listOf("Domani vado al mare.", "Poi se piove resto a casa."), Tagli.di(t).map { it.of(t) })
    }

    @Test
    fun gliIndiziContanoFinoATre() {
        assertEquals(0f, Indizi.di("oggi giornata lunga e piena di cose"), 0f)
        assertEquals(1f / 3, Indizi.di("devo finire il lavoro"), 1e-6f)
        // devo, entro, giovedì, Luca: quattro, ma il massimo è tre.
        assertEquals(1f, Indizi.di("devo mandare il preventivo a Luca entro giovedì"), 0f)
        // «dentro» non è «entro»; a inizio frase una maiuscola non è un nome.
        assertEquals(0f, Indizi.di("Metti tutto dentro la scatola"), 0f)
    }

    @Test
    fun quanteSceglierne() {
        assertEquals(1, Estratto.quante(1))
        assertEquals(1, Estratto.quante(2))
        assertEquals(3, Estratto.quante(6))
        assertEquals(4, Estratto.quante(40))
    }

    @Test
    fun mmrNonRipeteLaStessaCosa() {
        val a = floatArrayOf(1f, 0f)
        val quasiA = Vec.normalized(floatArrayOf(0.99f, 0.1f))
        val b = floatArrayOf(0f, 1f)
        // Le due più pesanti si somigliano: la seconda scelta è quella diversa, e tornano nell'ordine del testo.
        assertEquals(listOf(0, 1), Mmr.scegli(listOf(b, a, quasiA), floatArrayOf(0.7f, 1f, 0.95f), 2, 0.7f))
    }

    @Test
    fun ilRiassuntoTornaNelTestoOriginale() {
        val t = "Allora, cioè, oggi sono uscito presto per andare al lavoro. Comunque devo mandare il preventivo a Luca entro giovedì. " +
            "Poi a pranzo ho mangiato il solito panino al bar."
        // Un senso finto: ogni frase la sua direzione. Pesano gli indizi.
        val scelte = Estratto.di(t) { frasi -> frasi.mapIndexed { i, _ -> FloatArray(3).also { v -> v[i % 3] = 1f } } }
        // Tre candidate → due scelte: quella con gli indizi, poi a pari peso la prima nel testo.
        assertEquals(2, scelte.size)
        val s = scelte[1]
        assertEquals("Devo mandare il preventivo a Luca entro giovedì.", s.testo)
        assertEquals("devo mandare il preventivo a Luca entro giovedì", s.span.of(t))
    }
}
