package com.pasao.transcrify

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.SystemClock
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

enum class Phase { IDLE, RECORDING, PROCESSING, SUCCESS, ERROR, LIMITED }

/** Cosa serve per uscire da un errore: cambia il bottone principale. */
enum class Fix { RETRY, SETTINGS, NONE }

/**
 * Registra, trascrive, pulisce, copia. Lo stato è osservabile da Compose.
 * Vive nel servizio, quindi sopravvive alla pillola che si apre e si chiude.
 */
class Session(private val context: Context, private val store: Store, private val scope: CoroutineScope) {
    var phase by mutableStateOf(Phase.IDLE); private set

    /** Registrazione in pausa: il tempo si ferma, il microfono anche. */
    var paused by mutableStateOf(false); private set
    var fix by mutableStateOf(Fix.NONE); private set
    var error by mutableStateOf<String?>(null); private set
    var elapsedMs by mutableLongStateOf(0); private set
    var sizeMb by mutableFloatStateOf(0f); private set
    var purify by mutableStateOf(store.purify); private set

    /** Il modo di pulizia: "fedele", "pulita" o "riassunto". */
    var mode by mutableStateOf(store.cleanMode); private set

    /** Un avviso breve al posto dello stato, per esempio "Non ho sentito niente". */
    var notice by mutableStateOf<String?>(null); private set

    /** Quanto si è parlato davvero (ms sopra la soglia della voce). */
    private var voicedMs = 0L

    /** Volume della voce adesso (0–1) e gli ultimi valori, per disegnare l'onda. */
    var level by mutableFloatStateOf(0f); private set
    val levels = androidx.compose.runtime.mutableStateListOf<Float>().apply { repeat(WAVE) { add(0f) } }
    var hasLast by mutableStateOf(store.history().isNotEmpty()); private set

    /** Registrazioni che aspettano la rete (o un nuovo tentativo). */
    val queue = Queue(context)
    private val transcriber = Transcriber(store, queue)
    var waiting by androidx.compose.runtime.mutableIntStateOf(queue.all().size); private set
    private var flushing = false

    /** Avvisato a ogni nuova trascrizione (per aggiornare l'app se è aperta). */
    var onHistoryChanged: () -> Unit = {}

    private var recorder: MediaRecorder? = null
    private var startedAt = 0L
    private var pausedAt = 0L
    private var pausedMs = 0L
    private val audio = context.getSystemService(android.media.AudioManager::class.java)
    private val focus = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
        .setAudioAttributes(
            android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_ASSISTANT)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
        )
        .build()
    private var ticker: Job? = null
    // Nei file dell'app, non nella cache: Android non la cancella mentre aspetta.
    private val recording get() = File(context.filesDir, "recording.m4a")

    init {
        // L'audio da riprovare della versione di prima entra nella coda.
        store.retryFile?.let { path ->
            File(path).takeIf { it.exists() }?.let { queue.add(it, 0, if (store.purify) store.cleanMode else null) }
            store.retryFile = null
        }
        waiting = queue.all().size
        refreshLimits()
    }

    /** "tornano alle 14:32" */
    val limitText: String
        get() = store.resetAt()?.let {
            "tornano alle " + java.text.SimpleDateFormat("HH:mm", java.util.Locale.ITALY).format(java.util.Date(it))
        } ?: ""

    private fun refreshLimits() {
        phase = if (store.checkLimits() == Limit.OK) Phase.IDLE else Phase.LIMITED
        error = null
        fix = Fix.NONE
    }

    fun togglePurify() {
        purify = !purify
        store.purify = purify
    }

    /** Dal selettore di Transcri: un modo lo accende; ritoccare quello acceso spegne la pulizia. */
    fun pickMode(m: String) {
        if (purify && mode == m) setMode(m, on = false) else setMode(m, on = true)
    }

    private fun setMode(m: String, on: Boolean) {
        mode = m
        store.cleanMode = m
        purify = on
        store.purify = on
    }

    /** L'app ha cambiato qualcosa nelle impostazioni: si rilegge. */
    fun reloadSettings() {
        mode = store.cleanMode
        purify = store.purify
    }

    fun start() {
        if (phase == Phase.RECORDING || phase == Phase.PROCESSING) return
        refreshLimits()
        if (phase == Phase.LIMITED) return
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return fail("Microfono non consentito", Fix.SETTINGS)
        }
        try {
            recording.delete()
            // Chiede il focus audio: musica e vocali in riproduzione si fermano
            // e non finiscono nella trascrizione.
            audio.requestAudioFocus(focus)
            recorder = MediaRecorder(context).apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16_000)
                setAudioChannels(1)
                setAudioEncodingBitRate(32_000)
                setOutputFile(recording.absolutePath)
                prepare()
                start()
            }
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
            audio.abandonAudioFocusRequest(focus)
            return fail("Il microfono non parte", Fix.NONE)
        }
        startedAt = SystemClock.elapsedRealtime()
        voicedMs = 0
        notice = null
        pausedMs = 0
        paused = false
        elapsedMs = 0
        sizeMb = 0f
        phase = Phase.RECORDING
        ticker = scope.launch {
            var tick = 0
            while (isActive && phase == Phase.RECORDING) {
                if (!paused) {
                    elapsedMs = SystemClock.elapsedRealtime() - startedAt - pausedMs
                    // getMaxAmplitude: il picco dall'ultima chiamata. La radice rende visibile anche la voce bassa.
                    val amp = runCatching { recorder?.maxAmplitude ?: 0 }.getOrDefault(0)
                    level = kotlin.math.sqrt(amp / 32767f).times(1.6f).coerceIn(0f, 1f)
                    if (level > VOICE) voicedMs += 70
                    levels.removeAt(0)
                    levels.add(level)
                }
                if (tick++ % 4 == 0) {
                    sizeMb = recording.length() / 1_048_576f
                    if (sizeMb >= MAX_MB) {
                        stopAndSend()
                        break
                    }
                }
                delay(70)
            }
            level = 0f
        }
    }

    fun togglePause() {
        val r = recorder ?: return
        if (phase != Phase.RECORDING) return
        if (paused) {
            r.resume()
            pausedMs += SystemClock.elapsedRealtime() - pausedAt
        } else {
            r.pause()
            pausedAt = SystemClock.elapsedRealtime()
        }
        paused = !paused
    }

    /** Dalla pillola chiusa, tenendola premuta: se è ferma detta, se detta si ferma e trascrive. */
    fun quick() {
        when (phase) {
            Phase.RECORDING -> stopAndSend()
            Phase.IDLE, Phase.SUCCESS, Phase.ERROR -> start()
            else -> Unit
        }
    }

    fun stopAndSend() {
        if (phase != Phase.RECORDING) return
        ticker?.cancel()
        if (paused) {
            pausedMs += SystemClock.elapsedRealtime() - pausedAt
            paused = false
        }
        val duration = SystemClock.elapsedRealtime() - startedAt - pausedMs
        val ok = stopRecorder()
        if (!ok || duration < 400) {
            // Tocco accidentale o niente audio: si torna pronti senza errori.
            recording.delete()
            refreshLimits()
            return
        }
        // Silenzio, o una prova di un attimo: niente da trascrivere (e Whisper sul silenzio inventa frasi).
        if (voicedMs < MIN_VOICED_MS) {
            recording.delete()
            refreshLimits()
            say("Non ho sentito niente")
            return
        }
        // Prima di tutto in coda: da qui in poi l'audio non si perde.
        val item = queue.add(recording, duration / 1000, if (purify) mode else null)
        waiting = queue.all().size
        onHistoryChanged()
        process(item)
    }

    /** Riprova l'ultima registrazione rimasta in coda. */
    fun retry() {
        val item = queue.all().lastOrNull() ?: return refreshLimits()
        process(item)
    }

    /** Trascrive una registrazione appena fatta: chi ha parlato aspetta, quindi si vede e si copia. */
    private fun process(item: Pending) {
        phase = Phase.PROCESSING
        error = null
        scope.launch {
            val outcome = withContext(Dispatchers.IO) { transcriber.run(item) }
            waiting = queue.all().size
            onHistoryChanged()
            when (outcome) {
                is Transcriber.Outcome.Done -> {
                    val t = outcome.result
                    if (t == null) {
                        refreshLimits()
                        say("Non ho sentito niente")
                        return@launch
                    }
                    copy(t.text)
                    hasLast = true
                    phase = Phase.SUCCESS
                    delay(1500)
                    if (phase == Phase.SUCCESS) refreshLimits()
                }
                // Senza rete: l'audio è salvato, e si riprova quando si vuole.
                Transcriber.Outcome.Offline -> fail("Niente rete. L'audio è salvato", Fix.RETRY)
                is Transcriber.Outcome.Failed -> fail(outcome.message, Fix.RETRY)
            }
        }
    }

    /** Trascrive quello che è rimasto in coda, quando lo chiedi dall'app. Non tocca gli appunti. */
    fun flush() {
        if (flushing || phase == Phase.RECORDING || phase == Phase.PROCESSING) return
        if (queue.all().isEmpty()) return
        flushing = true
        scope.launch {
            var done = 0
            for (item in queue.all()) {
                val outcome = withContext(Dispatchers.IO) { transcriber.run(item) }
                if (outcome is Transcriber.Outcome.Done) {
                    if (outcome.result != null) done++
                } else break
            }
            waiting = queue.all().size
            flushing = false
            if (done > 0) {
                hasLast = true
                onHistoryChanged()
                say(if (done == 1) "Trascrizione pronta in Transcrify" else "$done trascrizioni pronte in Transcrify")
            }
        }
    }

    /** Il cestino: butta la registrazione in corso o, dopo un errore, quella che non è riuscita. */
    fun discard() {
        ticker?.cancel()
        if (phase == Phase.RECORDING) {
            stopRecorder()
            recording.delete()
        } else if (phase == Phase.ERROR) {
            queue.all().lastOrNull()?.let { queue.remove(it.id) }
            waiting = queue.all().size
            onHistoryChanged()
        }
        elapsedMs = 0
        sizeMb = 0f
        refreshLimits()
    }

    fun clearError() = refreshLimits()

    private fun say(text: String) {
        notice = text
        scope.launch {
            delay(1800)
            if (notice == text) notice = null
        }
    }

    fun copyLast() {
        store.history().firstOrNull()?.let { copy(it.text) }
    }

    fun release() {
        ticker?.cancel()
        stopRecorder()
    }

    private fun copy(text: String) {
        val cm = context.getSystemService(ClipboardManager::class.java)
        cm.setPrimaryClip(ClipData.newPlainText("Transcrify", text))
    }

    private fun stopRecorder(): Boolean {
        val r = recorder ?: return false
        recorder = null
        paused = false
        audio.abandonAudioFocusRequest(focus)
        return try {
            r.stop()
            true
        } catch (e: RuntimeException) {
            false
        } finally {
            r.release()
        }
    }

    private fun fail(message: String, how: Fix) {
        error = message
        fix = how
        phase = Phase.ERROR
    }

    companion object {
        // Il piano gratuito di Groq accetta file fino a 25 MB: ci si ferma prima.
        private const val MAX_MB = 24f

        /** Quanti tratti ha l'onda. */
        const val WAVE = 22

        /** Livello sopra cui è voce, e quanta voce serve perché valga la pena trascrivere. */
        private const val VOICE = 0.14f
        private const val MIN_VOICED_MS = 700L
    }
}
