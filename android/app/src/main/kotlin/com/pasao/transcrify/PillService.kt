package com.pasao.transcrify

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.animation.ValueAnimator
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.compose.runtime.snapshotFlow
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.roundToInt

/** Cosa c'è sopra lo schermo oltre alla pillola. */
sealed interface Stage {
    /**
     * Transcri esce di casa: [home] è la capsula nel bottone dell'app. La bolla parte con
     * la sua forma e il suo colore, si gonfia, diventa blu e vola al bordo.
     */
    data class Intro(val from: Offset, val home: Rect?) : Stage

    /** Il contrario: torna a casa, si rimpicciolisce nella capsula e il servizio si chiude. */
    data class Outro(val to: Offset, val home: Rect?, val toApp: Boolean = false) : Stage
    data object Menu : Stage

    /** Mentre si trascina: la X in basso che può inghiottire la pillola. */
    data object Dismiss : Stage


    /** I comandi del Floater con Transcri nel Dock: si aprono dal suo posto [nest], sopra l'app. */
    data class Panel(val nest: Rect) : Stage
}

/**
 * La pillola: un servizio in primo piano con due finestre sopra le altre app.
 * La finestra piccola è la pillola sul bordo; quella a schermo intero compare
 * solo per le animazioni, per il menu e per la X, e sparisce subito dopo.
 */
class PillService : Service(), LifecycleOwner, SavedStateRegistryOwner {
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedState = SavedStateRegistryController.create(this)
    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry get() = savedState.savedStateRegistry

    private val scope = MainScope()
    private val main = Handler(Looper.getMainLooper())

    /**
     * Transcri è appena arrivato a casa: la scena tiene fermo l'ultimo fotogramma ancora un
     * attimo mentre la casa vera (il nido nell'app, il widget) si riaccende sotto di lui.
     * Così il cambio avviene ad animazione finita, alla stessa misura, senza un istante vuoto.
     */
    var homecoming = false; private set
    /** Se stava trascrivendo finisce il lavoro (e copia) prima di spegnersi: la pillola è già sparita. */
    private val finish = Runnable {
        finishing = scope.launch {
            snapshotFlow { session.busy }.first { !it }
            // Nel Dock il verde di «fatto» si vede solo se il servizio resta acceso ancora un attimo.
            if (!out && session.phase == Phase.SUCCESS) delay(Durate.CONFERMA)
            stopSelf()
        }
    }
    private var finishing: Job? = null
    private lateinit var wm: WindowManager
    lateinit var store: Store; private set
    lateinit var session: Session; private set

    private var pillView: ComposeView? = null
    private var stageView: ComposeView? = null
    private lateinit var pillParams: WindowManager.LayoutParams

    var stage by mutableStateOf<Stage?>(null); private set
    var pillRight by mutableStateOf(true); private set

    /** La pillola è dentro il raggio della X: rilasciandola si chiude. */
    var dismissHot by mutableStateOf(false); private set

    /**
     * Dove sta Transcri mentre lo trascini (centro, px). La pillola è una finestra stretta e non può
     * cambiare forma: mentre la porti in giro diventa invisibile (ma sente ancora il dito) e lui lo
     * disegna la scena a schermo intero, dove può staccarsi dal bordo e adattarsi alla casa.
     */
    var dragPoint by mutableStateOf(Offset.Zero); private set

    /** Lo stai trascinando: è sveglio e tutto dentro lo schermo. */
    var carried by mutableStateOf(false); private set

    /** Quanto la pillola sta fuori dallo schermo mentre sbircia (px, verso il bordo). */
    var peekShift = 0f

    /** Cresce ogni volta che la pillola si posa sul bordo dopo un volo: lei riparte sveglia e poi si ritira. */
    var settle by mutableStateOf(0); private set

    /** Quanto è vicino alla casa mentre lo trascini: 0 lontano, 1 sopra. La casa si allarga di conseguenza. */
    var nearness by mutableStateOf(0f); private set

    /** La X sta inghiottendo la pillola. */
    var absorbing by mutableStateOf(false); private set

    /**
     * Dove si trova la bolla in volo, aggiornato a ogni fotogramma. Se un volo viene
     * interrotto (esci e subito richiami, o il contrario), il nuovo parte da qui e non
     * dal suo punto di partenza: è questo che rende l'animazione interrompibile.
     */
    var flight: Rect? = null

    private val density get() = resources.displayMetrics.density
    private val screen get() = wm.currentWindowMetrics.bounds
    /** Mentre registra l'area di tocco si allarga: fermarlo tenendolo premuto dev'essere facile. */
    private var wide = false
    private val touchW get() = ((if (wide) PillGeometry.TOUCH_W_RECORDING else PillGeometry.TOUCH_W) * density).roundToInt()

    /** Il dito è sopra e sta tenendo premuto: il segno si gonfia finché scatta. */
    var holding by mutableStateOf(false); private set
    private val touchH get() = (PillGeometry.TOUCH_H * density).roundToInt()

    override fun onBind(intent: Intent?): IBinder? = null


    override fun onCreate() {
        super.onCreate()
        savedState.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
        wm = getSystemService(WindowManager::class.java)
        store = Store(this)
        session = Session(this, store, scope).also {
            it.onHistoryChanged = { listener?.invoke() }
            it.onShared = { t, origin -> if (out) showMessage(t, origin) else it.notifyShared(t, origin) }
            it.contestoRisposta = ::contestoRisposta
        }
        pillRight = store.pillRight
        readAccent()
        instance = this

        scope.launch {
            snapshotFlow { session.phase == Phase.RECORDING }.collect { rec ->
                wide = rec
                pillView?.let { v ->
                    pillParams.width = touchW
                    pillParams.x = if (pillRight) screen.width() - touchW else 0
                    wm.updateViewLayout(v, pillParams)
                }
            }
        }
        // L'app disegna Transcri nel Dock che ascolta: le serve lo stato e il volume della voce.
        scope.launch {
            snapshotFlow { liveNow() }.collect { liveListener?.invoke(it) }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // «Chiudi» nella notifica: rientra come con la X, e se stava registrando manda quello che ha sentito.
        if (intent?.action == ACTION_STOP) {
            rientra()
            return START_NOT_STICKY
        }
        // Il tipo microfono senza il permesso farebbe chiudere l'app: per un audio condiviso non serve.
        val mic = checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED
        startForeground(
            NOTIFICATION_ID, notification(),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or (if (mic) ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0)
        )
        // Rilanciato mentre stava rientrando: resta acceso.
        main.removeCallbacks(finish)
        finishing?.cancel()
        when (intent?.action) {
            ACTION_LISTEN -> {
                listen(if (intent.hasExtra(EXTRA_APPEND)) intent.getLongExtra(EXTRA_APPEND, 0) else null, intent.getIntExtra(EXTRA_CURSOR, -1))
                intent.getFloatArrayExtra(EXTRA_PANEL)?.toRect()?.let(::openPanel)
                return START_NOT_STICKY
            }
            ACTION_SHARED -> {
                workShared()
                return START_NOT_STICKY
            }
        }
        homecoming = false
        if (pillView == null) addPill()
        // Il widget si svuota quando la bolla lo copre già.
        main.postDelayed({ TranscriWidget.refresh(this) }, 120)
        val x = intent?.getFloatExtra(EXTRA_X, -1f) ?: -1f
        val y = intent?.getFloatExtra(EXTRA_Y, -1f) ?: -1f
        if (x >= 0 && y >= 0) showStage(Stage.Intro(Offset(x, y), intent?.getFloatArrayExtra(EXTRA_HOME)?.toRect()))
        // Dal tasto che detta: lo stesso ascolto dell'app (e della pillola tenuta premuta), mentre esce.
        if (intent?.getBooleanExtra(EXTRA_RECORD, false) == true) listen(null, -1)
        listener?.invoke()
        // Niente riavvio automatico: Android non permette di riaprire il microfono da dietro le quinte.
        return START_NOT_STICKY
    }

    // --- Dentro l'app: Transcri ascolta senza uscire dal Dock ---

    /** Fuori dal Dock, con la sua pillola sul bordo. Dentro l'app il servizio può lavorare anche senza. */
    val out get() = pillView != null

    /** Quello che fa adesso, per l'app. */
    fun liveNow() = mapOf(
        "phase" to session.phase.name,
        "level" to (session.level * 50).roundToInt() / 50.0,
        "appendTo" to session.appendingTo,
        "error" to session.error,
        // Per i ComandiVoce nella barra della trascrizione: in pausa, e da quanti secondi ascolta.
        "paused" to session.paused,
        "seconds" to (session.elapsedMs / 1000).toInt(),
    )

    /** Ascolta: dal Dock, senza finestre sopra le altre app; se è già fuori, lo vedi sulla sua pillola. */
    private fun listen(appendTo: Long?, cursor: Int) {
        session.start(appendTo, cursor)
        if (!out && session.phase != Phase.RECORDING) rest()
    }

    /** Ferma e manda quello che ha sentito. Se era nel Dock, il servizio si spegne appena ha finito. */
    fun stopListening() {
        session.stopAndSend()
        if (!out) rest()
    }

    /** Mette in pausa o riprende l'ascolto (il tasto a destra dei ComandiVoce). */
    fun togglePause() = session.togglePause()

    /** Butta quello che ha sentito. */
    fun discardListening() {
        session.discard()
        if (!out) rest()
    }

    /**
     * L'app va via mentre Transcri ascolta: il microfono non si è mai fermato, e lui esce dal Dock
     * e vola al bordo col suo colore da ascolto. Da lì si continua come sempre.
     */
    fun appLeft(nest: Rect?) {
        if (out || session.phase != Phase.RECORDING || !Settings.canDrawOverlays(this)) return
        main.removeCallbacks(finish)
        finishing?.cancel()
        addPill()
        main.post { TranscriWidget.refresh(this) }
        showStage(Stage.Intro(nest?.center ?: dismissCenter(), nest))
        listener?.invoke()
    }

    /** Si spegne appena non ha più niente da fare. */
    private fun rest() {
        main.removeCallbacks(finish)
        main.post(finish)
    }

    /** Uscito apposta per un audio condiviso: finito il lavoro, se nessuno l'ha toccato, se ne torna a casa. */
    private var outForShared = false

    /**
     * La carta del Floater (B12, 2 nov notte): esce dalla fessura sopra il registratore. Mostra i vocali condivisi
     * ([vocale] il primo, [messages] gli altri, di fila) o, se non ce ne sono, l'ultima trascrizione.
     * Con la carta di un vocale aperta, quello che detti risponde a quel vocale: il pulitore lo riceve come contesto.
     */
    val messages = androidx.compose.runtime.mutableStateListOf<Pair<Transcription, Origin>>()
    var vocale by mutableStateOf<Pair<Transcription, Origin>?>(null); private set

    /** Quale carta è fuori (i cassetti la aprono, la scambiano, la chiudono); null: nessuna. */
    var carta by mutableStateOf<Carta?>(null)

    /** Tutti i vocali sulla carta, dal primo all'ultimo. */
    val vocali: List<Pair<Transcription, Origin>> get() = listOfNotNull(vocale) + messages

    /** Il vocale a cui stai rispondendo: c'è solo se la sua carta è aperta. */
    private fun contestoRisposta(): String? = if (carta == Carta.VOCALI) vocali.joinToString("\n\n") { it.first.text }.ifBlank { null } else null

    /** La X di un vocale: esce dalla carta (resta salvato dov'era). Finiti i vocali, la carta si richiude. */
    fun togliVocale(t: Transcription) {
        if (vocale?.first?.at == t.at) vocale = messages.removeFirstOrNull() else messages.removeAll { it.first.at == t.at }
        if (vocale == null && carta == Carta.VOCALI) carta = null
    }

    /** «Salva come nota»: i vocali sulla carta passano tra le note. Il titolo arriva appena è pronto. */
    fun vocaliInNote() {
        vocale = vocale?.let(::inNota)
        for (i in messages.indices) messages[i] = inNota(messages[i])
        listener?.invoke()
    }

    /** «Salva come nota» sulla carta dell'ultima trascrizione. */
    fun ultimaInNota() {
        val t = store.history().firstOrNull() ?: return
        inNota(t to Origin(t.source, toNote = false))
        listener?.invoke()
    }

    private fun inNota(v: Pair<Transcription, Origin>): Pair<Transcription, Origin> {
        val (t, origin) = v
        if (t.noteId != null) return v
        val id = "${t.at}-pensiero"
        store.removeFromHistory(t.at)
        store.saveNote(Note(id, "", t.text, t.at, t.at, origin.source))
        NoteTopicsWorker.get(this).request(id)
        scope.launch(kotlinx.coroutines.Dispatchers.IO) {
            val title = session.transcriber.titleFor(t.text)
            if (title.isNotEmpty()) store.notes().firstOrNull { it.id == id }?.let { store.saveNote(it.copy(title = title)) }
            listener?.invoke()
        }
        return t.copy(noteId = id) to origin.copy(toNote = true)
    }

    private fun showMessage(t: Transcription, origin: Origin) {
        if (vocale == null) vocale = t to origin else messages += t to origin
        // Mentre registri non apre la carta da sola: diventerebbe il contesto di quello che stai già dicendo.
        if (session.phase != Phase.RECORDING) carta = Carta.VOCALI
        if (stage == null) showStage(Stage.Menu)
    }

    /** Se è uscito solo per gli audio condivisi, e li hai letti tutti, torna a casa. */
    private fun goHomeIfDone() {
        // Con un vocale nel pannello resta fuori: aspetta che lo riapri.
        if (!outForShared || !out || stage != null || vocale != null || session.busy) return
        if (session.phase == Phase.ERROR || session.phase == Phase.RECORDING) return
        outForShared = false
        showStage(Stage.Outro(dismissCenter(), null))
    }

    private fun workShared() {
        if (!out && Settings.canDrawOverlays(this)) {
            homecoming = false
            addPill()
            outForShared = true
            main.post { TranscriWidget.refresh(this) }
            showStage(Stage.Intro(dismissCenter(), null))
        }
        session.drainShared { if (out) goHomeIfDone() else rest() }
    }

    override fun onDestroy() {
        liveListener?.invoke(mapOf("phase" to Phase.IDLE.name, "level" to 0.0, "appendTo" to null, "error" to null, "paused" to false, "seconds" to 0))
        main.removeCallbacks(finish)
        val refreshed = homecoming
        session.release()
        stageView?.let { wm.removeView(it) }
        pillView?.let { wm.removeView(it) }
        stageView = null
        pillView = null
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        scope.cancel()
        instance = null
        // Se è rientrato da sé il widget è già stato ridisegnato: rifarlo lo farebbe lampeggiare.
        if (!refreshed) {
            listener?.invoke()
            TranscriWidget.refresh(this)
        }
        super.onDestroy()
    }

    /** Lo schermo ruota: la pillola resta sul suo bordo, alla stessa altezza in proporzione. */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (stage == Stage.Menu || stage == Stage.Dismiss || stage is Stage.Panel) removeStage()
        readAccent()
        placePill()
    }

    /**
     * I colori della pillola vengono dalla fonte unica dei token (Token.kt), come l'app e il widget:
     * Transcri coi suoi due toni, il pannello scuro «floater», gli stati del design system.
     */
    private fun readAccent() {
        // Il Floater è sempre scuro: i token del tema scuro (vedi Palette).
        Palette.token = Token.dal(Seme.di(this), scuro = true)
        Opacita.di(store).applica()
    }

    // --- Geometria, in pixel dello schermo ---

    /** Il rettangolo del segno visibile della pillola. */
    fun barRect(): Rect {
        val w = PillGeometry.BAR_W * density
        val h = PillGeometry.BAR_H * density
        val inset = PillGeometry.BAR_INSET * density
        val left = (if (pillRight) pillParams.x + touchW - inset - w else pillParams.x + inset) + peekShift
        val top = pillParams.y + (touchH - h) / 2f
        return Rect(left, top, left + w, top + h)
    }

    /** Centro della casa in cui rientra: il nido dell'app se è aperta, se no quella che compare in basso. */
    fun dismissCenter(): Offset {
        appNest?.let { return it.center }
        val b = screen
        return Offset(b.width() / 2f, b.height() - PillGeometry.DISMISS_BOTTOM * density)
    }

    // --- Finestre ---

    private fun overlayParams(w: Int, h: Int) = WindowManager.LayoutParams(
        w, h,
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
    }

    private fun composeView(content: @androidx.compose.runtime.Composable () -> Unit) = ComposeView(this).apply {
        setViewTreeLifecycleOwner(this@PillService)
        setViewTreeSavedStateRegistryOwner(this@PillService)
        setContent(content)
    }

    private fun placePill() {
        val view = pillView ?: return
        val b = screen
        pillParams.x = if (pillRight) b.width() - touchW else 0
        pillParams.y = (store.pillY * b.height() - touchH / 2f).roundToInt().coerceIn(0, b.height() - touchH)
        wm.updateViewLayout(view, pillParams)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun addPill() {
        pillParams = overlayParams(touchW, touchH)
        val view = composeView { PillBar(this) }
        // Il trascinamento usa le coordinate dello schermo: la finestra si muove
        // sotto il dito, quindi quelle locali non sarebbero affidabili.
        // Soglia più larga del normale: tenendolo premuto il dito trema, e non deve diventare un trascinamento.
        // Soglia più larga del normale: tenendolo premuto il dito trema, e non deve diventare un trascinamento.
        val slop = ViewConfiguration.get(this).scaledTouchSlop * 2 * 2
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        var held = false
        // Tenendola premuta senza muoverla: detta subito, o si ferma e trascrive.
        val hold = Runnable {
            held = true
            holding = false
            view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            session.quick()
        }
        view.setOnTouchListener { v, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY
                    startX = pillParams.x; startY = pillParams.y
                    dragging = false
                    held = false
                    holding = true
                    v.postDelayed(hold, HOLD_MS)
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && !held && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        carried = true
                        holding = false
                        nearness = 0f
                        v.removeCallbacks(hold)
                        dragPoint = Offset(pillParams.x + touchW / 2f, pillParams.y + touchH / 2f)
                        flight = null
                        showStage(Stage.Dismiss)
                        // La scena ha bisogno di un paio di fotogrammi per comparire: la pillola sparisce
                        // solo quando lui è già disegnato lì, così non c'è un istante vuoto.
                        v.postDelayed({ if (carried) v.alpha = 0f }, 40)
                    }
                    if (dragging) dragTo(v, startX + dx, startY + dy, e.rawX, e.rawY)
                }
                MotionEvent.ACTION_UP -> {
                    holding = false
                    carried = false
                    when {
                        held -> Unit
                        !dragging -> {
                            v.removeCallbacks(hold)
                            expand()
                        }
                        dismissHot && appNest != null -> homeToApp()
                        dismissHot -> absorb()
                        else -> {
                            flight = null
                            v.alpha = 1f
                            removeStage()
                            snapToEdge()
                        }
                    }
                }
                MotionEvent.ACTION_CANCEL -> if (dragging || held || holding) {
                    holding = false
                    carried = false
                    v.removeCallbacks(hold)
                    setHot(v, false)
                    flight = null
                    v.alpha = 1f
                    removeStage()
                    snapToEdge()
                }
            }
            true
        }
        // Quando dorme se ne vede solo un pezzetto attaccato al bordo, proprio dove Android ascolta
        // il gesto "indietro": senza questo la pressione lunga se la prenderebbe il sistema.
        // Si esclude solo il tratto di bordo occupato dalla pillola (Android ne concede al massimo 200 dp).
        view.addOnLayoutChangeListener { v, _, _, _, _, _, _, _, _ ->
            v.systemGestureExclusionRects = listOf(android.graphics.Rect(0, 0, v.width, v.height))
        }
        wm.addView(view, pillParams)
        pillView = view
        placePill()
    }

    /** Segue il dito; vicino alla X la pillola viene attratta al centro. */
    private fun dragTo(v: View, x: Float, y: Float, fingerX: Float, fingerY: Float) {
        val target = dismissCenter()
        val distance = hypot(fingerX - target.x, fingerY - target.y)
        val magnet = PillGeometry.DISMISS_MAGNET * density
        nearness = (1f - (distance - magnet) / (magnet * 3f)).coerceIn(0f, 1f)
        val near = distance < magnet
        if (near != dismissHot) setHot(v, near)
        if (near) {
            pillParams.x = (target.x - touchW / 2f).roundToInt()
            pillParams.y = (target.y - touchH / 2f).roundToInt()
        } else {
            pillParams.x = x.roundToInt()
            pillParams.y = y.roundToInt().coerceIn(0, screen.height() - touchH)
        }
        wm.updateViewLayout(v, pillParams)
        dragPoint = Offset(pillParams.x + touchW / 2f, pillParams.y + touchH / 2f)
    }

    /** Dopo il trascinamento la pillola torna al bordo più vicino con una molla: lo supera appena e rientra. */
    private fun snapToEdge() {
        val view = pillView ?: return
        val width = screen.width()
        val right = pillParams.x + touchW / 2 > width / 2
        pillRight = right
        val target = if (right) width - touchW else 0
        ValueAnimator.ofInt(pillParams.x, target).apply {
            duration = 420
            interpolator = OvershootInterpolator(1.6f)
            addUpdateListener {
                if (pillView != null) {
                    pillParams.x = it.animatedValue as Int
                    wm.updateViewLayout(view, pillParams)
                }
            }
            start()
        }
        store.pillRight = right
        store.pillY = (pillParams.y + touchH / 2f) / screen.height()
    }

    private fun setHot(v: View, hot: Boolean) {
        if (hot == dismissHot) return
        dismissHot = hot
        v.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
        // Con l'app aperta la casa è il nido dell'app: è lui che si accende.
        if (appNest != null) hotListener?.invoke(hot)
    }

    /** Rilasciato sopra il nido dell'app: ci rientra come quando lo richiami da lì. */
    private fun homeToApp() {
        val nest = appNest ?: return absorb()
        pillView?.let { setHot(it, false) }
        showStage(Stage.Outro(nest.center, nest, toApp = true))
    }

    /** Rilasciata sulla X: la scena la inghiotte, poi tutto si chiude. */
    private fun absorb() {
        setPillVisible(false)
        absorbing = true
    }

    private fun setPillVisible(visible: Boolean) {
        pillView?.visibility = if (visible) View.VISIBLE else View.INVISIBLE
        if (visible && !carried) pillView?.alpha = 1f
    }

    private fun showStage(s: Stage) {
        removeStage()
        stage = s
        val params = overlayParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        // Animazioni e X non prendono tocchi: passano alla pillola o all'app sotto.
        if (s !is Stage.Menu && s !is Stage.Panel) params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        val view = composeView { StageLayer(this) }
        wm.addView(view, params)
        stageView = view
        setPillVisible(s is Stage.Dismiss)
    }

    private fun removeStage() {
        stageView?.let { wm.removeView(it) }
        stageView = null
        stage = null
    }

    /** Chiamato dalla scena quando la sua animazione è finita. */
    fun stageDone() {
        flight = null
        when (val s = stage) {
            is Stage.Outro -> {
                if (s.toApp && session.phase == Phase.RECORDING) return backInDock()
                return arrived(if (s.toApp) APP_HANDOFF_MS else WIDGET_HANDOFF_MS)
            }
            Stage.Dismiss -> if (absorbing) return arrived(0)
            else -> Unit
        }
        settle++
        // Prima la pillola ferma, poi (un paio di fotogrammi dopo) via la scena: così non c'è un istante vuoto.
        setPillVisible(true)
        val leaving = stageView
        stageView = null
        stage = null
        leaving?.postDelayed({ runCatching { wm.removeView(leaving) } }, 48)
        when {
            // Il pannello nel Dock si chiude, e non c'è più niente in corso: il servizio può spegnersi.
            !out -> if (session.phase != Phase.RECORDING) rest()
            else -> goHomeIfDone()
        }
    }

    /** Apre il player (ferma, butta, pausa, modi) vicino a [nest], dov'è il tasto toccato. Se è fuori, dalla pillola. */
    fun openPanel(nest: Rect) {
        when {
            out -> expand()
            stage == null && Settings.canDrawOverlays(this) -> showStage(Stage.Panel(nest))
        }
    }

    /**
     * È tornato nel Dock mentre ascoltava: non si ferma, continua da lì. Le finestre sopra le altre
     * app non servono più; il microfono resta acceso, e per finire basta toccarlo.
     */
    private fun backInDock() {
        val leaving = stageView
        stageView = null
        stage = null
        leaving?.postDelayed({ runCatching { wm.removeView(leaving) } }, APP_HANDOFF_MS)
        pillView?.let { wm.removeView(it) }
        pillView = null
        dismissHot = false
        nearness = 0f
        TranscriWidget.refresh(this)
        listener?.invoke()
    }

    /**
     * È a casa: la casa vera si riaccende sotto l'ultimo fotogramma (fermo, stessa misura),
     * poi la scena se ne va dopo [handoff] ms. Il widget si ridisegna una volta sola, qui.
     */
    private fun arrived(handoff: Long) {
        // Se stava ascoltando, quello che ha sentito si trascrive e si copia: tornare a casa non butta niente.
        session.wrapUp()
        homecoming = true
        TranscriWidget.refresh(this)
        listener?.invoke()
        main.postDelayed(finish, handoff)
    }

    fun expand() {
        if (stage == null) showStage(Stage.Menu)
    }

    /** Dal bottone dell'app: la pillola rientra volando nel punto [to]. */
    fun recall(to: Offset, home: Rect?, toApp: Boolean = false) = showStage(Stage.Outro(to, home, toApp))

    /**
     * Torna a casa senza sapere dove (un tocco sul widget senza la sua posizione, «Chiudi» nella notifica):
     * se è fuori rientra nella casa in basso, se è nel Dock si ferma. In tutti e due i casi quello che stava
     * registrando, anche in pausa, si trascrive e si copia come quando lo fermi tu: non si butta e non resta in attesa.
     */
    fun rientra() = if (out) recall(dismissCenter(), null) else stopListening()

    fun openAppSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        session.clearError()
    }

    // --- Notifica: una sola, con il modo di chiudere ---

    private fun notification(): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        nm.deleteNotificationChannel("pill") // il canale vecchio, più rumoroso
        nm.createNotificationChannel(
            // Minima: Android la impone a chi usa il microfono, ma può stare in fondo e in silenzio.
            NotificationChannel(CHANNEL, "Pillola", NotificationManager.IMPORTANCE_MIN).apply {
                setShowBadge(false)
            }
        )
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, PillService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_mic)
            .setContentTitle("Transcrify")
            .setContentText("Per farlo rientrare, trascinalo nella sua casa in basso")
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Chiudi", stop).build())
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL = "pill_quiet"
        const val HOLD_MS = 520L
        /** La bolla è già sparita nella casa: la scena resta solo il tempo che la casa lo faccia rispuntare. */
        private const val APP_HANDOFF_MS = 60L
        private const val WIDGET_HANDOFF_MS = 60L
        private const val NOTIFICATION_ID = 7
        private const val ACTION_STOP = "stop"
        private const val ACTION_LISTEN = "listen"
        private const val ACTION_SHARED = "shared"
        private const val EXTRA_APPEND = "append"
        private const val EXTRA_CURSOR = "cursor"
        private const val EXTRA_PANEL = "panel"
        private const val EXTRA_X = "x"
        private const val EXTRA_Y = "y"
        private const val EXTRA_HOME = "home"
        /** Esce già in ascolto: lo passa anche il tasto che detta del widget al suo trampolino. */
        const val EXTRA_RECORD = "record"

        var instance: PillService? = null; private set
        /** Fuori casa: acceso e non sta già rientrando. */
        val running get() = instance?.let { !it.homecoming && it.out } == true

        /** Avvisato quando cambia quello che Transcri sta facendo: stato e volume, per il Dock. */
        var liveListener: ((Map<String, Any?>) -> Unit)? = null


        /** Comincia ad ascoltare con l'app aperta: è qui che Android concede il microfono anche per dopo. */
        fun listen(context: Context, appendTo: Long?, cursor: Int, panel: FloatArray?) {
            context.startForegroundService(
                Intent(context, PillService::class.java).setAction(ACTION_LISTEN).putExtra(EXTRA_CURSOR, cursor).apply {
                    appendTo?.let { putExtra(EXTRA_APPEND, it) }
                    panel?.let { putExtra(EXTRA_PANEL, it) }
                }
            )
        }

        /** Ci sono audio condivisi in coda: Transcri esce a lavorarci. */
        fun workShared(context: Context) {
            context.startForegroundService(Intent(context, PillService::class.java).setAction(ACTION_SHARED))
        }

        /** Avvisato quando la pillola si accende, si spegne o salva una trascrizione. */
        var listener: (() -> Unit)? = null

        /** Il nido di Transcri nell'app, in pixel dello schermo, finché l'app è aperta e lo mostra. */
        var appNest: Rect? = null

        /** Avvisato quando, trascinandolo, Transcri arriva sopra il nido dell'app (o se ne allontana). */
        var hotListener: ((Boolean) -> Unit)? = null

        /**
         * [x], [y]: punto dello schermo (px) da cui esce la bolla; [home]: la capsula di casa nel bottone (l, t, r, b).
         * [record]: esce già in ascolto (il tasto che detta del widget 4 × 1).
         */
        fun start(context: Context, x: Float, y: Float, home: FloatArray?, record: Boolean = false) {
            context.startForegroundService(
                Intent(context, PillService::class.java).putExtra(EXTRA_X, x).putExtra(EXTRA_Y, y)
                    .putExtra(EXTRA_HOME, home).putExtra(EXTRA_RECORD, record)
            )
        }

        fun FloatArray.toRect(): Rect? = if (size == 4) Rect(this[0], this[1], this[2], this[3]) else null

        fun stop(context: Context) {
            context.stopService(Intent(context, PillService::class.java))
        }
    }
}

/** Le carte che escono sopra il registratore del Floater. */
enum class Carta { VOCALI, ULTIMA }
