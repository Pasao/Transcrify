package com.pasao.transcrify

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.lerp

/*
 * Il cassetto che diventa la sua carta (6 nov, sua richiesta: «voglio vedere il caret fondersi con il contenuto
 * che apre»). Una forma sola: tocchi il cassetto e la sua pillola si allarga e sale fino a essere la carta (stesso
 * fondo, contorno continuo), con lo scatto del Floater ([Scatto.molla]); richiudendo la carta torna pillola
 * ([Scatto.svelto]). Il contenuto compare dopo il 60% della trasformazione, e chiudendo se ne va per primo.
 */

/** Da quanto della trasformazione si vede il contenuto della carta. */
private const val CONTENUTO_DA = 0.6f

/**
 * La fila dei cassetti sopra il registratore e la carta di quello aperto, fusa con lui. [quali] dice quali
 * cassetti ci sono ([Cassettiera.quali]); uno solo aperto alla volta: aprendone un altro, quello aperto torna
 * pillola e poi si apre il nuovo.
 */
@Composable
internal fun CarteFuse(svc: PillService, quali: List<Carta>, maxCarta: Dp) {
    if (quali.isEmpty()) return
    val aperta = Cassettiera.aperta(svc.carta, quali)
    val t = remember { Animatable(0f) }
    // Quella che si vede: resta durante la chiusura, finché non è tornata pillola.
    var mostrata by remember { mutableStateOf(aperta) }
    LaunchedEffect(aperta) {
        svc.morfa = true
        if (mostrata != null && mostrata != aperta) t.animateTo(0f, Scatto.svelto())
        mostrata = aperta
        if (aperta != null) t.animateTo(1f, Scatto.molla())
        svc.morfa = false
    }
    val p = t.value
    val pieno = p.coerceIn(0f, 1f)
    var cartaH by remember { mutableIntStateOf(0) }
    val density = LocalDensity.current
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val largo = maxWidth
        val n = quali.size
        val riga = CARET_W * n + CARET_SPAZIO * (n - 1)
        val i = quali.indexOf(mostrata).coerceAtLeast(0)
        val caretX = (largo - riga) / 2 + (CARET_W + CARET_SPAZIO) * i
        val tutta = with(density) { cartaH.toDp() } + CARET_SPAZIO + CARET_H
        val alta = lerp(CARET_H, tutta, p).coerceAtLeast(CARET_H)
        Box(Modifier.fillMaxWidth().height(alta)) {
            val quale = mostrata
            if (quale != null) {
                val x = lerp(caretX, 0.dp, p)
                val forma = RoundedCornerShape(lerp(CARET_H / 2, Forme.raggioScheda, pieno))
                // Rispondi a un vocale mentre registri: la carta si accende del colore dell'azione.
                val risponde = quale == Carta.VOCALI && svc.session.phase == Phase.RECORDING
                Box(
                    Modifier
                        .align(Alignment.BottomStart)
                        .offset(x = x)
                        .size(lerp(CARET_W, largo, p), alta)
                        .clip(forma)
                        .background(lerp(fondoCaret(0f), Palette.Carta, pieno))
                        .then(if (risponde) Modifier.border(2.dp, Palette.Blue.copy(alpha = pieno), forma) else Modifier),
                ) {
                    Box(
                        Modifier
                            .offset(x = -x)
                            .wrapContentWidth(Alignment.Start, unbounded = true)
                            .width(largo)
                            .wrapContentHeight(Alignment.Top, unbounded = true)
                            .onSizeChanged { cartaH = it.height }
                            .alpha(((p - CONTENUTO_DA) / (1f - CONTENUTO_DA)).coerceIn(0f, 1f)),
                    ) { CartaFuori(svc, quale, maxCarta) }
                }
            }
            Row(Modifier.align(Alignment.BottomCenter), horizontalArrangement = Arrangement.spacedBy(CARET_SPAZIO)) {
                quali.forEach { c -> Caret(svc, c, if (c == quale) pieno else 0f, sopraCarta = if (quale != null) pieno else 0f) }
            }
        }
    }
}

/**
 * Un cassetto: una pillola col suo segno. [fuso] da 0 a 1: quanto è già diventato la sua carta (il fondo lo dà
 * la carta, lui resta la maniglia in basso). [sopraCarta]: quanto la carta aperta gli sta dietro (segni scuri).
 */
@Composable
private fun Caret(svc: PillService, quale: Carta, fuso: Float, sopraCarta: Float) {
    val aperto = svc.carta == quale
    val tinta = lerp(Palette.Text, Palette.SuCarta, sopraCarta)
    // Il cassetto che si fonde non ha un fondo suo: è la forma che cresce.
    val fondo = if (quale == svc.carta || fuso > 0f) Color.Transparent else fondoCaret(sopraCarta)
    Box(
        Modifier
            .size(CARET_W, CARET_H)
            .clip(Forme.pillola)
            .background(fondo)
            .clickable(onClickLabel = (if (aperto) "Chiudi " else "Apri ") + nome(svc, quale)) { svc.carta = Cassettiera.tocca(svc.carta, quale) },
        contentAlignment = Alignment.Center,
    ) {
        when (quale) {
            Carta.ULTIMA -> Freccia(aperto, tinta)
            Carta.VOCALI -> IconaProvenienza(svc.vocali.firstOrNull()?.second?.source)
            Carta.PAUSA -> Icon(Icons.Rounded.Pause, null, tint = tinta, modifier = Modifier.size(16.dp))
        }
    }
}

/** Il fondo di un cassetto chiuso: un velo del testo sul pannello, o della carta quando le sta sopra. */
private fun fondoCaret(sopraCarta: Float) = lerp(Palette.Text, Palette.SuCarta, sopraCarta).copy(alpha = 0.12f)

private fun nome(svc: PillService, quale: Carta) = when (quale) {
    Carta.ULTIMA -> "l'ultima trascrizione"
    Carta.VOCALI -> if (svc.vocali.size > 1) "i vocali" else "il vocale"
    Carta.PAUSA -> "dove eri arrivato"
}

@Composable
private fun Freccia(aperto: Boolean, tinta: Color) {
    val giro by animateFloatAsState(if (aperto) 180f else 0f, Scatto.molla(), label = "freccia")
    Icon(Icons.Rounded.ExpandLess, null, tint = tinta, modifier = Modifier.size(18.dp).rotate(giro))
}

private val CARET_W = 56.dp
private val CARET_H = 28.dp
private val CARET_SPAZIO = 8.dp
