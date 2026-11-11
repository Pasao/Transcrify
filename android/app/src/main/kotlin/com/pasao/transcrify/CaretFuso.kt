package com.pasao.transcrify

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.AnimationVector1D
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathOperation
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp
import kotlinx.coroutines.launch

/*
 * Il cassetto e la sua carta, uniti da un ponte (6 nov: «voglio vedere il caret fondersi con il contenuto che apre»;
 * 7 nov: «si fa assorbire dalla carta, e non vedi più l'altro caret separato: immagina un PONTE tra il caret e la
 * carta»). Il cassetto resta una pillola nella sua fila, allo stesso posto e della stessa grandezza, con gli altri
 * accanto; la carta cresce SOPRA la fila, e un collo del suo colore, raccordato in curva da tutte e due le parti, va
 * dalla cima del cassetto al fondo della carta. Il cassetto aperto prende il colore della carta: cassetto, ponte e
 * carta sono una forma sola, gli altri restano scuri e separati. Tutto con lo scatto del Floater ([Scatto.molla]
 * aprendo, [Scatto.svelto] chiudendo). Il contenuto compare dopo il 60% e chiudendo se ne va per primo.
 * 10 nov: da un cassetto all'altro la carta non si chiude più, morfa con lo scatto [cambio] (vedi [CarteFuse]).
 * 7 nov sera, «si anima a pezzi»: lo scatto [carta] non è più suo, è del pannello (Coreografia), che ne prende anche la
 * larghezza; la sua altezza è quella di questa fila, misurata nello stesso passaggio. Il contenuto della carta si misura
 * sempre largo quanto la carta aperta ([larghezzaCarta]): non va a capo diversamente mentre il pannello si allarga.
 * 7 nov: «meno a scatti, più dinamico; parte dai BORDI del caret e curva quando si unisce, ma più LARGO»: carta e
 * ponte sono un Path solo ([PonteFuso]), disegnato a ogni fotogramma dallo stesso valore [t] che muove anche il colore
 * e la freccia del cassetto. Nessun'altra animazione.
 */

/**
 * La fila dei cassetti sopra il registratore e la carta di quello aperto, col ponte. [quali] dice quali cassetti ci
 * sono ([Cassettiera.quali]); uno solo aperto alla volta. Aprendone un altro (10 nov, suo: «chiude tutto e riapre, troppo
 * movimentato») la carta resta aperta e MORFA: dallo scatto [cambio] (uno, con [Scatto.molla]) la sua altezza va da
 * quella di A a quella di B, il ponte scivola dal cassetto A al cassetto B, i colori dei due cassetti si scambiano e il
 * contenuto passa dall'uno all'altro ([Coreografia.esce], [Coreografia.entra]).
 */
@Composable
internal fun CarteFuse(
    svc: PillService, quali: List<Carta>, t: Animatable<Float, AnimationVector1D>, cambio: Animatable<Float, AnimationVector1D>,
    maxCarta: Dp, larghezzaCarta: Dp,
) {
    val aperta = Cassettiera.aperta(svc.carta, quali)
    // Quella che si vede: resta durante la chiusura, finché la carta non è sparita. [prima]: quella che lascia, nel cambio.
    var mostrata by remember { mutableStateOf(aperta) }
    var prima by remember { mutableStateOf<Carta?>(null) }
    LaunchedEffect(aperta) {
        when (Coreografia.passo(mostrata, aperta)) {
            Passo.CHIUDE -> {
                t.animateTo(0f, Scatto.svelto())
                mostrata = null
            }
            Passo.APRE -> {
                mostrata = aperta
                cambio.snapTo(1f)
                t.animateTo(1f, Scatto.molla())
            }
            Passo.CAMBIA -> {
                prima = mostrata
                mostrata = aperta
                cambio.snapTo(0f)
                // Se stava ancora chiudendosi torna aperta, con la stessa molla, mentre cambia.
                launch { t.animateTo(1f, Scatto.molla()) }
                cambio.animateTo(1f, Scatto.molla())
                prima = null
            }
            Passo.RESTA -> if (aperta != null) t.animateTo(1f, Scatto.molla())
        }
    }
    if (quali.isEmpty()) return
    val p = t.value.coerceAtLeast(0f)
    val pieno = p.coerceIn(0f, 1f)
    val c = Coreografia.pieno(cambio.value)
    // L'altezza misurata di ogni carta: nel cambio si passa dall'una all'altra.
    val alte = remember { mutableStateMapOf<Carta, Int>() }
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val largo = maxWidth
        val n = quali.size
        val riga = CARET_W * n + CARET_SPAZIO * (n - 1)
        fun xDi(quale: Carta?) = (largo - riga) / 2 + (CARET_W + CARET_SPAZIO) * quali.indexOf(quale).coerceAtLeast(0)
        val lascia = prima?.takeIf { it in quali && it != mostrata }
        val caretX = lerp(xDi(lascia ?: mostrata), xDi(mostrata), c)
        val hB = (alte[mostrata] ?: 0).toFloat()
        val cartaPx = Coreografia.tra(lascia?.let { alte[it] }?.toFloat() ?: hB, hB, c)
        val carta = with(density) { cartaPx.toDp() } * p
        val ponte = PONTE_H * p
        // Quanto è aperto ogni cassetto: quello che arriva prende il colore della carta, quello che lascia torna scuro.
        fun peso(quale: Carta) = pieno * when (quale) {
            mostrata -> if (lascia == null) 1f else c
            lascia -> 1f - c
            else -> 0f
        }
        // Rispondi a un vocale mentre registri: la forma intera si accende del colore dell'azione.
        val risponde = if (svc.session.phase == Phase.RECORDING) peso(Carta.VOCALI) else 0f
        // Carta, ponte e cassetto: le misure di adesso, dallo stesso valore (le misure in dp, la carta misurata).
        fun DrawScope.forma() = PonteFuso.misure(
            t.value, size.width, caretX.toPx(), CARET_W.toPx(), CARET_H.toPx(), cartaPx, PONTE_H.toPx(), Forme.raggioScheda.toPx(),
        )
        Box(Modifier.fillMaxWidth().height(CARET_H + ponte + carta)) {
            val quale = mostrata
            if (quale != null) {
                Canvas(Modifier.matchParentSize()) { drawPath(formaFusa(forma()), Palette.Carta) }
                // La carta cresce dalla cima del cassetto: si allarga da lui a tutta la riga.
                val x = lerp(caretX, 0.dp, pieno)
                Box(
                    Modifier
                        .align(Alignment.TopStart)
                        .offset(x = x)
                        .size(lerp(CARET_W, largo, pieno), carta)
                        .clip(RoundedCornerShape(lerp(CARET_H / 2, Forme.raggioScheda, pieno))),
                ) {
                    Box(
                        Modifier
                            .offset(x = -x)
                            .wrapContentWidth(Alignment.Start, unbounded = true)
                            .width(larghezzaCarta)
                            .wrapContentHeight(Alignment.Top, unbounded = true)
                            .alpha(Coreografia.contenuto(p)),
                    ) {
                        if (lascia != null) Contenuto(svc, lascia, maxCarta, Coreografia.esce(c)) { alte[lascia] = it }
                        Contenuto(svc, quale, maxCarta, if (lascia != null) Coreografia.entra(c) else 1f) { alte[quale] = it }
                    }
                }
            }
            Row(Modifier.align(Alignment.BottomCenter), horizontalArrangement = Arrangement.spacedBy(CARET_SPAZIO)) {
                quali.forEach { q -> Caret(svc, q, peso(q)) }
            }
            // Il contorno della risposta segue tutta la forma (carta, ponte e cassetto): lo stesso Path, sopra i cassetti.
            if (quale != null && risponde > 0f) {
                Canvas(Modifier.matchParentSize()) {
                    drawPath(formaFusa(forma(), conCassetto = true), Palette.Blue.copy(alpha = risponde), style = Stroke(BORDO_RISPOSTA.toPx()))
                }
            }
        }
    }
}

/** Il contenuto di una carta, misurato (per l'altezza della forma) e trasparente quanto [quanto]. */
@Composable
private fun Contenuto(svc: PillService, quale: Carta, maxCarta: Dp, quanto: Float, misurata: (Int) -> Unit) {
    Box(Modifier.onSizeChanged { misurata(it.height) }.alpha(quanto)) { CartaFuori(svc, quale, maxCarta) }
}

/**
 * Il Path della forma fusa: la carta, e il ponte che parte dal cassetto (dai suoi bordi, da aperto) e si apre in due
 * curve concave nel fondo della carta. Sotto, il ponte abbraccia la metà alta del cassetto: da chiuso segue la sua
 * pillola (e il cassetto, disegnato sopra, lo copre), da aperto le spalle si fanno dritte e il cassetto ci si fonde.
 */
internal fun formaFusa(f: FormaFusa, conCassetto: Boolean = false): Path {
    val carta = Path().apply { addRoundRect(RoundRect(f.cartaL, 0f, f.cartaR, f.cartaGiu, CornerRadius(f.raggio))) }
    // Il contorno abbraccia anche il cassetto intero: la forma è una sola, carta + ponte + cassetto.
    val forma = if (!conCassetto) carta else Path.combine(
        PathOperation.Union, carta,
        Path().apply { addRoundRect(RoundRect(f.caretL, f.caretSu, f.caretR, f.caretGiu, CornerRadius(f.caretMeta - f.caretSu))) },
    )
    val g = f.varco
    if (g <= 0f) return forma
    // Il ponte entra un poco nella carta: l'unione non lascia fessure.
    val dentro = f.cartaGiu - minOf(f.cartaGiu, g)
    val ponte = Path().apply {
        moveTo(f.caretL, f.caretMeta)
        lineTo(f.caretL, f.caretSu + f.spalla)
        quadraticTo(f.caretL, f.caretSu, f.baseL, f.caretSu)
        cubicTo(f.baseL, f.caretSu - g * CURVA, f.baseL - f.svasoL * (1f - CURVA), f.cartaGiu, f.baseL - f.svasoL, f.cartaGiu)
        lineTo(f.baseL - f.svasoL, dentro)
        lineTo(f.baseR + f.svasoR, dentro)
        lineTo(f.baseR + f.svasoR, f.cartaGiu)
        cubicTo(f.baseR + f.svasoR * (1f - CURVA), f.cartaGiu, f.baseR, f.caretSu - g * CURVA, f.baseR, f.caretSu)
        quadraticTo(f.caretR, f.caretSu, f.caretR, f.caretSu + f.spalla)
        lineTo(f.caretR, f.caretMeta)
        close()
    }
    return Path.combine(PathOperation.Union, forma, ponte)
}

/** Le maniglie delle curve del ponte (come un quarto di cerchio): verticali sul cassetto, orizzontali sulla carta. */
private const val CURVA = 0.55f

/**
 * Un cassetto: una pillola col suo segno, sempre al suo posto. [aperto] da 0 a 1: quanto la sua carta è aperta; il
 * suo fondo passa dal velo scuro al colore della carta, e il segno con lui.
 */
@Composable
private fun Caret(svc: PillService, quale: Carta, aperto: Float) {
    val tinta = lerp(Palette.Text, Palette.SuCarta, aperto)
    Box(
        Modifier
            .size(CARET_W, CARET_H)
            .clip(Forme.pillola)
            .background(lerp(fondoCaret, Palette.Carta, aperto))
            .clickable(onClickLabel = (if (svc.carta == quale) "Chiudi " else "Apri ") + nome(svc, quale)) { svc.carta = Cassettiera.tocca(svc.carta, quale) },
        contentAlignment = Alignment.Center,
    ) {
        when (quale) {
            Carta.ULTIMA -> Freccia(aperto, tinta)
            Carta.VOCALI -> IconaProvenienza(svc.vocali.firstOrNull()?.second?.source)
            Carta.PAUSA -> Icon(Icons.Rounded.Pause, null, tint = tinta, modifier = Modifier.size(16.dp))
        }
    }
}

/** Il fondo di un cassetto chiuso: un velo del testo sul pannello. */
private val fondoCaret: Color get() = Palette.Text.copy(alpha = 0.12f)

private fun nome(svc: PillService, quale: Carta) = when (quale) {
    Carta.ULTIMA -> "l'ultima trascrizione"
    Carta.VOCALI -> if (svc.vocali.size > 1) "i vocali" else "il vocale"
    Carta.PAUSA -> "dove eri arrivato"
}

/** La freccia gira con la carta, dallo stesso valore: aperta punta in giù. */
@Composable
private fun Freccia(aperto: Float, tinta: Color) {
    Icon(Icons.Rounded.ExpandLess, null, tint = tinta, modifier = Modifier.size(18.dp).rotate(180f * aperto))
}

private val CARET_W = 56.dp
private val CARET_H = 28.dp
private val CARET_SPAZIO = 8.dp

/** Il contorno di «Stai rispondendo»: lo spessore del tratto sulla forma intera. */
private val BORDO_RISPOSTA = 2.dp

/** Il ponte: quanto è alto da aperto (le sue curve si allargano di [PonteFuso.SVASO] volte tanto). */
private val PONTE_H = 12.dp
