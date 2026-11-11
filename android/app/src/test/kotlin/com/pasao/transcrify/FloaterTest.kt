package com.pasao.transcrify

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Il Floater: la carta esce con lo stesso scatto della pillola, e la notifica ha «Richiama» a destra. */
class FloaterTest {
    private val pillUi = File("src/main/kotlin/com/pasao/transcrify/PillUi.kt").readText()

    @Test
    fun loScattoEUnaMollaSolaCheSuperaAppena() {
        assertEquals(spring<Float>(0.68f, 400f), Scatto.molla<Float>())
        assertTrue("deve rimbalzare un poco", Durate.SCATTO_SMORZAMENTO < 1f)
    }

    @Test
    fun laPillolaELaCartaUsanoLoStessoScatto() {
        // La pillola che diventa pannello, e il pannello che cresce scoprendo la carta: la stessa molla.
        assertTrue(pillUi.contains("t.animateTo(1f, Scatto.molla())"))
        // Nessuna molla copiata a mano al posto dello scatto, e la carta non cresce più da sola (due molle in fila).
        assertFalse(pillUi.contains("dampingRatio = 0.68f"))
        assertFalse(pillUi.contains("expandVertically"))
    }

    /** Il pezzo di PillUi che disegna il pannello aperto: da MenuStage a dove finisce il registratore. */
    private val pannello = pillUi.substring(pillUi.indexOf("private fun MenuStage"), pillUi.indexOf("private fun MainButton"))
    private val caretFuso = File("src/main/kotlin/com/pasao/transcrify/CaretFuso.kt").readText()

    @Test
    fun aprireEChiudereLaCartaEUnoScattoSolo() {
        // «Si anima a pezzi»: lo scatto della carta è uno, del pannello, e CarteFuse lo riceve. Nessuna molla sua,
        // nessun'altra animazione nella carta; mentre la carta o la voce lo fanno crescere, il pannello le segue passo passo.
        assertEquals(1, Regex("""val carta = remember \{ Animatable""").findAll(pannello).count())
        assertFalse(caretFuso.contains("remember { Animatable"))
        assertFalse(Regex("""animate\w*AsState|AnimatedVisibility|animateContentSize""").containsMatchIn(caretFuso))
        // Anche aprendo (lo scatto [t]) e cambiando cassetto: l'altezza segue passo passo, non rincorre la larghezza.
        assertTrue(pannello.contains("if (alto.value == 0f || t.isRunning || carta.isRunning || cambio.isRunning || voce.isRunning || libero.isRunning) alto.snapTo(voluto) else alto.animateTo(voluto, Scatto.molla())"))
        assertFalse(pannello.contains("morfa"))
    }

    @Test
    fun ilPannelloMorfaLarghezzaEAltezzaInsieme() {
        // 10 nov, suo: «la chiusura va a fasi, prima in verticale e poi in orizzontale; prima (95c2384) morfava bene».
        // Una forma sola nel rettangolo tra la pillola e il pannello, dallo stesso scatto [t]: larghezza e altezza
        // insieme. Chiudendo il contenuto non si rimisura (la forma di partenza resta quella), e nessuna misura a mano.
        assertEquals(1, Regex("""Blob\(\s*rect = lerpRect\(bar, menu\(alto\.value\.coerceAtLeast\(1f\)\), p\)""").findAll(pannello).count())
        assertTrue(pannello.contains(".onSizeChanged { if (!closing) contenuto = it.height.toFloat() }"))
        assertFalse(Regex("""Constraints\.fixedWidth|sito\[""").containsMatchIn(pannello))
    }

    @Test
    fun registrareAllargaTuttoNelloStessoFotogramma() {
        // «Il registratore si apre e poi il floater si allarga in ritardo»: larghezza, tasti di lato, stato e pulizia
        // dallo stesso scatto della voce, nessuna molla dei pezzi.
        assertEquals(1, Regex("""val voce = remember \{ Animatable""").findAll(pannello).count())
        assertFalse(Regex("""animate\w*AsState|AnimatedVisibility|animateContentSize""").containsMatchIn(pannello.substringBefore("private fun ModeSlider")))
        assertTrue(pannello.contains("Coreografia.larghezza(carta.value, voce.value"))
    }

    @Test
    fun laCoreografiaDaUnValoreSolo() {
        // Stretto a riposo, largo con la carta o con la voce, mai oltre (la molla passa l'1 di poco).
        assertEquals(168f, Coreografia.larghezza(0f, 0f, 168f, 284f), 0f)
        assertEquals(284f, Coreografia.larghezza(1f, 0f, 168f, 284f), 0f)
        assertEquals(284f, Coreografia.larghezza(0.3f, 1.08f, 168f, 284f), 0f)
        assertEquals(226f, Coreografia.larghezza(0.5f, 0.2f, 168f, 284f), 0.01f)
        // Il contenuto della carta compare dopo il 60% dello scatto.
        assertEquals(0f, Coreografia.contenuto(0.6f), 0f)
        assertEquals(1f, Coreografia.contenuto(1.05f), 0f)
        // Mentre registri lo stato segue la voce; finita, se ne va con lei (non di colpo); un avviso c'è tutto.
        assertEquals(0.4f, Coreografia.conVoce(true, 0.4f, false), 0f)
        assertEquals(1f, Coreografia.conVoce(false, 0f, true), 0f)
        assertEquals(0.3f, Coreografia.conVoce(false, 0.3f, false), 0f)
        assertEquals(0f, Coreografia.conVoce(false, 0f, false), 0f)
    }

    @Test
    fun chiudereEUnMorphCheSiVede() {
        // 10 nov, suo: «quando lo chiudo torna subito al punto, senza morph». Si richiude con lo stesso scatto [t]
        // dell'apertura (forma, posto, colore, contenuto), all'indietro, in un tempo che si vede; nessun salto.
        val chiudi = pannello.substring(pannello.indexOf("fun collapse()"), pannello.indexOf("svc.stageDone()"))
        assertTrue(chiudi.contains("t.animateTo(0f, Scatto.richiude())"))
        assertFalse(Regex("""snapTo|removeStage""").containsMatchIn(chiudi))
        assertEquals(1, Regex("""val t = remember \{ Animatable""").findAll(pannello).count())
        assertEquals(tween<Float>(Durate.NORMALE, easing = FastOutSlowInEasing), Scatto.richiude<Float>())
        assertTrue(Durate.NORMALE > Durate.VELOCE)
    }

    @Test
    fun cambiareCassettoTieneLaCartaApertaEMorfaConUnoScattoSolo() {
        // 10 nov, suo: «aprendo un altro caret chiude tutto e poi riapre, troppo movimentato».
        assertEquals(Passo.CAMBIA, Coreografia.passo(Carta.ULTIMA, Carta.VOCALI))
        assertEquals(Passo.APRE, Coreografia.passo(null, Carta.ULTIMA))
        assertEquals(Passo.CHIUDE, Coreografia.passo(Carta.VOCALI, null))
        assertEquals(Passo.RESTA, Coreografia.passo(Carta.PAUSA, Carta.PAUSA))
        // Il cambio: la carta non si chiude (nessun t a 0 lì), un solo scatto [cambio] con la molla, tenuto dal pannello.
        val cambia = caretFuso.substring(caretFuso.indexOf("Passo.CAMBIA ->"), caretFuso.indexOf("Passo.RESTA ->"))
        assertFalse(cambia.contains("animateTo(0f"))
        assertEquals(1, Regex("""\.animateTo\(""").findAll(cambia.replace("t.animateTo(1f, Scatto.molla())", "")).count())
        assertTrue(cambia.contains("cambio.animateTo(1f, Scatto.molla())"))
        assertEquals(1, Regex("""val cambio = remember \{ Animatable""").findAll(pannello).count())
        // Altezza, ponte (la x del cassetto) e colori dallo stesso valore; il contenuto passa da uno all'altro.
        assertTrue(caretFuso.contains("lerp(xDi(lascia ?: mostrata), xDi(mostrata), c)"))
        assertEquals(150f, Coreografia.tra(100f, 200f, 0.5f), 0f)
        assertEquals(200f, Coreografia.tra(100f, 200f, 1.06f), 0f)
        assertEquals(1f, Coreografia.esce(0f), 0f)
        assertEquals(0f, Coreografia.esce(0.5f), 0f)
        assertEquals(0f, Coreografia.entra(0.5f), 0f)
        assertEquals(1f, Coreografia.entra(1f), 0f)
    }

    @Test
    fun ilContornoDellaRispostaSegueTuttaLaForma() {
        // «Stai rispondendo»: il bordo segue carta, ponte e cassetto (lo stesso Path), non il rettangolo della carta.
        assertTrue(caretFuso.contains("formaFusa(forma(), conCassetto = true)"))
        assertTrue(caretFuso.contains("style = Stroke(BORDO_RISPOSTA.toPx())"))
        assertFalse(caretFuso.contains(".border("))
        val f = PonteFuso.misure(1f, 300f, 122f, 56f, 28f, 200f, 12f, 24f)
        assertEquals(f.caretSu + 28f, f.caretGiu, 0.01f)
    }

    @Test
    fun laTestataDeiVocaliContaEChiudeTutto() {
        assertEquals("Vocali di WhatsApp (2)", Provenienza.testata(2, "WhatsApp", "Vocale di WhatsApp"))
        assertEquals("Vocale di WhatsApp", Provenienza.testata(1, "WhatsApp", "Vocale di WhatsApp"))
        assertEquals("Vocali (3)", Provenienza.testata(3, null, "Audio"))
        val carta = File("src/main/kotlin/com/pasao/transcrify/FloaterCarta.kt").readText()
        // La X della testata toglie tutti; ognuno nella lista ha ancora la sua.
        assertTrue(carta.contains("Testata(vocali, risponde) { svc.togliVocali() }"))
        assertTrue(carta.contains("Chiudi(\"Togli questo vocale\", Palette.SuCartaTenue) { svc.togliVocale(t) }"))
        val servizio = File("src/main/kotlin/com/pasao/transcrify/PillService.kt").readText()
        val togli = servizio.substring(servizio.indexOf("fun togliVocali()"), servizio.indexOf("fun vocaliInNote()"))
        assertTrue(togli.contains("messages.clear()") && togli.contains("vocale = null") && togli.contains("if (carta == Carta.VOCALI) carta = null"))
    }

    @Test
    fun laNotificaHaRichiamaInFondo() {
        assertEquals(AvvisoFuori.Tasto.RICHIAMA, AvvisoFuori.tasti.last())
        assertEquals("Richiama", AvvisoFuori.Tasto.RICHIAMA.etichetta)
        assertFalse(AvvisoFuori.TESTO.contains("Chiudi"))
        assertTrue(AvvisoFuori.TESTO.contains("Richiama"))
    }
}
