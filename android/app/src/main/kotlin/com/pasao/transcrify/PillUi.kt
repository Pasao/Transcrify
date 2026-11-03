package com.pasao.transcrify

import androidx.compose.foundation.layout.heightIn
import kotlin.math.cos
import kotlin.math.sin
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.Dp
import androidx.compose.foundation.Canvas
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.fadeOut
import androidx.compose.animation.fadeIn
import androidx.compose.animation.expandVertically
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material.icons.rounded.CloseFullscreen
import androidx.compose.material.icons.rounded.OpenInFull
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.ui.util.lerp
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.width
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.runtime.snapshotFlow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.verticalScroll
import kotlin.math.roundToInt

/** Misure della pillola, in dp. */
object PillGeometry {
    const val TOUCH_W = 40f
    const val TOUCH_W_RECORDING = 80f
    const val TOUCH_H = 160f
    const val BAR_W = 12f
    const val BAR_H = 88f
    const val BAR_INSET = 3f
    const val MENU_RADIUS = 28f
    /** Il pannello: largo quanto la carta (260) più i margini; alto almeno quanto il registratore. */
    const val PANNELLO_W = 284f
    const val PANNELLO_MIN = 100f
    /** Stretto: i cassetti e il microfono, finché non esce una carta o non parli. */
    const val PANNELLO_STRETTO = 168f
    /** Quanto il fondo del pannello scende sotto il centro della pillola: il registratore le resta accanto. */
    const val SOTTO_LA_PILLOLA = 60f
    const val MENU_MARGIN = 10f
    const val BUBBLE = 56f
    const val DISMISS = 72f
    const val DISMISS_BOTTOM = 120f
    const val DISMISS_MAGNET = 96f
}

/**
 * I colori della pillola: i ruoli della pillola presi dai token (Token.kt, la fonte unica). Nessun colore
 * scritto qui. Il Floater è sempre scuro, anche col telefono chiaro: usa i token del tema SCURO, fatti per
 * stare su un fondo scuro (il giallo dell'errore, il rosso dell'ascolto si leggono sul pannello).
 * Il servizio aggiorna [token] all'avvio e quando cambia il colore del telefono.
 */
object Palette {
    var token: Token = Token.dal(0xFFF1917F.toInt(), scuro = true)

    private fun c(argb: Int) = Color(argb)

    /**
     * Quanto si vedono i pezzi fuori dall'app (pannello, pillola, casa): lo sceglie lui nelle impostazioni
     * (Trasparenza), uno per uno, con l'anteprima sul suo sfondo. È uno stato: cambiandolo si ridisegna tutto.
     */
    var opacitaFloater by androidx.compose.runtime.mutableFloatStateOf(OPACITA_BASE)
    var opacitaPillola by androidx.compose.runtime.mutableFloatStateOf(OPACITA_BASE)
    var opacitaCasa by androidx.compose.runtime.mutableFloatStateOf(OPACITA_BASE)
    const val OPACITA_BASE = 0.95f
    const val OPACITA_MIN = 0.5f

    /** Il pannello: il fondo «floater», trasparente quanto hai scelto. */
    val Panel get() = c(token.floater).copy(alpha = opacitaFloater)

    /** Il testo e le icone sul pannello, pieni, leggeri, e il bordo sottile. */
    val Text get() = c(token.suFloater)
    val Muted get() = c(token.suFloater).copy(alpha = 0.6f)
    val Stroke get() = c(token.suFloater).copy(alpha = 0.25f)

    /** La carta che esce dalla fessura: chiara sul pannello scuro, col testo scuro. */
    val Carta get() = c(token.suFloater)
    val SuCarta get() = c(token.floater)
    val SuCartaTenue get() = c(token.floater).copy(alpha = 0.6f)
    val LineaCarta get() = c(token.floater).copy(alpha = 0.12f)
    /** La testata della carta dei vocali: un velo del colore dell'azione (piena quando rispondi). */
    val TestataCarta get() = c(token.azione).copy(alpha = 0.22f)

    /** Cosa va sopra i tasti chiari (registra, riprova). */
    val Ink get() = c(token.suAzione)

    /** L'azione e gli stati. */
    val Blue get() = c(token.azione)
    val Red get() = c(token.errore)
    val Yellow get() = c(token.attenzione)
    val Green get() = c(token.successo)
    val Paused get() = c(token.testoSecondario)

    /** Transcri: i suoi due toni. */
    val AccentA get() = c(token.transcriA)
    val AccentB get() = c(token.transcriB)

    /** A riposo sul bordo è spento: il fondo «floater», quasi trasparente. */
    val Smoke get() = c(token.floater)
    /** La pillola a riposo: la sua trasparenza. */
    val smokeAlpha get() = opacitaPillola
}

/** Il corpo di Transcri. */
internal fun transcriBrush() = Brush.verticalGradient(listOf(Palette.AccentA, Palette.AccentB))

/** A riposo (o senza minuti) Transcri è spento; mentre trascrive ha i suoi colori; negli altri stati il colore dello stato. */
private fun isRest(phase: Phase) = phase == Phase.IDLE || phase == Phase.LIMITED

private fun barColor(phase: Phase, paused: Boolean = false) = when (phase) {
    Phase.RECORDING -> if (paused) Palette.Paused else Palette.Red
    // Trascrive: nessun colore sopra, si vede il suo gradiente (con la luce che scorre).
    Phase.PROCESSING -> Palette.AccentA.copy(alpha = 0f)
    Phase.SUCCESS -> Palette.Green
    Phase.ERROR -> Palette.Yellow
    Phase.IDLE -> Palette.Smoke
    Phase.LIMITED -> Palette.Smoke
}

// --- La pillola sul bordo ---

@Composable
fun PillBar(svc: PillService) {
    val phase = svc.session.phase
    val rest = isRest(phase)
    // I cambi di stato si sfumano con calma (dal suo colore al verde, per esempio): mai uno scatto.
    val color by animateColorAsState(barColor(phase, svc.session.paused), tween(650, easing = FastOutSlowInEasing), label = "bar")
    val listening = phase == Phase.RECORDING && !svc.session.paused
    val voice by animateFloatAsState(if (listening) svc.session.level else 0f, tween(90), label = "voice")
    // Spento a riposo; toccandolo si sveglia (prende i suoi colori), negli altri stati è sempre acceso.
    // A riposo sbircia: mezzo fuori dallo schermo. Appena atterrato resta tutto fuori un attimo, poi si ritira.
    val target = if (!rest || svc.holding || svc.carried) 1f else 0f
    val awakeAnim = remember { Animatable(1f) }
    var seenSettle by remember { mutableStateOf(svc.settle) }
    LaunchedEffect(target, svc.settle) {
        if (svc.settle != seenSettle) {
            seenSettle = svc.settle
            awakeAnim.snapTo(1f)
        }
        if (target == 0f) {
            kotlinx.coroutines.delay(700)
            awakeAnim.animateTo(0f, tween(480, easing = FastOutSlowInEasing))
        } else {
            awakeAnim.animateTo(1f, spring(dampingRatio = 0.6f, stiffness = 900f))
        }
    }
    val awake = awakeAnim.value
    val density = LocalDensity.current
    val peek = with(density) { ((1f - awake) * (PillGeometry.BAR_W * 0.5f + PillGeometry.BAR_INSET)).dp.toPx() }
    svc.peekShift = if (svc.pillRight) peek else -peek
    // Tenendo premuto: si gonfia finché scatta (da fermo comincia ad ascoltarti, mentre ascolta trascrive).
    // Il colore non cambia finché non scatta davvero: prima è solo lui che prende la rincorsa.
    val hold by animateFloatAsState(
        if (svc.holding) 1f else 0f,
        if (svc.holding) tween((PillService.HOLD_MS - 60).toInt(), easing = LinearEasing) else spring(dampingRatio = 0.4f, stiffness = 700f),
        label = "hold",
    )
    // Trascrive: il suo gradiente scorre, lento e continuo. È lui che lavora, coi suoi colori.
    val flow = rememberInfiniteTransition(label = "flow")
    val shift by flow.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1600, easing = LinearEasing), RepeatMode.Restart), label = "shift",
    )
    // Qualcosa non va: scuote la testa due volte.
    val shake = remember { Animatable(0f) }
    LaunchedEffect(phase) {
        if (phase == Phase.ERROR) {
            shake.snapTo(0f)
            shake.animateTo(1f, tween(520, easing = LinearEasing))
        }
    }
    val wobble = if (shake.value in 0.001f..0.999f) kotlin.math.sin(shake.value * Math.PI.toFloat() * 4f) * (1f - shake.value) * 5f else 0f
    // Fatto: un piccolo salto.
    val hop = remember { Animatable(0f) }
    LaunchedEffect(phase) {
        if (phase == Phase.SUCCESS) {
            hop.snapTo(0f)
            hop.animateTo(1f, tween(420, easing = FastOutSlowInEasing))
        }
    }
    val jump = kotlin.math.sin(hop.value * Math.PI.toFloat()) * 8f
    // Mentre trascrive dal fianco verso il centro escono onde; il lato sul bordo resta fermo.
    val working by animateFloatAsState(if (phase == Phase.PROCESSING) 1f else 0f, tween(300), label = "working")
    val shape = if (working > 0f) OutwardWave(svc.pillRight, shift, working) else CircleShape
    Box(
        Modifier
            .fillMaxSize()
            .padding(horizontal = PillGeometry.BAR_INSET.dp)
            .semantics { contentDescription = "Transcrify: tocca per aprire, trascina per spostare" },
        contentAlignment = if (svc.pillRight) Alignment.CenterEnd else Alignment.CenterStart,
    ) {
        Box(
            Modifier
                .size(PillGeometry.BAR_W.dp, PillGeometry.BAR_H.dp)
                .graphicsLayer {
                    translationX = wobble.dp.toPx() + svc.peekShift
                    translationY = -jump.dp.toPx()
                    // Mentre ascolta si ingrossa con la voce: la forma resta, cambia quanto è grande.
                    // Cresce solo verso il centro dello schermo: il lato sul bordo resta dov'è.
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin(if (svc.pillRight) 1f else 0f, 0.5f)
                    scaleX = 1f + voice * 0.45f + hold.coerceAtLeast(0f) * 0.9f + awake * 0.08f + working * WORK_GROW
                    scaleY = 1f + voice * 0.08f + hold.coerceAtLeast(0f) * 0.14f
                    alpha = if (phase == Phase.LIMITED) 0.5f else lerp(Palette.smokeAlpha, 1f, awake)
                }
                .shadow((3 * awake).dp, shape, clip = false) // ds:eccezione: il movimento di Transcri (l'ombra cresce mentre si apre)
                .clip(shape)
                // Spento è fumo; sveglio ha i suoi colori; sopra, il colore dello stato.
                .background(Palette.Smoke)
                .background(transcriBrush(), alpha = awake)
                .background(if (rest) Color.Transparent else color)
                .drawWithContent {
                    drawContent()
                    if (phase == Phase.PROCESSING) {
                        // I due toni che si inseguono dall'alto in basso, ripetuti: nessun bagliore, solo il suo colore che scorre.
                        val h = size.height
                        drawRect(
                            Brush.verticalGradient(
                                listOf(Palette.AccentA, Palette.AccentB, Palette.AccentA),
                                startY = -h + h * shift, endY = h * shift,
                                tileMode = androidx.compose.ui.graphics.TileMode.Repeated,
                            )
                        )
                    }
                }
                .border(1.dp, Palette.Stroke, shape)
        )
    }
}

/**
 * La pillola mentre trascrive: resta una pillola della sua larghezza normale, attaccata al bordo,
 * e dal fianco verso il centro dello schermo escono onde che scorrono dall'alto in basso.
 * Le onde vanno solo verso fuori, mai dentro: nessuna ammaccatura. Agli estremi si spengono,
 * così le punte restano tonde e il fianco si unisce alle punte senza scalini.
 *
 * Il riquadro è già allargato di [WORK_GROW] (vedi scaleX): la parte in più, dal lato del centro,
 * è lo spazio dove l'onda può uscire.
 */
private class OutwardWave(val right: Boolean, val phase: Float, val amount: Float) : androidx.compose.ui.graphics.Shape {
    override fun createOutline(
        size: androidx.compose.ui.geometry.Size,
        layoutDirection: androidx.compose.ui.unit.LayoutDirection,
        density: androidx.compose.ui.unit.Density,
    ): androidx.compose.ui.graphics.Outline {
        val w = size.width
        val h = size.height
        // Quanto del riquadro è "in più": una volta allargato, la pillola di base torna larga com'era.
        val extra = w * (1f - 1f / (1f + WORK_GROW * amount))
        val r = (w - extra) / 2
        // Di quanto esce l'onda all'altezza y: da 0 (il fianco della pillola) a tutta la parte in più.
        fun bulge(y: Float): Float {
            val t = ((y - r) / (h - 2 * r)).coerceIn(0f, 1f)
            val taper = kotlin.math.sin(t * Math.PI.toFloat())
            return extra * taper * (0.5f + 0.5f * kotlin.math.sin((t * 1.5f - phase) * 2f * Math.PI.toFloat()))
        }
        val path = androidx.compose.ui.graphics.Path()
        val steps = 32
        if (right) {
            // Bordo a destra: la pillola sta in [extra, w], l'onda esce verso sinistra.
            path.moveTo(extra, r)
            path.arcTo(Rect(extra, 0f, w, 2 * r), 180f, 180f, false)
            path.lineTo(w, h - r)
            path.arcTo(Rect(extra, h - 2 * r, w, h), 0f, 180f, false)
            for (i in steps downTo 0) {
                val y = r + (h - 2 * r) * i / steps
                path.lineTo(extra - bulge(y), y)
            }
        } else {
            // Bordo a sinistra: la pillola sta in [0, w - extra], l'onda esce verso destra.
            val inner = w - extra
            path.moveTo(0f, r)
            path.arcTo(Rect(0f, 0f, inner, 2 * r), 180f, 180f, false)
            for (i in 0..steps) {
                val y = r + (h - 2 * r) * i / steps
                path.lineTo(inner + bulge(y), y)
            }
            path.arcTo(Rect(0f, h - 2 * r, inner, h), 0f, 180f, false)
        }
        path.close()
        return androidx.compose.ui.graphics.Outline.Generic(path)
    }
}

// --- La scena a schermo intero: volo d'ingresso e menu ---

@Composable
fun StageLayer(svc: PillService) {
    // La radice di una finestra impone le sue misure: serve un contenitore
    // perché le forme dentro possano avere la loro grandezza.
    Box(Modifier.fillMaxSize()) {
        when (val stage = svc.stage) {
            is Stage.Intro -> Intro(svc, stage.from, stage.home)
            is Stage.Outro -> Outro(svc, stage.to, stage.home)
            Stage.Menu -> MenuStage(svc)
            Stage.Dismiss -> DismissTarget(svc)
            is Stage.Panel -> MenuStage(svc, stage.nest)
            null -> Unit
        }
    }
}

/**
 * Il volo d'ingresso: esce dal centro del bottone e va a sbattere sul bordo (una molla
 * che supera un poco il punto d'arrivo e torna), allungandosi mentre vola. All'impatto
 * si schiaccia di lato e tremola come gelatina.
 */
@Composable
private fun Intro(svc: PillService, from: Offset, home: Rect?) {
    val density = LocalDensity.current
    val bubble = with(density) { PillGeometry.BUBBLE.dp.toPx() }
    // Parte con la forma della capsula di casa e si gonfia nei primi istanti.
    // Se stava rientrando ed è stato rilanciato, riparte da dov'era.
    val resumeFrom = remember { svc.flight }
    val origin = resumeFrom?.center ?: from
    val startW = resumeFrom?.width ?: home?.width ?: bubble
    val startH = resumeFrom?.height ?: home?.height ?: bubble
    val target = remember { svc.barRect() }
    val t = remember { Animatable(0f) }
    val land = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        launch {
            // L'impatto arriva quando la molla tocca il bordo la prima volta.
            snapshotFlow { t.value }.first { it >= 0.98f }
            land.animateTo(1f, tween(480, easing = LinearEasing))
        }
        t.animateTo(1f, spring(dampingRatio = 0.64f, stiffness = 95f))
        land.snapTo(1f)
        svc.stageDone()
    }
    val p = t.value
    // Prima sale (in verticale accelera presto), poi curva verso il bordo (in orizzontale tardi).
    // In orizzontale la molla non supera il bordo: si ferma lì, il rimbalzo resta in verticale e nella forma.
    fun at(f: Float) = Offset(
        lerp(origin.x, target.center.x, easeIn(f.coerceAtMost(1f))),
        lerp(origin.y, target.center.y, easeOut(f)),
    )
    val f = p.coerceAtLeast(0f)
    val morph = easeOut(((p - 0.72f) / 0.28f).coerceIn(0f, 1f))
    val a = at((f - 0.02f).coerceAtLeast(0f))
    val b = at(f + 0.02f)
    val angle = Math.toDegrees(kotlin.math.atan2(b.y - a.y, b.x - a.x).toDouble()).toFloat()
    val stretch = 1f + ((b - a).getDistance() / bubble * 0.6f).coerceAtMost(0.4f) * (1f - morph)
    // Gelatina: all'impatto si schiaccia contro il bordo (più stretta e più alta), poi oscilla.
    val w = land.value
    val jelly = if (w > 0f && w < 1f) kotlin.math.sin(w * Math.PI.toFloat() * 3f) * (1f - w) * 0.22f else 0f
    val grow = smooth((p / 0.34f).coerceIn(0f, 1f))
    // Prima di staccarsi si allunga verso l'alto, come una goccia che sta per cadere al contrario.
    val neck = if (home != null) kotlin.math.sin(grow * Math.PI.toFloat()) * 0.35f else 0f
    val flightW = lerp(startW, bubble, grow) * (1f - neck * 0.4f)
    val flightH = lerp(startH, bubble, grow) * (1f + neck)
    // Transcri vola coi suoi colori; arrivando sul bordo prende quello del suo stato (a riposo: si spegne, fumo).
    val rest = isRest(svc.session.phase)
    val stateTint = morph
    val w0 = lerp(flightW, target.width, morph)
    val h0 = lerp(flightH, target.height, morph)
    svc.flight = Rect(at(f) - Offset(w0 / 2, h0 / 2), androidx.compose.ui.geometry.Size(w0, h0))
    Squish(
        center = at(f),
        w = lerp(flightW, target.width, morph),
        h = lerp(flightH, target.height, morph),
        rotation = if (morph < 1f) angle * (1f - morph) * grow else 0f,
        sx = if (morph < 1f) lerp(1f, stretch, grow) * (1f - jelly) else 1f - jelly,
        sy = if (morph < 1f) lerp(1f, 1f / stretch, grow) * (1f + jelly * 0.4f) else 1f + jelly * 0.4f,
        // A riposo atterra coi suoi colori, sveglio: è la pillola, dopo un attimo, a spegnersi e a ritirarsi.
        color = if (rest) Color.Transparent else barColor(svc.session.phase).copy(alpha = stateTint.coerceIn(0f, 1f)),
        brush = transcriBrush(),
        shadow = 0.35f + 0.65f * (1f - morph) * grow,
        eyes = 1f - morph,
        corner = if (home != null && resumeFrom == null) lerp(HOME_CORNER, 0.5f, grow) else 0.5f,
    )
}

/** Il ritorno com'era: dal bordo scende e va verso il bottone, allungandosi, e ci si tuffa. */
@Composable
private fun Outro(svc: PillService, to: Offset, home: Rect?) {
    val density = LocalDensity.current
    val bubble = with(density) { PillGeometry.BUBBLE.dp.toPx() }
    // Se stava ancora volando verso il bordo, rientra da dov'era invece che dal bordo.
    val start = remember { svc.flight ?: svc.barRect() }
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        t.animateTo(1f, tween(OUTRO_MS, easing = FastOutSlowInEasing))
        svc.stageDone()
    }
    val p = t.value
    // L'arco al contrario: si stacca di lato, poi scende nel bottone dall'alto.
    fun at(f: Float) = Offset(lerp(start.center.x, to.x, easeOut(f)), lerp(start.center.y, to.y, easeIn(f)))
    val round = (p * 2f).coerceIn(0f, 1f)
    val a = at((p - 0.02f).coerceAtLeast(0f))
    val b = at((p + 0.02f).coerceAtMost(1f))
    val angle = Math.toDegrees(kotlin.math.atan2(b.y - a.y, b.x - a.x).toDouble()).toFloat()
    val stretch = 1f + ((b - a).getDistance() / bubble * 0.6f).coerceAtMost(0.4f) * round
    // Arrivando a casa torna capsula, e bianca.
    val settle = smooth(((p - 0.66f) / 0.34f).coerceIn(0f, 1f))
    val endW = home?.width ?: 0f
    val endH = home?.height ?: 0f
    // Toccando casa si schiaccia (più larga, più bassa) e torna: un piccolo atterraggio.
    val squash = if (home != null) kotlin.math.sin(settle * Math.PI.toFloat()) * 0.22f else 0f
    // Gli ultimi istanti: si tuffa nella casa, rimpicciolisce e sparisce. Chi lo accoglie lo fa rispuntare.
    val dive = if (home != null) smooth(((p - 0.78f) / 0.22f).coerceIn(0f, 1f)) else 0f
    val w1 = lerp(lerp(start.width, bubble, round), endW, settle) * (1f - 0.6f * dive)
    val h1 = lerp(lerp(start.height, bubble, round), endH, settle) * (1f - 0.6f * dive)
    svc.flight = Rect(at(p) - Offset(w1 / 2, h1 / 2), androidx.compose.ui.geometry.Size(w1, h1))
    Squish(
        center = at(p),
        w = w1,
        h = h1,
        // Non svanisce: si rimpicciolisce fino a 0,4 e lì il nido lo riprende alla stessa misura.
        alpha = if (isRest(svc.session.phase)) lerp(Palette.smokeAlpha, 1f, round) else 1f,
        rotation = angle * round * (1f - settle),
        sx = lerp(stretch, 1f, settle) * (1f + squash),
        sy = lerp(1f / stretch, 1f, settle) * (1f - squash),
        color = barColor(svc.session.phase).copy(alpha = 1f - round),
        brush = transcriBrush(),
        shadow = 0.35f + 0.65f * round * (1f - p),
        eyes = round,
        corner = if (home != null) lerp(0.5f, HOME_CORNER, settle) else 0.5f,
    )
}

/** Una capsula centrata in [center], ruotata e deformata attorno al suo centro. */
@Composable
private fun Squish(
    center: Offset,
    w: Float,
    h: Float,
    color: Color,
    rotation: Float = 0f,
    sx: Float = 1f,
    sy: Float = 1f,
    shadow: Float = 0f,
    brush: Brush? = null,
    eyes: Float = 0f,
    // Raggio degli angoli in proporzione al lato corto: 0,5 è una capsula, a casa è un blob (0,425).
    corner: Float = 0.5f,
    alpha: Float = 1f,
) {
    val density = LocalDensity.current
    val shape = RoundedCornerShape(with(density) { (minOf(w, h) * corner).toDp() })
    Box(
        Modifier
            .offset { IntOffset((center.x - w / 2).roundToInt(), (center.y - h / 2).roundToInt()) }
            .size(with(density) { w.coerceAtLeast(1f).toDp() }, with(density) { h.coerceAtLeast(1f).toDp() })
            // L'esterno ruota, l'interno si allunga: così l'allungamento segue la direzione del volo.
            .graphicsLayer { rotationZ = rotation }
            .graphicsLayer {
                this.alpha = alpha
                scaleX = sx
                scaleY = sy
                shadowElevation = 14.dp.toPx() * shadow
                this.shape = shape
                clip = true
            }
            .then(if (brush != null) Modifier.background(brush) else Modifier)
            .background(color)
            .drawWithContent {
                drawContent()
                if (eyes > 0f) drawEyes(eyes)
            }
    )
}

/** Due occhi bianchi in alto, che si allungano e ruotano col corpo. Svaniscono sul bordo (è troppo sottile). */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawEyes(alpha: Float) {
    val r = minOf(size.width, size.height) * 0.075f
    val y = size.height * 0.36f
    for (dx in listOf(-0.17f, 0.17f)) {
        drawCircle(Color.White.copy(alpha = alpha), r, Offset(size.width * (0.5f + dx), y))
    }
}

/**
 * Mentre lo trascini. Transcri si stacca dal bordo con un pop (da pillola diventa il suo blob)
 * e segue il dito con un filo di ritardo. Fuori dall'app, in basso compare la sua casa: una
 * piccola pillola spenta, come lui a riposo. Avvicinandolo la casa si allarga e lui prende la
 * sua forma; lasciandolo lì ci entra, la casa si riempie dei suoi colori, si gonfia e sparisce.
 * Con l'app aperta la casa è il nido dell'app: lui prende la forma del posto che ha lì.
 */
@Composable
private fun DismissTarget(svc: PillService) {
    val density = LocalDensity.current
    val px = { dp: Float -> with(density) { dp.dp.toPx() } }
    val center = remember { svc.dismissCenter() }
    val nest = remember { PillService.appNest }
    val appear = remember { Animatable(0f) }
    val uproot = remember { Animatable(0f) }
    val home = remember { Animatable(0f) }
    val start = remember { svc.barRect() }
    LaunchedEffect(Unit) {
        launch { uproot.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 500f)) }
        appear.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = 600f))
    }
    LaunchedEffect(svc.absorbing) {
        if (svc.absorbing) {
            home.animateTo(1f, tween(700, easing = LinearEasing))
            svc.stageDone()
        }
    }
    val near by animateFloatAsState(svc.nearness, spring(dampingRatio = 0.7f, stiffness = 500f), label = "near")
    val hot by animateFloatAsState(if (svc.dismissHot) 1f else 0f, spring(dampingRatio = 0.45f, stiffness = 700f), label = "hot")
    // Segue il dito con un filo di ritardo, e si lascia attirare dalla casa.
    val pos by androidx.compose.animation.core.animateOffsetAsState(
        svc.dragPoint, spring(dampingRatio = 0.85f, stiffness = 2200f), label = "pos",
    )

    // La casa fuori dall'app: quanto è grande adesso. Tre tempi quando lui entra:
    // si riempie dei suoi colori (0–0,3), si gonfia (0,25–0,6), si stringe e sparisce (0,6–1).
    val h = home.value
    val fill = smooth((h / 0.3f).coerceIn(0f, 1f))
    val swell = if (h < 0.25f) 0f else kotlin.math.sin(((h - 0.25f) / 0.35f).coerceIn(0f, 1f) * Math.PI.toFloat() / 2f)
    val gone = smooth(((h - 0.6f) / 0.4f).coerceIn(0f, 1f))
    val a = appear.value
    val homeW = lerp(px(44f), px(104f), near) * (0.6f + 0.4f * a) * (1f + 0.1f * hot) * (1f + 0.22f * swell) * (1f - gone)
    val homeH = lerp(px(14f), px(36f), near) * (0.6f + 0.4f * a) * (1f + 0.1f * hot) * (1f + 0.22f * swell) * (1f - 0.6f * gone)

    if (nest == null) {
        // Un velo leggero dal basso, per far leggere la casa su qualunque sfondo.
        Box(
            Modifier
                .fillMaxSize()
                .alpha((a * (1f - gone) * (0.5f + 0.5f * near)).coerceIn(0f, 1f))
                .background(Brush.verticalGradient(0.7f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.3f)))
        )
        // La casa: spenta come lui a riposo (fumo); quando lui entra si riempie dei suoi colori.
        Box(
            Modifier
                .offset { IntOffset((center.x - homeW / 2).roundToInt(), (center.y - homeH / 2 + (1f - a) * px(40f)).roundToInt()) }
                .size(with(density) { homeW.coerceAtLeast(1f).toDp() }, with(density) { homeH.coerceAtLeast(1f).toDp() })
                .alpha((a * (1f - gone)).coerceIn(0f, 1f))
                .clip(CircleShape)
                .background(casaFumo(near))
                .background(transcriBrush(), alpha = fill)
                .border(1.dp, Palette.Stroke, CircleShape)
                .drawWithContent {
                    drawContent()
                    if (fill > 0f) drawEyes(fill * (1f - gone))
                }
        )
    }

    if (!svc.absorbing) {
        // La forma che prende avvicinandosi: dentro la casa in basso (larga e bassa) o il suo posto nel nido.
        val fitW = nest?.width ?: (homeW * 0.86f)
        val fitH = nest?.height ?: (homeH * 0.7f)
        val u = uproot.value
        val blobW = lerp(start.width, px(44f), u)
        val blobH = lerp(start.height, px(40f), u)
        val w = lerp(blobW, fitW, near)
        val hh = lerp(blobH, fitH, near)
        val corner = if (nest != null) lerp(lerp(0.5f, HOME_CORNER, u), HOME_CORNER, near) else lerp(lerp(0.5f, HOME_CORNER, u), 0.5f, near)
        // Il pop del distacco: un attimo più largo e basso, poi la molla lo rimette in forma.
        val pop = 1f + 0.18f * kotlin.math.sin(u.coerceIn(0f, 1f) * Math.PI.toFloat())
        svc.flight = Rect(pos - Offset(w / 2, hh / 2), androidx.compose.ui.geometry.Size(w, hh))
        Squish(
            center = pos,
            w = w,
            h = hh,
            sx = pop,
            sy = 1f / pop,
            color = Color.Transparent,
            brush = transcriBrush(),
            // Dentro la casa in basso diventa basso e largo: gli occhi si fanno da parte.
            eyes = u * (1f - (if (nest == null) 0.6f * near else 0f)),
            shadow = 0.5f * (1f - near),
            corner = corner,
        )
    } else {
        // Ci entra: dal punto in cui l'hai lasciato si stringe dentro la casa.
        val from = remember { svc.flight ?: start }
        if (fill < 1f) {
            Squish(
                center = Offset(lerp(from.center.x, center.x, fill), lerp(from.center.y, center.y, fill)),
                w = lerp(from.width, homeW * 0.6f, fill),
                h = lerp(from.height, homeH * 0.6f, fill),
                color = Color.Transparent,
                brush = transcriBrush(),
                alpha = 1f - fill,
                corner = 0.5f,
            )
        }
    }
}

@Composable
private fun MenuStage(svc: PillService, nest: Rect? = null) {
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val t = remember { Animatable(0f) }
    var closing by remember { mutableStateOf(false) }
    // Dalla pillola sul bordo o, con Transcri nel Dock, dal suo posto.
    val bar = remember { nest ?: svc.barRect() }
    LaunchedEffect(Unit) { t.animateTo(1f, spring(dampingRatio = 0.68f, stiffness = Spring.StiffnessMediumLow)) }

    fun collapse() {
        if (closing) return
        closing = true
        scope.launch {
            t.animateTo(0f, tween(Durate.VELOCE, easing = FastOutSlowInEasing))
            svc.stageDone()
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = constraints.maxWidth.toFloat()
        val h = constraints.maxHeight.toFloat()
        val margin = with(density) { PillGeometry.MENU_MARGIN.dp.toPx() }
        // Il pannello è largo quanto la carta; alto quanto serve: si misura il contenuto e il pannello lo segue.
        // Stretto (i cassetti e il microfono) finché non esce una carta o non parli: allora si allarga (morfa tra le fasi).
        val largo = svc.carta != null || svc.session.phase !in setOf(Phase.IDLE, Phase.SUCCESS)
        val mwDp by animateFloatAsState(
            if (largo) PillGeometry.PANNELLO_W else PillGeometry.PANNELLO_STRETTO,
            spring(dampingRatio = 0.8f, stiffness = 420f), label = "menuW",
        )
        val mw = minOf(with(density) { mwDp.dp.toPx() }, w - margin * 2)
        var contenuto by remember { mutableFloatStateOf(0f) }
        val mh by animateFloatAsState(
            if (contenuto > 0f) contenuto else with(density) { PillGeometry.PANNELLO_MIN.dp.toPx() },
            spring(dampingRatio = 0.8f, stiffness = 420f), label = "menuH",
        )
        // Il registratore resta accanto alla pillola: la carta cresce verso l'alto.
        val right = if (nest != null) nest.center.x > w / 2 else svc.pillRight
        val left = if (right) w - mw - margin else margin
        val bottom = if (nest != null) nest.top - margin
        // Mai fin su in cima: il pannello resta verso il centro (la carta si scorre).
        else (bar.center.y + with(density) { PillGeometry.SOTTO_LA_PILLOLA.dp.toPx() }).coerceIn(minOf(mh + h * 0.12f, h - margin * 4), h - margin * 4)
        val menu = Rect(left, bottom - mh, left + mw, bottom)
        val p = t.value

        // Velo: un tocco fuori richiude, la registrazione continua.
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.32f * p.coerceIn(0f, 1f)))
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { collapse() }
        )
        Blob(
            rect = lerpRect(bar, menu, p),
            // Si apre dal suo colore (a riposo e mentre trascrive) o da quello dello stato, mai dal grigio.
            color = lerp(
                if (isRest(svc.session.phase) || svc.session.phase == Phase.PROCESSING) Palette.AccentA else barColor(svc.session.phase),
                Palette.Panel, p.coerceIn(0f, 1f),
            ),
            shadow = p.coerceIn(0f, 1f),
            maxRadius = with(density) { PillGeometry.MENU_RADIUS.dp.toPx() },
        ) {
            val visible = ((p - 0.55f) / 0.45f).coerceIn(0f, 1f)
            Pannello(
                svc,
                maxCarta = with(density) { (h * 0.36f).toDp() },
                onCollapse = ::collapse,
                modifier = Modifier
                    .fillMaxSize()
                    .wrapContentHeight(Alignment.Bottom, unbounded = true)
                    .onSizeChanged { contenuto = it.height.toFloat() }
                    .alpha(visible),
            )
        }
    }
}

/** Una forma a capsula disegnata in un rettangolo qualunque dello schermo. */
@Composable
private fun Blob(
    rect: Rect,
    color: Color,
    shadow: Float,
    stroke: Boolean = true,
    maxRadius: Float = Float.MAX_VALUE,
    content: @Composable () -> Unit = {},
) {
    val density = LocalDensity.current
    val radius = with(density) { minOf(minOf(rect.width, rect.height) / 2, maxRadius).toDp() }
    val shape = RoundedCornerShape(radius)
    Box(
        Modifier
            .offset { IntOffset(rect.left.roundToInt(), rect.top.roundToInt()) }
            .size(with(density) { rect.width.coerceAtLeast(1f).toDp() }, with(density) { rect.height.coerceAtLeast(1f).toDp() })
            .shadow((16 * shadow).dp, shape, clip = false) // ds:eccezione: il movimento di Transcri (l'ombra cresce mentre si apre)
            .background(color, shape)
            .then(if (stroke) Modifier.border(1.dp, Palette.Stroke, shape) else Modifier)
            .clip(shape),
        contentAlignment = Alignment.Center,
    ) { content() }
}

// --- Il pannello (Figma B12, riga «7 · Finale») ---

/**
 * Il registratore e la carta: in basso il registratore, sempre uguale; sopra il caret, che fa uscire la carta
 * (i vocali condivisi o l'ultima trascrizione, coi loro comandi). Niente X: si chiude toccando fuori.
 * La pulizia (Fedele · Pulita · Riassunto) compare sotto quando parli.
 */
@Composable
private fun Pannello(svc: PillService, maxCarta: Dp, onCollapse: () -> Unit, modifier: Modifier) {
    val s = svc.session
    val haUltima = s.hasLast && s.phase != Phase.LIMITED
    val carta = svc.carta?.takeIf { it == Carta.ULTIMA && haUltima || it == Carta.VOCALI && svc.vocali.isNotEmpty() }
    val parla = s.phase == Phase.RECORDING || s.phase == Phase.PROCESSING
    Column(modifier.padding(horizontal = 12.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        AnimatedVisibility(
            carta != null,
            enter = expandVertically(expandFrom = Alignment.Bottom) + fadeIn(),
            exit = shrinkVertically(shrinkTowards = Alignment.Bottom) + fadeOut(),
        ) {
            Column {
                // Tenuta durante l'uscita: la carta che rientra resta quella di prima.
                val ultima = remember { mutableStateOf(Carta.ULTIMA) }
                if (carta != null) ultima.value = carta
                CartaFuori(svc, ultima.value, maxCarta)
                Spacer(Modifier.height(8.dp))
            }
        }
        if (haUltima || svc.vocali.isNotEmpty()) Cassetti(svc, haUltima)
        StatoRegistratore(svc.session)
        Spacer(Modifier.height(6.dp))
        TastiVoce(svc, onCollapse)
        AnimatedVisibility(parla) {
            Column {
                Spacer(Modifier.height(10.dp))
                ModeSlider(s)
            }
        }
    }
}

/** Sopra i tasti: il tempo e l'onda mentre registri, un errore o un avviso; a riposo niente. */
@Composable
private fun StatoRegistratore(s: Session) {
    if (s.phase == Phase.IDLE && s.notice == null) return
    Box(Modifier.fillMaxWidth().padding(top = 6.dp).heightIn(min = 26.dp), contentAlignment = Alignment.Center) { Status(s) }
}

/** I tasti di Transcri: butta · il tasto grande · pausa. */
@Composable
private fun TastiVoce(svc: PillService, onCollapse: () -> Unit) {
    val s = svc.session
    val recording = s.phase == Phase.RECORDING
    // A riposo c'è solo il microfono, al centro: i posti di butta e pausa esistono solo quando servono
    // (vuoti, spingevano il microfono a destra nel pannello stretto).
    if (!recording && s.phase != Phase.ERROR) {
        Box(Modifier.size(60.dp), contentAlignment = Alignment.Center) { MainButton(svc, onCollapse) }
        return
    }
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
            if (recording || s.phase == Phase.ERROR) CircleButton(Icons.Rounded.DeleteOutline, "Butta l'audio", Palette.Muted) { s.discard() }
        }
        Box(Modifier.size(60.dp), contentAlignment = Alignment.Center) { MainButton(svc, onCollapse) }
        Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
            if (recording) {
                CircleButton(
                    if (s.paused) Icons.Rounded.PlayArrow else Icons.Rounded.Pause,
                    if (s.paused) "Riprendi" else "Pausa",
                    if (s.paused) Palette.Paused else Palette.Text,
                ) { s.togglePause() }
            }
        }
    }
}

@Composable
private fun MainButton(svc: PillService, onCollapse: () -> Unit) {
    val s = svc.session
    when (s.phase) {
        Phase.IDLE, Phase.SUCCESS -> RoundButton(Icons.Rounded.Mic, "Registra", Palette.Blue, Palette.Text) { s.start() }
        Phase.RECORDING -> RoundButton(Icons.Rounded.Check, "Ferma e trascrivi", Palette.Red, Palette.Text) {
            // Mandato a trascrivere: hai finito, il pannello si chiude (la pausa invece non chiude niente).
            s.stopAndSend()
            onCollapse()
        }
        Phase.ERROR -> when (s.fix) {
            Fix.RETRY -> RoundButton(Icons.Rounded.Refresh, "Riprova", Palette.Yellow, Palette.Ink) { s.retry() }
            Fix.SETTINGS -> RoundButton(Icons.Rounded.Settings, "Apri le impostazioni", Palette.Yellow, Palette.Ink) {
                svc.openAppSettings()
                onCollapse()
            }
            Fix.NONE -> RoundButton(Icons.Rounded.Mic, "Registra", Palette.Text, Palette.Ink) { s.start() }
        }
        Phase.LIMITED -> RoundButton(Icons.Rounded.Schedule, "Minuti finiti", Palette.Muted.copy(alpha = 0.2f), Palette.Muted) {}
        // Lavora: il blob che ondeggia (sua richiesta: la sua caratteristica è ondulare, non un cerchio fermo).
        Phase.PROCESSING -> BlobLavoro(Modifier.size(52.dp).semantics { contentDescription = "Sto trascrivendo" })
    }
}

/** Transcri al lavoro: una goccia coi suoi due toni, il bordo che ondeggia piano. */
@Composable
internal fun BlobLavoro(modifier: Modifier) {
    val giro by rememberInfiniteTransition(label = "blob").animateFloat(
        0f, (2 * Math.PI).toFloat(), infiniteRepeatable(tween(BLOB_GIRO_MS, easing = LinearEasing)), label = "giro",
    )
    val brush = transcriBrush()
    Canvas(modifier) {
        val path = Path()
        val r0 = size.minDimension / 2 * 0.86f
        for (i in 0..BLOB_PUNTI) {
            val a = i * 2 * Math.PI / BLOB_PUNTI
            val r = r0 * (1 + 0.07f * sin(3 * a + giro).toFloat() + 0.05f * sin(2 * a - 1.7 * giro).toFloat())
            val x = center.x + r * cos(a).toFloat()
            val y = center.y + r * sin(a).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        drawPath(path, brush)
    }
}

private const val BLOB_GIRO_MS = 2400
private const val BLOB_PUNTI = 48

/**
 * Copia l'ultima: i due fogli di copia (come l'icona di Material) e, in alto a destra, un
 * piccolo orologio staccato dal foglio: la cosa più recente che hai dettato.
 */
internal val CopyAgain: ImageVector by lazy {
    fun ImageVector.Builder.fill(d: String, evenOdd: Boolean = false) = addPath(
        pathData = androidx.compose.ui.graphics.vector.addPathNodes(d),
        fill = SolidColor(Color.Black),
        pathFillType = if (evenOdd) androidx.compose.ui.graphics.PathFillType.EvenOdd else androidx.compose.ui.graphics.PathFillType.NonZero,
    )
    ImageVector.Builder("CopyAgain", 24.dp, 24.dp, 24f, 24f)
        // il foglio dietro
        .fill("M15 20H5V7c0-.55-.45-1-1-1s-1 .45-1 1v13c0 1.1.9 2 2 2h10c.55 0 1-.45 1-1s-.45-1-1-1z")
        // il foglio davanti, con l'incavo dove sta l'orologio
        .fill("M9 2H14.17A5.6 5.6 0 0 0 20 11.51V16c0 1.1-.9 2-2 2H9c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2z")
        // l'orologio: un disco con le lancette scavate
        .fill(
            "M17.5 2.1a4.4 4.4 0 1 1 0 8.8a4.4 4.4 0 1 1 0-8.8z" +
                "M16.9 3.9h1.2v2.2h-1.2z" +
                "M16.9 6.1h2.7v1.1h-2.7z",
            evenOdd = true,
        )
        .build()
}

/** Un bottone secondario: un cerchio vero, appena visibile, così si capisce che si tocca. */
@Composable
internal fun CircleButton(icon: ImageVector, label: String, tint: Color, small: Boolean = false, onClick: () -> Unit) {
    val d = if (small) 32.dp else 40.dp
    Box(
        Modifier
            .size(d)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.08f))
            .clickable(onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = tint, modifier = Modifier.size(if (small) 18.dp else 20.dp)) }
}

/** La riga in alto: il tempo mentre registra, altrimenti niente. */
@Composable
private fun Headline(s: Session) {
    if (s.phase != Phase.RECORDING) return
    val sec = s.elapsedMs / 1000
    Row(verticalAlignment = Alignment.CenterVertically) {
        val pulse = rememberInfiniteTransition(label = "dot")
        val a by pulse.animateFloat(1f, 0.25f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "a")
        Box(
            Modifier.size(7.dp).alpha(if (s.paused) 1f else a)
                .background(if (s.paused) Palette.Paused else Palette.Red, CircleShape)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            if (s.paused) "in pausa" else "%02d:%02d".format(sec / 60, sec % 60),
            style = Caratteri.etichetta.copy(color = if (s.paused) Palette.Paused else Palette.Text),
        )
    }
}

/**
 * Il selettore dei modi: Fedele · Pulita · Riassunto. Si tocca o si trascina il dito sopra;
 * toccare quello acceso spegne la pulizia (e allora non è evidenziato niente).
 */
@Composable
private fun ModeSlider(s: Session) {
    val modes = listOf("fedele" to "Fedele", "pulita" to "Pulita", "riassunto" to "Riassunto")
    val selected = if (s.purify) modes.indexOfFirst { it.first == s.mode } else -1
    val knob by animateFloatAsState(selected.coerceAtLeast(0).toFloat(), spring(dampingRatio = 0.7f, stiffness = 600f), label = "knob")
    val shown by animateFloatAsState(if (selected >= 0) 1f else 0f, tween(180), label = "shown")
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(34.dp)
            .clip(Forme.pillola)
            .background(Color.White.copy(alpha = 0.08f))
            .pointerInput(Unit) {
                // Trascinando si sceglie il modo sotto il dito; un tocco solo può anche spegnere.
                detectHorizontalDragGestures { change, _ ->
                    val i = (change.position.x / size.width * 3).toInt().coerceIn(0, 2)
                    if (!s.purify || s.mode != modes[i].first) s.pickMode(modes[i].first)
                }
            }
            .pointerInput(Unit) {
                detectTapGestures { pos ->
                    val i = (pos.x / size.width * 3).toInt().coerceIn(0, 2)
                    s.pickMode(modes[i].first)
                }
            },
    ) {
        val cell = maxWidth / 3
        Box(
            Modifier
                .offset(x = cell * knob)
                .size(cell, 34.dp)
                .padding(3.dp)
                .alpha(shown)
                .background(Palette.Blue.copy(alpha = 0.9f), Forme.pillola)
        )
        Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            modes.forEachIndexed { i, (_, label) ->
                Text(
                    label,
                    modifier = Modifier.weight(1f).padding(horizontal = 2.dp),
                    textAlign = TextAlign.Center,
                    style = Caratteri.orario.copy(fontWeight = FontWeight.SemiBold, color = if (i == selected) Palette.Text else Palette.Muted),
                )
            }
        }
    }
}

/** L'onda della voce: tratti verticali quando parli, puntini quando taci. In pausa è gialla e ferma. */
@Composable
private fun Wave(s: Session, modifier: Modifier) {
    val color = if (s.paused) Palette.Paused else Palette.Text
    // Ridisegna a ogni fotogramma: tra un campione e l'altro l'onda scivola a sinistra di un passo,
    // così scorre in continuo invece di scattare ogni 70 ms.
    val now by androidx.compose.runtime.produceState(0L) {
        while (true) androidx.compose.runtime.withFrameNanos { value = it }
    }
    androidx.compose.foundation.Canvas(modifier.clip(androidx.compose.ui.graphics.RectangleShape)) {
        val n = s.levels.size
        val gap = size.width / n
        val bar = gap * 0.55f
        val slide = if (s.paused) 1f else ((now - s.sampledAt) / 70_000_000f).coerceIn(0f, 1f)
        for (i in 0 until n) {
            val v = s.levels[i]
            val x = gap * (i + 0.5f) + gap * (1f - slide)
            // I più vecchi sbiadiscono a sinistra.
            val fade = 0.35f + 0.65f * (i + 1f) / n
            if (v < 0.06f) {
                drawCircle(color.copy(alpha = fade * 0.8f), bar / 2, Offset(x, size.height / 2))
            } else {
                val h = (size.height * v).coerceAtLeast(bar)
                drawLine(
                    color.copy(alpha = fade),
                    Offset(x, size.height / 2 - h / 2),
                    Offset(x, size.height / 2 + h / 2),
                    bar,
                    androidx.compose.ui.graphics.StrokeCap.Round,
                )
            }
        }
    }
}

@Composable
private fun Status(s: Session) {
    val small = Caratteri.orario.copy(color = Palette.Text, textAlign = TextAlign.Center)
    s.notice?.let {
        Text(it, style = small.copy(color = Palette.Muted))
        return
    }
    when (s.phase) {
        // Il tempo accanto all'onda (sopra gli faceva strano).
        Phase.RECORDING -> Row(Modifier.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Headline(s)
            Spacer(Modifier.width(10.dp))
            Wave(s, Modifier.weight(1f).height(26.dp))
        }
        // Lavora: lo dice il blob, niente scritta (sua richiesta).
        Phase.PROCESSING -> Unit
        Phase.SUCCESS -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Copiato ✓", style = small.copy(color = Palette.Green, fontWeight = FontWeight.Medium))
        }
        Phase.ERROR -> Column(
            Modifier.padding(horizontal = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(s.error ?: "Errore", style = small.copy(color = Palette.Yellow), maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        Phase.LIMITED -> Text("Minuti finiti, " + s.limitText, style = small.copy(color = Palette.Muted), maxLines = 2)
        // Prima del via non c'è niente da mostrare: l'onda nasce quando si registra.
        Phase.IDLE -> Unit
    }
}

@Composable
internal fun RoundButton(icon: ImageVector, label: String, bg: Color, fg: Color, onClick: () -> Unit) {
    Box(
        Modifier
            .size(52.dp)
            .clip(CircleShape)
            .background(bg)
            .clickable(onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = fg, modifier = Modifier.size(26.dp)) }
}

/**
 * La tana in basso, spenta come lui a riposo: un po' più piena quanto più lui si avvicina ([near] da 0 a 1),
 * ma sempre in proporzione alla trasparenza scelta (prima un +0,2 fisso la riempiva comunque: lo slider non si vedeva).
 */
internal fun casaFumo(near: Float) = Palette.Smoke.copy(alpha = Palette.opacitaCasa * lerp(0.8f, 1f, near))

/** Durata del ritorno: l'app aspetta questo tempo prima di riattaccare la bolla al bottone. */
const val OUTRO_MS = 640

/** Mentre trascrive il riquadro si allarga verso il centro di questa frazione: lì escono le onde. */
const val WORK_GROW = 0.45f

/** Gli angoli di Transcri a casa (nel nido dell'app e nel widget), in proporzione al lato corto. */
const val HOME_CORNER = 0.425f

/** Durata del volo d'ingresso, prima dell'atterraggio. */
const val INTRO_MS = 700

private fun easeOut(x: Float) = 1f - (1f - x) * (1f - x)
private fun easeIn(x: Float) = x * x
private fun smooth(x: Float) = x * x * (3f - 2f * x)
private fun lerpRect(a: Rect, b: Rect, t: Float) =
    Rect(lerp(a.left, b.left, t), lerp(a.top, b.top, t), lerp(a.right, b.right, t), lerp(a.bottom, b.bottom, t))
