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
import androidx.compose.runtime.snapshotFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
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

    /**
     * In pausa da più di [Durate.PAUSA_SI_APRE]: il registratore si chiude (il pezzo fin qui si può leggere) e
     * [bozza] diventa il testo di quello che hai detto, chiesto una volta sola per pausa. Senza rete resta null.
     */
    var pausaLunga by mutableStateOf(false); private set
    var bozza by mutableStateOf<String?>(null); private set
    private val bozze = Bozza(::trascriviPezzo)
    private val spezzoni = mutableListOf<File>()
    private var pausaJob: Job? = null
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

    /** Quando è arrivato l'ultimo campione: l'onda scorre in modo continuo fino al prossimo. */
    var sampledAt = 0L
    var hasLast by mutableStateOf(store.history().isNotEmpty()); private set

    /** Il vocale a cui stai rispondendo, se la sua carta è aperta nel Floater (lo dice il servizio). */
    var contestoRisposta: () -> String? = { null }

    /** Il testo dell'ultima trascrizione, per la carta del Floater. */
    fun lastText(): String? = store.history().firstOrNull()?.text

    /** Registrazioni che aspettano la rete (o un nuovo tentativo). */
    val queue = Queue(context)
    val transcriber = Transcriber(context, store, queue)
    var waiting by androidx.compose.runtime.mutableIntStateOf(queue.all().size); private set
    private var flushing = false

    /** La trascrizione a cui si attacca quello che stai dettando, se l'hai aperta con «Aggiungi a voce». */
    var appendingTo by mutableStateOf<Long?>(null); private set

    /** Dov'era il cursore in quella trascrizione: lì finisce il testo. -1 = in fondo. */
    private var appendCursor = -1

    /** Sta lavorando sugli audio condivisi: chi spegne il servizio aspetta anche loro. */
    private var draining by mutableStateOf(false)

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
    private val recording get() = File(Sandbox.dir(context), "recording.m4a")

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

    fun start(appendTo: Long? = null, cursor: Int = -1) {
        if (phase == Phase.RECORDING || phase == Phase.PROCESSING) return
        appendingTo = appendTo
        appendCursor = cursor
        refreshLimits()
        if (phase == Phase.LIMITED) return
        if (Simulated.noMic || context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            return fail("Microfono non consentito", Fix.SETTINGS)
        }
        try {
            recording.delete()
            buttaSpezzoni()
            // Chiede il focus audio: musica e vocali in riproduzione si fermano
            // e non finiscono nella trascrizione.
            audio.requestAudioFocus(focus)
            recorder = nuovoRegistratore()
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
                    sampledAt = System.nanoTime()
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

    /** Il registratore, sempre uguale: all'inizio e quando riprendi dopo una pausa lunga (un pezzo nuovo). */
    private fun nuovoRegistratore() = MediaRecorder(context).apply {
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

    fun togglePause() {
        val r = recorder
        if (phase != Phase.RECORDING) return
        if (paused) {
            // Dopo una pausa lunga il registratore era chiuso: ne riparte uno, su un pezzo nuovo.
            if (r == null) recorder = runCatching { nuovoRegistratore() }.getOrElse { return fail("Il microfono non parte", Fix.NONE) }
            else r.resume()
            pausedMs += SystemClock.elapsedRealtime() - pausedAt
        } else {
            r?.pause()
            pausedAt = SystemClock.elapsedRealtime()
        }
        paused = !paused
        pausaJob?.cancel()
        pausaLunga = false
        bozza = null
        if (paused) pausaJob = scope.launch { aspettaPausa() }
    }

    /** Ferma da [Durate.PAUSA_SI_APRE]: si chiude il pezzo e si chiede cosa hai detto fin qui (una volta). */
    private suspend fun aspettaPausa() {
        delay(Durate.PAUSA_SI_APRE)
        if (!paused || phase != Phase.RECORDING) return
        chiudiPezzo()
        pausaLunga = true
        val pezzi = spezzoni.toList()
        val testo = withContext(Dispatchers.IO) { bozze.di(pezzi) }
        if (paused && pausaLunga) bozza = testo
    }

    /** Il registratore si chiude e il suo file diventa un pezzo; il focus audio resta (sei ancora in pausa). */
    private fun chiudiPezzo() {
        val r = recorder ?: return
        recorder = null
        val ok = runCatching { r.stop() }.isSuccess
        r.release()
        if (ok) aggiungiPezzo()
    }

    private fun aggiungiPezzo() {
        val pezzo = File(Sandbox.dir(context), "pezzo-${spezzoni.size}.m4a")
        if (recording.renameTo(pezzo)) spezzoni += pezzo
    }

    /** Un pezzo a Groq, solo il testo (niente pulizia, niente storia): per la bozza della pausa. */
    private fun trascriviPezzo(f: File): String? {
        val key = store.apiKey ?: return null
        return runCatching { Groq(key).transcribe(f, store.transcriptionModel) }.getOrNull()?.also { store.countUse(store.transcriptionModel) }
    }

    private fun buttaSpezzoni() {
        spezzoni.forEach { it.delete() }
        spezzoni.clear()
        bozze.svuota()
        pausaJob?.cancel()
        pausaLunga = false
        bozza = null
    }

    /**
     * La registrazione intera in [recording]: se una pausa lunga l'ha divisa, i pezzi si riuniscono. Se non ci si
     * riesce, i pezzi di prima vanno in coda da soli (l'audio non si perde) e resta l'ultimo.
     */
    private fun riunisci(): Boolean {
        if (spezzoni.isEmpty()) return true.also { buttaSpezzoni() }
        if (recording.exists() && recording.length() > 0) aggiungiPezzo()
        val tutti = spezzoni.toList()
        if (!Spezzoni.unisci(tutti, recording)) {
            recording.delete()
            tutti.dropLast(1).forEach { queue.add(it, 0, if (purify) mode else null) }
            tutti.last().renameTo(recording)
        }
        buttaSpezzoni()
        return recording.exists()
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
        finishRecording()?.let(::process)
    }

    /**
     * Transcri torna a casa mentre ascolta: quello che ha sentito non si butta, si manda come
     * sempre. Chi spegne il servizio aspetta [busy], così la trascrizione arriva e si copia.
     */
    fun wrapUp() = stopAndSend()

    /** Sta trascrivendo una registrazione appena fatta. */
    val busy get() = phase == Phase.PROCESSING || draining

    /**
     * Ferma il microfono e mette l'audio in coda, se c'è qualcosa da trascrivere.
     * Da qui in poi l'audio non si perde, anche se il servizio si spegne subito dopo.
     */
    private fun finishRecording(): Pending? {
        if (phase != Phase.RECORDING) return null
        ticker?.cancel()
        if (paused) {
            pausedMs += SystemClock.elapsedRealtime() - pausedAt
            paused = false
        }
        val duration = SystemClock.elapsedRealtime() - startedAt - pausedMs
        // Dopo una pausa lunga il registratore può essere già chiuso: l'audio sta nei pezzi.
        val chiuso = recorder == null && spezzoni.isNotEmpty()
        val fermato = stopRecorder()
        if (chiuso) audio.abandonAudioFocusRequest(focus)
        val ok = (fermato || chiuso) && riunisci()
        if (!ok || duration < 400) {
            // Tocco accidentale o niente audio: si torna pronti senza errori.
            recording.delete()
            refreshLimits()
            return null
        }
        // Silenzio, o una prova di un attimo: niente da trascrivere (e Whisper sul silenzio inventa frasi).
        if (voicedMs < MIN_VOICED_MS) {
            recording.delete()
            refreshLimits()
            say("Non ho sentito niente")
            return null
        }
        val item = queue.add(recording, duration / 1000, if (purify) mode else null, appendingTo, cursor = appendCursor, contesto = if (appendingTo == null) contestoRisposta() else null)
        waiting = queue.all().size
        onHistoryChanged()
        return item
    }

    /** Riprova l'ultima registrazione rimasta in coda. */
    fun retry() {
        val item = queue.all().lastOrNull() ?: return refreshLimits()
        process(item)
    }

    /**
     * Le registrazioni che si stanno trascrivendo in questo momento. Sono in coda (così non si
     * perdono), ma non sono "in attesa": l'app le mostra solo se il tentativo fallisce.
     */
    val working = java.util.Collections.synchronizedSet(mutableSetOf<String>())

    /** Trascrive una registrazione appena fatta: chi ha parlato aspetta, quindi si vede e si copia. */
    private fun process(item: Pending) {
        phase = Phase.PROCESSING
        error = null
        scope.launch { work(item) }
    }

    /** Il lavoro su un audio, fino alla fine. Dice se è andato a buon fine. */
    /** Trascrive [item] e aggiorna la coda; lo stato (phase) lo decide chi chiama. */
    private suspend fun esegui(item: Pending): Transcriber.Outcome {
        working.add(item.id)
        val outcome = withContext(Dispatchers.IO) { transcriber.run(item) }
        working.remove(item.id)
        waiting = queue.all().size
        onHistoryChanged()
        return outcome
    }

    private suspend fun work(item: Pending): Boolean {
        phase = Phase.PROCESSING
        error = null
        when (val outcome = esegui(item)) {
            is Transcriber.Outcome.Done -> {
                val t = outcome.result
                if (t == null) {
                    refreshLimits()
                    say("Non ho sentito niente")
                    return true
                }
                // Quello che detti lo incolli altrove; un audio condiviso lo vuoi leggere, e gli appunti non si toccano.
                if (item.origin != null) onShared(t, item.origin) else copy(t.text)
                if (item.origin?.toNote != true) hasLast = true
                phase = Phase.SUCCESS
                delay(1500)
                if (phase == Phase.SUCCESS) refreshLimits()
                return true
            }
            // Senza rete: l'audio è salvato, e si riprova quando si vuole.
            Transcriber.Outcome.Offline -> fail("Niente rete. L'audio è salvato", Fix.RETRY)
            is Transcriber.Outcome.Failed -> fail(outcome.message, Fix.RETRY)
        }
        return false
    }

    /**
     * Un audio condiviso mentre stai registrando (anche in pausa): si trascrive in sottofondo, senza toccare la tua
     * registrazione né lo stato di Transcri; quando è pronto arriva nella carta. Se fallisce resta in coda.
     */
    private suspend fun inSottofondo(item: Pending): Boolean {
        val outcome = esegui(item)
        if (outcome !is Transcriber.Outcome.Done) return false
        outcome.result?.let { onShared(it, item.origin!!) }
        return true
    }

    /**
     * Trascrive gli audio condivisi, uno alla volta: se stai registrando, in sottofondo (sua richiesta, 3 nov:
     * prima aspettavano che finissi). Se uno fallisce si ferma: restano in coda e l'app li mostra.
     */
    fun drainShared(onDone: () -> Unit) {
        if (draining) return
        draining = true
        scope.launch {
            while (true) {
                snapshotFlow { phase }.first { it != Phase.PROCESSING }
                val item = queue.all().firstOrNull { it.origin != null && it.id !in working } ?: break
                if (!(if (phase == Phase.RECORDING) inSottofondo(item) else work(item))) break
            }
            draining = false
            onDone()
        }
    }

    /** Un audio condiviso è pronto: chi vive nel servizio decide dove mostrarlo. */
    var onShared: (Transcription, Origin) -> Unit = ::notifyShared

    /** Senza il Floater (manca il permesso): la notifica si apre e si legge tutto. */
    fun notifyShared(t: Transcription, origin: Origin) {
        val nm = context.getSystemService(android.app.NotificationManager::class.java)
        nm.createNotificationChannel(
            android.app.NotificationChannel(SHARED_CHANNEL, "Audio condivisi", android.app.NotificationManager.IMPORTANCE_HIGH)
        )
        val open = android.app.PendingIntent.getActivity(
            context, 0, android.content.Intent(context, MainActivity::class.java), android.app.PendingIntent.FLAG_IMMUTABLE,
        )
        val from = Provenienza.titolo(context, origin)
        nm.notify(
            t.at.hashCode(),
            android.app.Notification.Builder(context, SHARED_CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_mic)
                .setContentTitle(from)
                .setContentText(t.text)
                .setLargeIcon(Provenienza.icona(context, origin.source))
                .setStyle(android.app.Notification.BigTextStyle().bigText(t.text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build(),
        )
    }

    /** Trascrive quello che è rimasto in coda, quando lo chiedi dall'app. Non tocca gli appunti. */
    fun flush() {
        if (flushing || phase == Phase.RECORDING || phase == Phase.PROCESSING) return
        if (queue.all().isEmpty()) return
        flushing = true
        scope.launch {
            var done = 0
            for (item in queue.all()) {
                if (item.id in working) continue
                working.add(item.id)
                val outcome = withContext(Dispatchers.IO) { transcriber.run(item) }
                working.remove(item.id)
                if (outcome is Transcriber.Outcome.Done) {
                    if (outcome.result != null) done++
                } else break
            }
            codaCambiata()
            flushing = false
            if (done > 0) {
                hasLast = true
                onHistoryChanged()
                say(if (done == 1) "Trascrizione pronta in Transcrify" else "$done trascrizioni pronte in Transcrify")
            }
        }
    }

    /**
     * La coda è cambiata (l'app ha buttato o trascritto quello che aspettava): si riconta e, se non resta
     * niente da riprovare, il giallo di «Riprova» se ne va subito, come quando lo tocchi a coda vuota.
     */
    fun codaCambiata() {
        waiting = queue.all().size
        if (phase == Phase.ERROR && fix == Fix.RETRY && waiting == 0) refreshLimits()
    }

    /** Il cestino: butta la registrazione in corso o, dopo un errore, quella che non è riuscita. */
    fun discard() {
        ticker?.cancel()
        if (phase == Phase.RECORDING) {
            if (recorder == null) audio.abandonAudioFocusRequest(focus)
            stopRecorder()
            recording.delete()
            buttaSpezzoni()
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
        lastText()?.let { copy(it) }
    }

    /**
     * Il servizio si spegne (per esempio «Richiama» nella notifica): se stava ascoltando, l'audio
     * resta in coda e l'app lo mostra "in attesa". Buttarlo è solo del cestino e della X.
     */
    fun release() {
        ticker?.cancel()
        if (finishRecording() == null) stopRecorder()
    }

    private fun copy(text: String) {
        if (Sandbox.on(context)) return
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
        private const val SHARED_CHANNEL = "audio_condivisi"

        /** Quanti tratti ha l'onda. */
        const val WAVE = 22

        /** Livello sopra cui è voce, e quanta voce serve perché valga la pena trascrivere. */
        private const val VOICE = 0.14f
        private const val MIN_VOICED_MS = 700L
    }
}
