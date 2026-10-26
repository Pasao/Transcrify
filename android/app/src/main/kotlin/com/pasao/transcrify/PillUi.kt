package com.pasao.transcrify

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
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
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
import kotlin.math.roundToInt

/** Misure della pillola, in dp. */
object PillGeometry {
    const val TOUCH_W = 40f
    const val TOUCH_W_RECORDING = 80f
    const val TOUCH_H = 160f
    const val BAR_W = 12f
    const val BAR_H = 88f
    const val BAR_INSET = 3f
    const val MENU_W = 224f
    const val MENU_H = 216f
    const val MENU_RADIUS = 28f
    const val MENU_MARGIN = 10f
    const val BUBBLE = 56f
    const val DISMISS = 60f
    const val DISMISS_BOTTOM = 120f
    const val DISMISS_MAGNET = 96f
}

/** Colori, presi dalla palette di Figma. */
object Palette {
    val Panel = Color(0xF22C2C2C)
    val Ink = Color(0xFF1E1E1E)
    val Stroke = Color(0x40FFFFFF)
    val Text = Color(0xFFFFFFFF)
    val Muted = Color(0x99FFFFFF)
    val Blue = Color(0xFF0D99FF)
    val Red = Color(0xFFF24822)
    val Yellow = Color(0xFFFFCD29)
    val Green = Color(0xFF14AE5C)
    val Idle = Color(0xD92C2C2C)
    val Paused = Color(0xFFB3B3B3)
}

private fun barColor(phase: Phase, paused: Boolean = false) = when (phase) {
    Phase.RECORDING -> if (paused) Palette.Paused else Palette.Red
    Phase.PROCESSING -> Palette.Blue
    Phase.SUCCESS -> Palette.Green
    Phase.ERROR -> Palette.Yellow
    Phase.IDLE -> Palette.Idle
    Phase.LIMITED -> Palette.Idle.copy(alpha = 0.35f)
}

// --- La pillola sul bordo ---

@Composable
fun PillBar(svc: PillService) {
    val phase = svc.session.phase
    val color by animateColorAsState(barColor(phase, svc.session.paused), tween(250), label = "bar")
    val pulse = rememberInfiniteTransition(label = "pulse")
    val beat by pulse.animateFloat(
        initialValue = 1f, targetValue = 0.45f,
        animationSpec = infiniteRepeatable(tween(700, easing = LinearEasing), RepeatMode.Reverse), label = "beat",
    )
    val listening = phase == Phase.RECORDING && !svc.session.paused
    val voice by animateFloatAsState(if (listening) svc.session.level else 0f, tween(90), label = "voice")
    val alive = phase == Phase.PROCESSING
    // Tenendo premuto: si gonfia e si colora finché scatta (rosso per partire, blu per fermare).
    val hold by animateFloatAsState(
        if (svc.holding) 1f else 0f,
        if (svc.holding) tween((PillService.HOLD_MS - 60).toInt(), easing = LinearEasing) else spring(dampingRatio = 0.4f, stiffness = 700f),
        label = "hold",
    )
    val holdColor = if (phase == Phase.RECORDING) Palette.Blue else Palette.Red
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
                    scaleX = 1f + voice * 0.35f + hold.coerceAtLeast(0f) * 0.9f
                    scaleY = 1f + voice * 0.08f + hold.coerceAtLeast(0f) * 0.14f
                }
                .alpha(if (alive) beat else if (listening) 0.75f + 0.25f * voice else 1f)
                .background(lerp(color, holdColor, hold.coerceIn(0f, 1f)), CircleShape)
                .border(1.dp, Palette.Stroke, CircleShape)
        )
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
    fun at(f: Float) = Offset(lerp(origin.x, target.center.x, easeIn(f)), lerp(origin.y, target.center.y, easeOut(f)))
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
    // Bianca come la capsula di casa, diventa blu appena esce.
    val flightColor = if (home != null && resumeFrom == null) lerp(Color.White, Palette.Blue, grow) else Palette.Blue
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
        color = lerp(flightColor, barColor(svc.session.phase), morph.coerceIn(0f, 1f)),
        shadow = (1f - morph) * grow,
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
    val w1 = lerp(lerp(start.width, bubble, round), endW, settle)
    val h1 = lerp(lerp(start.height, bubble, round), endH, settle)
    svc.flight = Rect(at(p) - Offset(w1 / 2, h1 / 2), androidx.compose.ui.geometry.Size(w1, h1))
    Squish(
        center = at(p),
        w = lerp(lerp(start.width, bubble, round), endW, settle),
        h = lerp(lerp(start.height, bubble, round), endH, settle),
        rotation = angle * round * (1f - settle),
        sx = lerp(stretch, 1f, settle) * (1f + squash),
        sy = lerp(1f / stretch, 1f, settle) * (1f - squash),
        color = lerp(lerp(barColor(svc.session.phase), Palette.Blue, round), if (home != null) Color.White else Palette.Blue, settle),
        shadow = round * (1f - p),
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
) {
    val density = LocalDensity.current
    val shape = RoundedCornerShape(percent = 50)
    Box(
        Modifier
            .offset { IntOffset((center.x - w / 2).roundToInt(), (center.y - h / 2).roundToInt()) }
            .size(with(density) { w.coerceAtLeast(1f).toDp() }, with(density) { h.coerceAtLeast(1f).toDp() })
            // L'esterno ruota, l'interno si allunga: così l'allungamento segue la direzione del volo.
            .graphicsLayer { rotationZ = rotation }
            .graphicsLayer {
                scaleX = sx
                scaleY = sy
                shadowElevation = 14.dp.toPx() * shadow
                this.shape = shape
                clip = true
            }
            .background(color)
    )
}

/**
 * La X in basso mentre si trascina. Quando la pillola è vicina la X si gonfia;
 * se la pillola viene lasciata lì, la X la inghiotte come un buco nero.
 */
@Composable
private fun DismissTarget(svc: PillService) {
    val density = LocalDensity.current
    val center = remember { svc.dismissCenter() }
    val base = with(density) { PillGeometry.DISMISS.dp.toPx() }
    val appear = remember { Animatable(0f) }
    val swallow = remember { Animatable(0f) }
    LaunchedEffect(Unit) { appear.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = 900f)) }
    LaunchedEffect(svc.absorbing) {
        if (svc.absorbing) {
            swallow.animateTo(1f, tween(300, easing = FastOutSlowInEasing))
            svc.stageDone()
        }
    }
    val hot by animateFloatAsState(if (svc.dismissHot) 1f else 0f, spring(dampingRatio = 0.45f, stiffness = 1100f), label = "hot")
    val s = swallow.value
    // Buco nero: si allarga mentre inghiotte, poi si richiude su se stesso.
    val hole = if (s < 0.45f) 1f + 0.5f * (s / 0.45f) else 1.5f * (1f - ((s - 0.45f) / 0.55f)).coerceAtLeast(0f)
    val size = base * (0.6f + 0.4f * appear.value) * (1f + 0.3f * hot) * (if (svc.absorbing) hole else 1f)
    val lift = (1f - appear.value) * base

    // Un velo che sale dal basso, per far leggere la X su qualunque sfondo.
    Box(
        Modifier
            .fillMaxSize()
            .alpha(appear.value.coerceIn(0f, 1f) * (1f - s))
            .background(Brush.verticalGradient(0.6f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.45f)))
    )
    if (svc.absorbing) {
        // La pillola risucchiata: si accorcia e gira entrando nel centro.
        val bw = with(density) { PillGeometry.BAR_W.dp.toPx() } * (1f - s).coerceAtLeast(0f)
        val bh = with(density) { PillGeometry.BAR_H.dp.toPx() } * (1f - s * 1.4f).coerceAtLeast(0f)
        Box(
            Modifier
                .offset { IntOffset((center.x - bw / 2).roundToInt(), (center.y - bh / 2).roundToInt()) }
                .size(with(density) { bw.toDp() }, with(density) { bh.toDp() })
                .graphicsLayer { rotationZ = 300f * s }
                .background(barColor(svc.session.phase), CircleShape)
        )
    }
    Box(
        Modifier
            .offset { IntOffset((center.x - size / 2).roundToInt(), (center.y - size / 2 + lift).roundToInt()) }
            .size(with(density) { size.coerceAtLeast(1f).toDp() })
            .alpha(appear.value.coerceIn(0f, 1f))
            .background(lerp(Color(0xCC1E1E1E), Palette.Red, hot * (1f - s)), CircleShape)
            .border(1.dp, Palette.Stroke, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Rounded.Close, "Chiudi la pillola",
            tint = Palette.Text.copy(alpha = 1f - s),
            modifier = Modifier.size(with(density) { (size * 0.4f).toDp() }),
        )
    }
}

@Composable
private fun MenuStage(svc: PillService) {
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val t = remember { Animatable(0f) }
    var closing by remember { mutableStateOf(false) }
    val bar = remember { svc.barRect() }
    LaunchedEffect(Unit) { t.animateTo(1f, spring(dampingRatio = 0.68f, stiffness = Spring.StiffnessMediumLow)) }

    fun collapse() {
        if (closing) return
        closing = true
        scope.launch {
            t.animateTo(0f, tween(200, easing = FastOutSlowInEasing))
            svc.stageDone()
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = constraints.maxWidth.toFloat()
        val h = constraints.maxHeight.toFloat()
        val mw = with(density) { PillGeometry.MENU_W.dp.toPx() }
        // Quando non c'è niente da dire il menu è più corto: niente vuoto in mezzo.
        val mh = with(density) { PillGeometry.MENU_H.dp.toPx() }
        val margin = with(density) { PillGeometry.MENU_MARGIN.dp.toPx() }
        val left = if (svc.pillRight) w - mw - margin else margin
        val top = (bar.center.y - mh / 2).coerceIn(margin * 4, h - mh - margin * 4)
        val menu = Rect(left, top, left + mw, top + mh)
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
            color = lerp(barColor(svc.session.phase), Palette.Panel, p.coerceIn(0f, 1f)),
            shadow = p.coerceIn(0f, 1f),
            maxRadius = with(density) { PillGeometry.MENU_RADIUS.dp.toPx() },
        ) {
            Menu(svc, visible = ((p - 0.55f) / 0.45f).coerceIn(0f, 1f), onCollapse = ::collapse)
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
            .shadow((16 * shadow).dp, shape, clip = false)
            .background(color, shape)
            .then(if (stroke) Modifier.border(1.dp, Palette.Stroke, shape) else Modifier),
        contentAlignment = Alignment.Center,
    ) { content() }
}

// --- Il menu ---

@Composable
private fun Menu(svc: PillService, visible: Float, onCollapse: () -> Unit) {
    val s = svc.session
    val recording = s.phase == Phase.RECORDING
    Box(
        Modifier
            .alpha(visible)
            .size(PillGeometry.MENU_W.dp, PillGeometry.MENU_H.dp)
            .padding(12.dp),
    ) {
        Column(Modifier.fillMaxSize()) {
            // Angoli in alto: a sinistra il tempo (o copia), a destra la X.
            Row(Modifier.fillMaxWidth().height(36.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                    when {
                        recording -> Box(Modifier.padding(start = 8.dp)) { Headline(s) }
                        s.hasLast && s.phase != Phase.PROCESSING -> CopyLast(s)
                    }
                }
                CircleButton(Icons.Rounded.Close, "Rimpicciolisci", Palette.Muted, small = true, onClick = onCollapse)
            }
            // Centro: l'onda (solo registrando) o il messaggio, poi il bottone grande coi suoi due compagni.
            Column(Modifier.weight(1f).fillMaxWidth(), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.fillMaxWidth().height(26.dp), contentAlignment = Alignment.Center) { Status(s) }
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Box(Modifier.size(40.dp), contentAlignment = Alignment.Center) {
                        if (recording || s.phase == Phase.ERROR) {
                            CircleButton(Icons.Rounded.DeleteOutline, "Butta l'audio", Palette.Muted) { s.discard() }
                        }
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
            ModeSlider(s)
        }
    }
}

@Composable
private fun MainButton(svc: PillService, onCollapse: () -> Unit) {
    val s = svc.session
    when (s.phase) {
        Phase.IDLE, Phase.SUCCESS -> RoundButton(Icons.Rounded.Mic, "Registra", Palette.Blue, Palette.Text) { s.start() }
        Phase.RECORDING -> RoundButton(Icons.Rounded.Check, "Ferma e trascrivi", Palette.Red, Palette.Text) {
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
        Phase.PROCESSING -> CircularProgressIndicator(Modifier.size(30.dp), color = Palette.Blue, strokeWidth = 2.5.dp)
    }
}

@Composable
private fun CopyLast(s: Session) {
    var done by remember { mutableStateOf(false) }
    LaunchedEffect(done) {
        if (done) {
            kotlinx.coroutines.delay(1400)
            done = false
        }
    }
    Row(
        Modifier
            .height(32.dp)
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClickLabel = "Copia l'ultima trascrizione") {
                s.copyLast()
                done = true
            }
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            if (done) Icons.Rounded.Check else Icons.Rounded.ContentCopy, null,
            tint = if (done) Palette.Green else Palette.Muted, modifier = Modifier.size(15.dp),
        )
        Spacer(Modifier.width(6.dp))
        Text(
            if (done) "Copiata" else "Copia ultima",
            style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = if (done) Palette.Green else Palette.Muted),
        )
    }
}

/** Un bottone secondario: un cerchio vero, appena visibile, così si capisce che si tocca. */
@Composable
private fun CircleButton(icon: ImageVector, label: String, tint: Color, small: Boolean = false, onClick: () -> Unit) {
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
            style = TextStyle(
                color = if (s.paused) Palette.Paused else Palette.Text,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
            ),
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
            .clip(RoundedCornerShape(17.dp))
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
                .background(Palette.Blue.copy(alpha = 0.9f), RoundedCornerShape(14.dp))
        )
        Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
            modes.forEachIndexed { i, (_, label) ->
                Text(
                    label,
                    modifier = Modifier.weight(1f).padding(horizontal = 2.dp),
                    textAlign = TextAlign.Center,
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (i == selected) Palette.Text else Palette.Muted,
                    ),
                )
            }
        }
    }
}

/** L'onda della voce: tratti verticali quando parli, puntini quando taci. In pausa è gialla e ferma. */
@Composable
private fun Wave(s: Session, modifier: Modifier) {
    val color = if (s.paused) Palette.Paused else Palette.Text
    androidx.compose.foundation.Canvas(modifier) {
        val n = s.levels.size
        val gap = size.width / n
        val bar = gap * 0.55f
        for (i in 0 until n) {
            val v = s.levels[i]
            val x = gap * (i + 0.5f)
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
    val small = TextStyle(color = Palette.Text, fontSize = 11.sp, lineHeight = 14.sp, textAlign = TextAlign.Center)
    s.notice?.let {
        Text(it, style = small.copy(color = Palette.Muted))
        return
    }
    when (s.phase) {
        Phase.RECORDING -> Wave(s, Modifier.fillMaxWidth().padding(horizontal = 18.dp).height(26.dp))
        Phase.PROCESSING -> Text("Trascrivo…", style = small)
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
private fun RoundButton(icon: ImageVector, label: String, bg: Color, fg: Color, onClick: () -> Unit) {
    Box(
        Modifier
            .size(52.dp)
            .clip(CircleShape)
            .background(bg)
            .clickable(onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = fg, modifier = Modifier.size(26.dp)) }
}

/** Area di tocco fissa da 44 dp, risposta al tocco rotonda: l'icona non si sposta mai. */
@Composable
private fun SmallButton(icon: ImageVector, label: String, tint: Color, onClick: () -> Unit) {
    Box(
        Modifier
            .size(36.dp)
            .clip(CircleShape)
            .clickable(onClickLabel = label, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, label, tint = tint, modifier = Modifier.size(20.dp)) }
}

/** Durata del ritorno: l'app aspetta questo tempo prima di riattaccare la bolla al bottone. */
const val OUTRO_MS = 640

/** Durata del volo d'ingresso, prima dell'atterraggio. */
const val INTRO_MS = 700

private fun easeOut(x: Float) = 1f - (1f - x) * (1f - x)
private fun easeIn(x: Float) = x * x
private fun smooth(x: Float) = x * x * (3f - 2f * x)
private fun lerpRect(a: Rect, b: Rect, t: Float) =
    Rect(lerp(a.left, b.left, t), lerp(a.top, b.top, t), lerp(a.right, b.right, t), lerp(a.bottom, b.bottom, t))
