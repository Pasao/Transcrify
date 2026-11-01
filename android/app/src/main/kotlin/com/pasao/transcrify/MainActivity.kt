package com.pasao.transcrify

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

/**
 * Ponte tra l'interfaccia Flutter e il nucleo nativo (Store, Groq, pillola).
 * Flutter non tiene dati: chiede e scrive tutto qui.
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val main = Handler(Looper.getMainLooper())
    private val store get() = PillService.instance?.store ?: ownStore
    private val ownStore by lazy { Store(this) }
    private val queue get() = PillService.instance?.session?.queue ?: ownQueue
    private val ownQueue by lazy { Queue(this) }
    private val topicModels by lazy { TopicModels(this) }
    private val topics by lazy { NoteTopicsWorker.get(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "transcrify/core")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "state" -> result.success(state())
                "history" -> result.success(store.history().map { mapOf("text" to it.text, "at" to it.at, "purified" to it.purified, "mode" to it.mode, "source" to it.source) })
                // Quello che si sta trascrivendo adesso non è "in attesa": compare solo se fallisce.
                "pending" -> result.success(queue.all().filter { it.id !in (PillService.instance?.session?.working ?: emptySet()) }.map {
                    mapOf("id" to it.id, "at" to it.at, "seconds" to it.seconds, "mode" to it.mode)
                })
                "discardPending" -> {
                    queue.remove(call.argument<String>("id")!!)
                    result.success(null)
                }
                "flushPending" -> {
                    val session = PillService.instance?.session
                    if (session != null) {
                        session.flush()
                        result.success(null)
                    } else {
                        // Transcri è chiuso: ci pensa l'app, un audio alla volta.
                        background(result) {
                            val t = Transcriber(this, store, queue)
                            var done = 0
                            for (item in queue.all()) {
                                val o = t.run(item)
                                if (o is Transcriber.Outcome.Done) done++ else break
                            }
                            done
                        }
                    }
                }
                "deleteHistory" -> {
                    store.removeFromHistory(call.argument<Number>("at")!!.toLong())
                    result.success(null)
                }
                "setSandbox" -> {
                    // Tutto legge la cartella all'avvio: si chiude Transcri e si riparte da capo.
                    PillService.stop(this)
                    Sandbox.set(this, call.argument<Boolean>("on")!!)
                    packageManager.getLaunchIntentForPackage(packageName)?.let {
                        startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
                    }
                    android.os.Process.killProcess(android.os.Process.myPid())
                }
                "editHistory" -> {
                    store.editEntry(call.argument<Number>("at")!!.toLong(), call.argument<String>("text")!!)
                    result.success(null)
                }
                "listen" -> {
                    // Parte con l'app davanti: Android poi lascia il microfono acceso anche fuori.
                    PillService.listen(this, call.argument<Number>("appendTo")?.toLong())
                    result.success(null)
                }
                "stopListening" -> {
                    PillService.instance?.stopListening()
                    result.success(null)
                }
                "discardListening" -> {
                    PillService.instance?.discardListening()
                    result.success(null)
                }
                "summarize" -> {
                    val key = store.apiKey ?: return@setMethodCallHandler result.error("nokey", "Manca la chiave", null)
                    background(result) {
                        Groq(key).cleanLong(call.argument<String>("text")!!, store.cleanupModel, store.promptFor("riassunto"), store.words)
                            .also { store.countUse(store.cleanupModel) }
                    }
                }
                "introSeen" -> {
                    store.introSeen = true
                    result.success(null)
                }
                "topicModels" -> result.success(TopicModel.entries.map { m ->
                    val st = topicModels.status(m)
                    mapOf(
                        "id" to m.id, "label" to m.label, "name" to m.modelName, "approxMb" to m.approxMb,
                        "chosen" to (topicModels.chosen == m),
                        // Sotto i 6 GB il più preciso può essere lento: l'app lo dice sotto la scelta.
                        "ramGb" to topics.ramGb,
                        "state" to when (st) {
                            TopicModels.Status.Missing -> "missing"
                            is TopicModels.Status.Downloading -> "downloading"
                            TopicModels.Status.Ready -> "ready"
                            is TopicModels.Status.Failed -> "failed"
                        },
                        "done" to (st as? TopicModels.Status.Downloading)?.done,
                        "total" to (st as? TopicModels.Status.Downloading)?.total,
                        "error" to (st as? TopicModels.Status.Failed)?.reason,
                    )
                })
                "chooseTopicModel" -> {
                    // Sceglierlo vuol dire anche scaricarlo, se non c'è ancora. null = argomenti spenti.
                    val m = TopicModel.of(call.argument<String>("id"))
                    topicModels.chosen = m
                    if (m != null) topicModels.download(m)
                    topics.requestAll()
                    result.success(null)
                }
                "cancelTopicModel" -> {
                    TopicModel.of(call.argument<String>("id"))?.let(topicModels::cancel)
                    result.success(null)
                }
                "deleteTopicModel" -> {
                    TopicModel.of(call.argument<String>("id"))?.let(topicModels::delete)
                    result.success(null)
                }
                "notes" -> result.success(store.notes().map { it.toMap() + ("topics" to topics.state(it.id, it.text)) })
                "noteTopics" -> result.success(topics.topics(call.argument<String>("id")!!))
                "albums" -> result.success(topics.albums())
                "share" -> {
                    val send = android.content.Intent(android.content.Intent.ACTION_SEND)
                        .setType("text/plain")
                        .putExtra(android.content.Intent.EXTRA_TEXT, call.argument<String>("text")!!)
                    startActivity(android.content.Intent.createChooser(send, null))
                    result.success(null)
                }
                "saveNote" -> {
                    val id = call.argument<String>("id")!!
                    store.saveNote(
                        Note(
                            id, call.argument<String>("title") ?: "", call.argument<String>("text") ?: "",
                            call.argument<Number>("created")!!.toLong(), call.argument<Number>("updated")!!.toLong(),
                            call.argument<String>("source"), call.argument<String>("summary"),
                        )
                    )
                    // Il «commit»: salvata la nota, i suoi argomenti si rifanno in fondo (solo le frasi nuove).
                    topics.request(id)
                    result.success(null)
                }
                "deleteNote" -> {
                    store.deleteNote(call.argument<String>("id")!!)
                    topics.forget(call.argument<String>("id")!!)
                    result.success(null)
                }
                "checkKey" -> background(result) { Groq(call.argument<String>("key")!!.trim()).models().size }
                "setKey" -> {
                    store.apiKey = call.argument<String>("key")
                    result.success(null)
                }
                "deleteKey" -> {
                    PillService.stop(this)
                    store.apiKey = null
                    result.success(null)
                }
                "models" -> {
                    val key = store.apiKey ?: return@setMethodCallHandler result.error("nokey", "Manca la chiave", null)
                    // Dalla copia del giorno, se c'è: la rotella si apre subito.
                    store.modelsCache?.let { return@setMethodCallHandler result.success(modelsFrom(it)) }
                    background(result) {
                        val list = Groq(key).models()
                        val json = org.json.JSONArray(list.map {
                            org.json.JSONObject().put("id", it.id).put("owner", it.owner).put("context", it.context).put("speech", it.speech)
                        })
                        store.modelsCache = json.toString()
                        modelsFrom(json.toString())
                    }
                }
                "setMode" -> {
                    store.cleanMode = call.argument<String>("mode")!!
                    PillService.instance?.session?.reloadSettings()
                    result.success(null)
                }
                "simulate" -> {
                    Simulated.set(call.argument<String>("what")!!, call.argument<Boolean>("on")!!)
                    result.success(null)
                }
                "simulateLimit" -> {
                    store.simulateLimit = call.argument<Boolean>("on")!!
                    PillService.instance?.session?.clearError()
                    result.success(null)
                }
                "setModel" -> {
                    val id = call.argument<String>("id")!!
                    if (call.argument<Boolean>("speech") == true) store.transcriptionModel = id else store.cleanupModel = id
                    result.success(null)
                }
                "probeLimits" -> {
                    // I limiti di un modello che non hai ancora usato: si chiedono una volta sola.
                    val id = call.argument<String>("id")!!
                    val speech = call.argument<Boolean>("speech") == true
                    val key = store.apiKey
                    if (key == null || store.modelLimits(id).isNotEmpty()) return@setMethodCallHandler result.success(null)
                    background(result) {
                        val g = Groq(key)
                        g.probe(id, speech)
                        store.saveModelLimits(id, g.lastLimits)
                        null
                    }
                }
                "setWords" -> {
                    store.words = call.argument<List<String>>("words")!!
                    result.success(null)
                }
                "setPrompt" -> {
                    store.customPrompt = call.argument<String?>("prompt")
                    result.success(null)
                }
                "setPurify" -> {
                    val on = call.argument<Boolean>("on")!!
                    PillService.instance?.session?.let { if (it.purify != on) it.togglePurify() } ?: run { store.purify = on }
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "startPill" -> {
                    if (!Settings.canDrawOverlays(this)) return@setMethodCallHandler result.success("overlay")
                    // Tirato fuori a mano dal nido: si attacca al bordo più vicino, all'altezza in cui l'hai lasciato.
                    if (call.argument<Boolean>("place") == true) {
                        val b = windowManager.currentWindowMetrics.bounds
                        store.pillRight = call.argument<Double>("x")!! > b.width() / 2.0
                        store.pillY = (call.argument<Double>("y")!! / b.height()).toFloat().coerceIn(0.08f, 0.92f)
                    }
                    PillService.start(
                        this, call.argument<Double>("x")!!.toFloat(), call.argument<Double>("y")!!.toFloat(),
                        call.argument<List<Double>>("home")?.map { it.toFloat() }?.toFloatArray(),
                    )
                    result.success(null)
                }
                "setNest" -> {
                    // Solo con l'app davanti: un aggiornamento che arriva dopo la pausa (Flutter ridisegna
                    // ancora un fotogramma) farebbe rientrare Transcri in un nido che non si vede.
                    PillService.appNest = if (!resumed) null else call.argument<List<Double>>("rect")?.map { it.toFloat() }?.toFloatArray()
                        ?.let { with(PillService) { it.toRect() } }
                    result.success(null)
                }
                "stopPill" -> {
                    val x = call.argument<Double>("x")
                    val y = call.argument<Double>("y")
                    val pill = PillService.instance
                    // Con un punto di arrivo la pillola rientra volando nel bottone.
                    if (pill != null && x != null && y != null) {
                        val home = call.argument<List<Double>>("home")?.map { it.toFloat() }?.toFloatArray()
                        pill.recall(
                            androidx.compose.ui.geometry.Offset(x.toFloat(), y.toFloat()),
                            home?.let { with(PillService) { it.toRect() } },
                            toApp = true,
                        )
                    } else {
                        PillService.stop(this)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // La pillola avvisa quando cambia qualcosa: Flutter rilegge.
        PillService.listener = { main.post { channel.invokeMethod("changed", null) } }
        PillService.hotListener = { hot -> main.post { channel.invokeMethod("nestHot", hot) } }
        PillService.liveListener = { live -> main.post { channel.invokeMethod("live", live) } }
        // Una nota ha i suoi argomenti: Flutter rilegge (l'indicatore nella lista, la nota aperta).
        topics.listener = { main.post { channel.invokeMethod("changed", null) } }
        ShareShortcuts.publish(this)
        // Le note scritte prima di scegliere il modello, o cambiate mentre l'app era chiusa.
        topics.requestAll()
    }

    private var resumed = false

    override fun onResume() {
        super.onResume()
        resumed = true
    }

    // Fuori dall'app il nido non si vede: si rientra nella casa che compare in basso.
    override fun onPause() {
        resumed = false
        PillService.appNest?.let { lastNest = it }
        PillService.appNest = null
        super.onPause()
    }

    /** Dov'era il nido quando l'app è andata via: se Transcri stava ascoltando, esce da lì. */
    private var lastNest: androidx.compose.ui.geometry.Rect? = null

    // Il tasto Home arriva prima della fine dell'animazione; onStop copre tutti gli altri modi di uscire.
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        PillService.instance?.appLeft(PillService.appNest ?: lastNest)
    }

    override fun onStop() {
        PillService.instance?.appLeft(lastNest)
        super.onStop()
    }

    override fun onDestroy() {
        PillService.listener = null
        PillService.hotListener = null
        PillService.liveListener = null
        PillService.appNest = null
        super.onDestroy()
    }

    private fun state(): Map<String, Any?> {
        val (hour, day) = store.usage()
        val (hourEnd, dayEnd) = store.windowsEnd()
        return mapOf(
            "hasKey" to (store.apiKey != null),
            "introSeen" to store.introSeen,
            "maskedKey" to store.maskedKey,
            "pillOn" to PillService.running,
            "sandbox" to Sandbox.on(this),
            "live" to PillService.instance?.liveNow(),
            "purify" to store.purify,
            "words" to store.words,
            "prompt" to store.prompt,
            "customPrompt" to (store.customPrompt != null),
            "defaultPrompt" to store.defaultPrompt,
            "mode" to store.cleanMode,
            "limited" to when (store.checkLimits()) {
                Limit.DAILY -> "daily"
                Limit.HOURLY -> "hourly"
                Limit.OK -> null
            },
            "resetAt" to store.resetAt(),
            "simulateLimit" to store.simulateLimit,
            "simOffline" to Simulated.offline,
            "simBadKey" to Simulated.badKey,
            "simNoMic" to Simulated.noMic,
            "sttModel" to store.transcriptionModel,
            "llmModel" to store.cleanupModel,
            "sttLimits" to store.modelLimits(store.transcriptionModel),
            "llmLimits" to store.modelLimits(store.cleanupModel),
            "sttUses" to store.usesToday(store.transcriptionModel),
            "llmUses" to store.usesToday(store.cleanupModel),
            "hourUsed" to hour,
            "dayUsed" to day,
            "hourEnd" to hourEnd,
            // Gli stessi due toni che usa la parte nativa per Transcri.
            "accentA" to getColor(android.R.color.system_accent1_300),
            "accentB" to getColor(android.R.color.system_accent3_300),
            // Lo stesso tono pieno dei bottoni della pillola: l'app e Transcri hanno un colore solo.
            "accentMain" to getColor(android.R.color.system_accent1_400),
            // Gli stessi rosso e verde della pillola: Transcri è uguale dovunque.
            "stateRed" to PillService.stateColor(this, PillService.RED),
            "stateGreen" to PillService.stateColor(this, PillService.GREEN),
            "accentSecond" to getColor(android.R.color.system_accent3_400),
            "dayEnd" to dayEnd,
            "hourLimit" to Store.HOUR_LIMIT,
            "dayLimit" to Store.DAY_LIMIT,
        )
    }

    private fun modelsFrom(json: String): List<Map<String, Any>> {
        val arr = org.json.JSONArray(json)
        return (0 until arr.length()).map { arr.getJSONObject(it) }.map {
            mapOf("id" to it.getString("id"), "owner" to it.optString("owner"), "context" to it.optInt("context"), "speech" to it.getBoolean("speech"))
        }
    }

    /** Lavoro di rete fuori dal thread principale; gli errori di Groq tornano come messaggi leggibili. */
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        thread {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("groq", e.message ?: "Errore", null) }
            }
        }
    }
}
