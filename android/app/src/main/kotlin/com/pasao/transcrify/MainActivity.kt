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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "transcrify/core")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "state" -> result.success(state())
                "history" -> result.success(store.history().map { mapOf("text" to it.text, "at" to it.at, "purified" to it.purified, "mode" to it.mode) })
                "pending" -> result.success(queue.all().map {
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
                            val t = Transcriber(store, queue)
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
                    PillService.start(
                        this, call.argument<Double>("x")!!.toFloat(), call.argument<Double>("y")!!.toFloat(),
                        call.argument<List<Double>>("home")?.map { it.toFloat() }?.toFloatArray(),
                    )
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
    }

    override fun onDestroy() {
        PillService.listener = null
        super.onDestroy()
    }

    private fun state(): Map<String, Any?> {
        val (hour, day) = store.usage()
        return mapOf(
            "hasKey" to (store.apiKey != null),
            "maskedKey" to store.maskedKey,
            "pillOn" to PillService.running,
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
            "sttModel" to store.transcriptionModel,
            "llmModel" to store.cleanupModel,
            "sttLimits" to store.modelLimits(store.transcriptionModel),
            "llmLimits" to store.modelLimits(store.cleanupModel),
            "sttUses" to store.usesToday(store.transcriptionModel),
            "llmUses" to store.usesToday(store.cleanupModel),
            "hourUsed" to hour,
            "dayUsed" to day,
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
