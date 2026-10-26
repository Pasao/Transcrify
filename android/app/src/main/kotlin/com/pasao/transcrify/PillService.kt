package com.pasao.transcrify

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.graphics.PixelFormat
import android.net.Uri
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
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
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
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
    data class Outro(val to: Offset, val home: Rect?) : Stage
    data object Menu : Stage

    /** Mentre si trascina: la X in basso che può inghiottire la pillola. */
    data object Dismiss : Stage
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
        session = Session(this, store, scope).also { it.onHistoryChanged = { listener?.invoke() } }
        pillRight = store.pillRight
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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(
            NOTIFICATION_ID, notification(),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        )
        if (pillView == null) addPill()
        TranscriWidget.refresh(this)
        val x = intent?.getFloatExtra(EXTRA_X, -1f) ?: -1f
        val y = intent?.getFloatExtra(EXTRA_Y, -1f) ?: -1f
        if (x >= 0 && y >= 0) showStage(Stage.Intro(Offset(x, y), intent?.getFloatArrayExtra(EXTRA_HOME)?.toRect()))
        listener?.invoke()
        // Niente riavvio automatico: Android non permette di riaprire il microfono da dietro le quinte.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        session.release()
        stageView?.let { wm.removeView(it) }
        pillView?.let { wm.removeView(it) }
        stageView = null
        pillView = null
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        scope.cancel()
        instance = null
        listener?.invoke()
        TranscriWidget.refresh(this)
        super.onDestroy()
    }

    /** Lo schermo ruota: la pillola resta sul suo bordo, alla stessa altezza in proporzione. */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (stage == Stage.Menu || stage == Stage.Dismiss) removeStage()
        placePill()
    }

    // --- Geometria, in pixel dello schermo ---

    /** Il rettangolo del segno visibile della pillola. */
    fun barRect(): Rect {
        val w = PillGeometry.BAR_W * density
        val h = PillGeometry.BAR_H * density
        val inset = PillGeometry.BAR_INSET * density
        val left = if (pillRight) pillParams.x + touchW - inset - w else pillParams.x + inset
        val top = pillParams.y + (touchH - h) / 2f
        return Rect(left, top, left + w, top + h)
    }

    /** Centro della X che chiude la pillola. */
    fun dismissCenter(): Offset {
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
                        holding = false
                        v.removeCallbacks(hold)
                        showStage(Stage.Dismiss)
                    }
                    if (dragging) dragTo(v, startX + dx, startY + dy, e.rawX, e.rawY)
                }
                MotionEvent.ACTION_UP -> {
                    holding = false
                    when {
                        held -> Unit
                        !dragging -> {
                            v.removeCallbacks(hold)
                            expand()
                        }
                        dismissHot -> absorb()
                        else -> {
                            removeStage()
                            snapToEdge()
                        }
                    }
                }
                MotionEvent.ACTION_CANCEL -> if (dragging || held || holding) {
                    holding = false
                    v.removeCallbacks(hold)
                    dismissHot = false
                    removeStage()
                    snapToEdge()
                }
            }
            true
        }
        wm.addView(view, pillParams)
        pillView = view
        placePill()
    }

    /** Segue il dito; vicino alla X la pillola viene attratta al centro. */
    private fun dragTo(v: View, x: Float, y: Float, fingerX: Float, fingerY: Float) {
        val target = dismissCenter()
        val near = hypot(fingerX - target.x, fingerY - target.y) < PillGeometry.DISMISS_MAGNET * density
        if (near != dismissHot) {
            dismissHot = near
            v.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
        }
        if (near) {
            pillParams.x = (target.x - touchW / 2f).roundToInt()
            pillParams.y = (target.y - touchH / 2f).roundToInt()
        } else {
            pillParams.x = x.roundToInt()
            pillParams.y = y.roundToInt().coerceIn(0, screen.height() - touchH)
        }
        wm.updateViewLayout(v, pillParams)
    }

    /** Dopo il trascinamento la pillola scivola sul bordo più vicino. */
    private fun snapToEdge() {
        val view = pillView ?: return
        val width = screen.width()
        val right = pillParams.x + touchW / 2 > width / 2
        pillRight = right
        val target = if (right) width - touchW else 0
        ValueAnimator.ofInt(pillParams.x, target).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
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

    /** Rilasciata sulla X: la scena la inghiotte, poi tutto si chiude. */
    private fun absorb() {
        setPillVisible(false)
        absorbing = true
    }

    private fun setPillVisible(visible: Boolean) {
        pillView?.visibility = if (visible) View.VISIBLE else View.INVISIBLE
    }

    private fun showStage(s: Stage) {
        removeStage()
        stage = s
        val params = overlayParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        // Animazioni e X non prendono tocchi: passano alla pillola o all'app sotto.
        if (s !is Stage.Menu) params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
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
        when (stage) {
            is Stage.Outro -> return stopSelf()
            Stage.Dismiss -> if (absorbing) return closeAll()
            else -> Unit
        }
        removeStage()
        setPillVisible(true)
    }

    fun expand() {
        if (stage == null) showStage(Stage.Menu)
    }

    /** Dal bottone dell'app: la pillola rientra volando nel punto [to]. */
    fun recall(to: Offset, home: Rect?) = showStage(Stage.Outro(to, home))

    /** La X: chiude la pillola e il servizio. */
    fun closeAll() {
        session.discard()
        stopSelf()
    }

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
            .setContentText("Trascina Transcri sulla X per chiuderlo")
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "Chiudi", stop).build())
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL = "pill_quiet"
        const val HOLD_MS = 520L
        private const val NOTIFICATION_ID = 7
        private const val ACTION_STOP = "stop"
        private const val EXTRA_X = "x"
        private const val EXTRA_Y = "y"
        private const val EXTRA_HOME = "home"

        var instance: PillService? = null; private set
        val running get() = instance != null

        /** Avvisato quando la pillola si accende, si spegne o salva una trascrizione. */
        var listener: (() -> Unit)? = null

        /** [x], [y]: punto dello schermo (px) da cui esce la bolla; [home]: la capsula di casa nel bottone (l, t, r, b). */
        fun start(context: Context, x: Float, y: Float, home: FloatArray?) {
            context.startForegroundService(
                Intent(context, PillService::class.java).putExtra(EXTRA_X, x).putExtra(EXTRA_Y, y)
                    .putExtra(EXTRA_HOME, home)
            )
        }

        fun FloatArray.toRect(): Rect? = if (size == 4) Rect(this[0], this[1], this[2], this[3]) else null

        fun stop(context: Context) {
            context.stopService(Intent(context, PillService::class.java))
        }
    }
}
