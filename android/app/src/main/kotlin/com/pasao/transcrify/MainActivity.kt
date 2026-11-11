package com.pasao.transcrify

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.Executors
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
                "openTrasparenza" -> {
                    startActivity(android.content.Intent(this, Trasparenza::class.java))
                    result.success(null)
                }
                // Il nome e l'icona dell'app da cui è arrivato un audio condiviso (PNG), per il simbolino nell'app.
                "provenienza" -> {
                    val source = call.argument<String>("source")
                    val png = Provenienza.icona(this, source)?.let { b ->
                        java.io.ByteArrayOutputStream().also { b.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
                    }
                    result.success(mapOf("nome" to Provenienza.nome(this, source), "icona" to png))
                }
                "history" -> background(result, letture) { store.history().map { it.toMap() } }
                // Quello che si sta trascrivendo adesso non è "in attesa": compare solo se fallisce.
                "pending" -> result.success(queue.all().filter { it.id !in (PillService.instance?.session?.working ?: emptySet()) }.map {
                    mapOf("id" to it.id, "at" to it.at, "seconds" to it.seconds, "mode" to it.mode)
                })
                "discardPending" -> {
                    queue.remove(call.argument<String>("id")!!)
                    PillService.instance?.session?.codaCambiata()
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
                "setSandbox" -> cambiaSandbox(call.argument<Boolean>("on")!!)
                // I dieci tocchi sulla versione (o «Nascondi le prove»). Nascondendole coi dati finti accesi, si spengono
                // anche loro (e l'app riparte sui dati veri): non resta un interruttore acceso che non si vede.
                "sbloccaProve" -> {
                    val on = call.argument<Boolean>("on")!!
                    val finti = Sandbox.on(this)
                    Prove.sblocca(this, on)
                    if (!on && !Prove.visibili(this) && finti) cambiaSandbox(false) else result.success(null)
                }
                "editHistory" -> {
                    store.editEntry(call.argument<Number>("at")!!.toLong(), call.argument<String>("text")!!)
                    result.success(null)
                }
                // Colore, privata e titolo, su una o più trascrizioni: c'è solo quello che cambia (RegoleColori.segna).
                "segnaHistory" -> {
                    val ats = call.argument<List<Number>>("ats")!!.map { it.toLong() }.toSet()
                    val segno = Segno(
                        colore = call.hasArgument("colore"), nuovoColore = call.argument<String>("colore"),
                        privata = call.argument<Boolean>("privata"),
                        titolo = call.hasArgument("titolo"), nuovoTitolo = call.argument<String>("titolo"),
                    )
                    val regole = store.regoleColori
                    store.cambia(ats) { RegoleColori.segna(it, segno, regole) }
                    // Una diventata privata ha il titolo per prima (la sua scheda mostra solo quello).
                    Titolatore.get(this).avvia()
                    result.success(null)
                }
                // Unite: il titolo di macchina se ne va, Groq ne fa uno per il testo intero.
                "unisciHistory" -> {
                    result.success(store.unisci(call.argument<List<Number>>("ats")!!.map { it.toLong() })?.toMap())
                    Titolatore.get(this).avvia()
                }
                // Le regole dei colori (7 nov): colore → {regola, offuscaSempre, daNome}. Senza una regola scritta vale il
                // nome del colore (10 nov, RegoleColori.effettive): allora daNome è true.
                "regoleColori" -> {
                    val scritte = store.regoleColori
                    result.success(RegoleColori.effettive(scritte, store.nomiColori).mapValues { (c, r) -> r.toMap() + ("daNome" to scritte[c]?.regola.isNullOrBlank()) })
                }
                // «Offusca sempre» vale per tutte quelle che hanno quel colore (10 nov): acceso le rende private (anche se
                // era già acceso: così si rimettono in pari quelle rimaste indietro), spento le rimette tutte in vista.
                // Quante ne ha offuscate, in «offuscate».
                "salvaRegola" -> {
                    val colore = call.argument<String>("colore")!!
                    val regola = RegolaColore(call.argument<String>("regola").orEmpty(), call.argument<Boolean>("offuscaSempre") ?: false)
                    val prima = store.regoleColori
                    store.regoleColori = RegoleColori.salva(prima, colore, regola)
                    val offuscate = when {
                        regola.offuscaSempre -> offusca(colore, true)
                        prima[colore]?.offuscaSempre == true -> { offusca(colore, false); 0 }
                        else -> 0
                    }
                    // Le regole cambiate: «Colora da sola» rifà le sue proposte (non colora niente da sola).
                    topics.proponiColori()
                    result.success(mapOf("offuscate" to offuscate))
                }
                // «Colora le sue di prima»: quali ha colorato (i loro «at»), per «Ho colorato N come «nome» · Annulla».
                "coloraRetro" -> coloraRetro(call.argument<String>("colore")!!) { ats -> runOnUiThread { result.success(mapOf("ids" to ats)) } }
                // L'«Annulla»: tornano com'erano (se nel frattempo non le hai toccate tu).
                "annullaColoraRetro" -> {
                    val ats = call.argument<List<Number>>("ids")!!.map { it.toLong() }.toSet()
                    val regole = RegoleColori.effettive(store.regoleColori, store.nomiColori)
                    store.cambia(ats) { RegoleColori.annullaColorata(it, regole[it.colore]?.offuscaSempre == true) }
                    result.success(null)
                }
                "rimettiHistory" -> {
                    store.rimetti(call.argument<List<Map<*, *>>>("voci")!!.map(Transcription::fromMap))
                    result.success(null)
                }
                "nomiColori" -> result.success(store.nomiColori)
                // Le ultime ricerche (7 nov): restano sul telefono; quali e quante lo decide Flutter (RicercheRecenti).
                "ricercheRecenti" -> {
                    val p = getSharedPreferences("ricerca", MODE_PRIVATE)
                    call.argument<List<String>>("ricerche")?.let { p.edit().putString("recenti", it.joinToString("\n")).apply() }
                    result.success(p.getString("recenti", "")!!.split('\n').filter { it.isNotEmpty() })
                }
                "nomeColore" -> {
                    val colore = call.argument<String>("colore")!!
                    val nome = call.argument<String>("nome")?.trim().orEmpty()
                    store.nomiColori = store.nomiColori.toMutableMap().apply { if (nome.isEmpty()) remove(colore) else put(colore, nome) }
                    topics.proponiColori()
                    if (nome.isNotEmpty()) proponiRegola(colore, nome)
                    result.success(null)
                }
                // «Proponi etichette» (10 nov): a Groq solo i titoli; torna [{nome, regola}], senza i nomi che hai già.
                "proponiEtichette" -> background(result) {
                    val key = store.apiKey ?: throw GroqError("Manca la chiave di Groq")
                    Groq(key).etichette(store.history().mapNotNull { it.titolo }, store.nomiColori.values, store.cleanupModel)
                        .also { store.countUse(store.cleanupModel) }
                        .map { it.toMap() }
                }
                // «Proponi regole» (10 nov): a Groq solo i titoli e le etichette con la regola di adesso; torna
                // [{colore, nome, regola}] per quelle che cambiano. Le applica Flutter, una per una, con «salvaRegola».
                "proponiRegole" -> background(result) {
                    val key = store.apiKey ?: throw GroqError("Manca la chiave di Groq")
                    val nomi = store.nomiColori.filterValues { it.isNotBlank() }
                    val adesso = RegoleColori.effettive(store.regoleColori, nomi)
                    val perNome = nomi.entries.associate { (colore, nome) -> nome.trim() to (adesso[colore]?.regola ?: nome.trim()) }
                    val nuove = Groq(key).regole(store.history().mapNotNull { it.titolo }, perNome, store.cleanupModel).also { store.countUse(store.cleanupModel) }
                    nomi.mapNotNull { (colore, nome) ->
                        nuove[nome.trim()]?.takeIf { it != perNome[nome.trim()] }?.let { mapOf("colore" to colore, "nome" to nome, "regola" to it) }
                    }
                }
                "listen" -> {
                    // Parte con l'app davanti: Android poi lascia il microfono acceso anche fuori.
                    PillService.listen(
                        this, call.argument<Number>("appendTo")?.toLong(), call.argument<Number>("cursor")?.toInt() ?: -1,
                        call.argument<List<Double>>("panel")?.map { it.toFloat() }?.toFloatArray(),
                    )
                    result.success(null)
                }
                "lasciaDettatura" -> {
                    PillService.instance?.lasciaDettatura()
                    result.success(null)
                }
                "openPanel" -> {
                    call.argument<List<Double>>("rect")?.map { it.toFloat() }?.toFloatArray()
                        ?.let { with(PillService) { it.toRect() } }
                        ?.let { PillService.instance?.openPanel(it) }
                    result.success(null)
                }
                "stopListening" -> {
                    PillService.instance?.stopListening()
                    result.success(null)
                }
                "togglePause" -> {
                    PillService.instance?.togglePause()
                    result.success(null)
                }
                "discardListening" -> {
                    PillService.instance?.discardListening()
                    result.success(null)
                }
                "summarize" -> {
                    val key = store.apiKey ?: return@setMethodCallHandler result.error("nokey", "Manca la chiave", null)
                    background(result) {
                        Groq(key).cleanLong(call.argument<String>("text")!!, store.cleanupModel, store.promptFor("riassunto"), store.words, riserva = store.riservaPulizia)
                            .also { store.countUse(store.cleanupModel) }
                    }
                }
                "introSeen" -> {
                    store.introSeen = true
                    result.success(null)
                }
                // La riga dei titoli nelle Prove: quanti fatti e cosa sta facendo il Titolatore.
                "titoli" -> background(result) { Titolatore.get(this).riepilogo() }
                // «Rifai i titoli» (Prove): via quelli di Groq (i tuoi restano), e si richiedono. Risponde quanti.
                "rifaiTitoli" -> background(result) { Titolatore.get(this).rifai() }
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
                "notes" -> background(result, letture) { store.notes().map { it.toMap() + ("topics" to topics.state(it.id, it.text)) } }
                "noteTopics" -> result.success(topics.topics(call.argument<String>("id")!!))
                "albums" -> background(result, letture) { topics.albums() }
                "categorie" -> background(result, letture) { topics.categorie() }
                "cerca" -> topics.cerca(call.argument<String>("testo").orEmpty(), call.argument<Boolean>("senso") == true) { trovati -> runOnUiThread { result.success(trovati) } }
                "ricercaAperta" -> { topics.ricercaAperta(call.argument<Boolean>("aperta") == true); result.success(null) }
                "estratto" -> topics.estratto(call.argument<String>("testo").orEmpty()) { r -> runOnUiThread { result.success(r) } }
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
                            call.argument<Boolean>("privata") ?: false,
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
                // Acceso, propone per tutte quelle senza colore; spento, le proposte se ne vanno.
                "coloraDaSola" -> {
                    store.coloraDaSola = call.argument<Boolean>("on")!!
                    if (store.coloraDaSola) topics.proponiColori() else store.proposteColore = emptyMap()
                    result.success(null)
                }
                // «Colora da sola» propone (10 nov): [{at, colore}], solo quelle ancora senza colore.
                "proposteColore" -> background(result, letture) {
                    val proposte = ProposteColore.valide(store.proposteColore, store.history())
                    if (proposte != store.proposteColore) store.proposteColore = proposte
                    proposte.map { (at, colore) -> mapOf("at" to at, "colore" to colore) }
                }
                "accettaProposta" -> {
                    accettaProposte(setOf(call.argument<Number>("at")!!.toLong()))
                    result.success(null)
                }
                "accettaTutte" -> {
                    accettaProposte(null)
                    result.success(null)
                }
                "rifiutaTutte" -> {
                    val (proposte, rifiutate) = ProposteColore.rifiutaTutte(store.proposteColore, store.rifiutateColore)
                    store.proposteColore = proposte
                    store.rifiutateColore = rifiutate
                    result.success(null)
                }
                "rifiutaProposta" -> {
                    val (proposte, rifiutate) = ProposteColore.rifiuta(store.proposteColore, store.rifiutateColore, call.argument<Number>("at")!!.toLong())
                    store.proposteColore = proposte
                    store.rifiutateColore = rifiutate
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
                        // La prova dell'introduzione: esce già in ascolto, come dal tasto che detta del widget.
                        record = call.argument<Boolean>("record") == true,
                        // ...e guidata: ferma sul bordo destro a quell'altezza (frazione dello schermo), senza salvarla.
                        guida = call.argument<Double>("guida")?.toFloat(),
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
                        // Senza punto d'arrivo rientra nella casa in basso: quello che stava registrando si manda lo stesso.
                        pill?.rientra()
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
        // Un titolo arrivato da Groq: Flutter rilegge. Un colore messo da sola: la pillola «Annulla».
        Titolatore.get(this).listener = { main.post { channel.invokeMethod("changed", null) } }
        topics.proposteCambiate = { main.post { channel.invokeMethod("proposteColore", null) } }
        // I titoli delle trascrizioni di prima, piano piano.
        Titolatore.get(this).avvia()
        // Il widget col disegno e i colori di adesso (un aggiornamento dell'app non lo ridisegna da solo).
        TranscriWidget.refresh(this)
        // «Trascrivi» in cima al Condividi (la scorciatoia, accanto alla voce tra le app).
        ShareShortcuts.publish(this)
        // Le note scritte prima di scegliere il modello, o cambiate mentre l'app era chiusa.
        topics.requestAll()
        // «Colora da sola»: le proposte per quelle senza colore (anche di prima), se l'hai acceso; solo se le etichette
        // o il modello sono cambiati da quando sono state fatte.
        topics.proponiColori(seCambiate = true)
    }

    private var resumed = false

    override fun onResume() {
        super.onResume()
        resumed = true
        // Si riapre l'app: i titoli ripartono se si erano fermati (senza rete, un errore); una pausa in corso si aspetta.
        Titolatore.get(this).avvia()
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

    override fun onStart() {
        super.onStart()
        PillService.appDavanti = true
    }

    override fun onStop() {
        PillService.appDavanti = false
        PillService.instance?.appLeft(lastNest)
        super.onStop()
    }

    override fun onDestroy() {
        PillService.listener = null
        PillService.hotListener = null
        PillService.liveListener = null
        PillService.appNest = null
        Titolatore.get(this).listener = null
        topics.proposteCambiate = null
        letture.shutdown()
        super.onDestroy()
    }

    /** Tutto legge la cartella all'avvio: si chiude Transcri e si riparte da capo. */
    private fun cambiaSandbox(on: Boolean) {
        PillService.stop(this)
        Sandbox.set(this, on)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        }
        android.os.Process.killProcess(android.os.Process.myPid())
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
            "prove" to Prove.visibili(this),
            "proveSbloccate" to Prove.sbloccate(this),
            "versione" to packageManager.getPackageInfo(packageName, 0).versionName,
            // I valori di chi apre l'app la prima volta, per la prova «come un utente nuovo».
            "sttDefault" to Groq.DEFAULT_STT,
            "llmDefault" to Groq.DEFAULT_LLM,
            "promptDefault" to Groq.DEFAULT_PROMPT,
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
            "coloraDaSola" to store.coloraDaSola,
            "simOffline" to Simulated.offline,
            "simBadKey" to Simulated.badKey,
            "simNoMic" to Simulated.noMic,
            "provaRespiro" to Simulated.respiro,
            "sttModel" to store.transcriptionModel,
            "llmModel" to store.cleanupModel,
            "sttLimits" to store.modelLimits(store.transcriptionModel),
            "llmLimits" to store.modelLimits(store.cleanupModel),
            "sttUses" to store.usesToday(store.transcriptionModel),
            "llmUses" to store.usesToday(store.cleanupModel),
            "hourUsed" to hour,
            "dayUsed" to day,
            "hourEnd" to hourEnd,
            // I token del design system, dalla fonte unica (Token.kt): gli stessi della pillola e del widget.
            "tokenChiaro" to Token.dal(Seme.di(this), scuro = false).mappa(),
            "tokenScuro" to Token.dal(Seme.di(this), scuro = true).mappa(),
            "dayEnd" to dayEnd,
            "hourLimit" to Store.HOUR_LIMIT,
            "dayLimit" to Store.DAY_LIMIT,
        )
    }

    /**
     * Le trascrizioni di [colore] diventano private ([privata] true, e hanno il titolo per prime) o tornano in vista, in
     * una scrittura sola. Quante sono cambiate.
     */
    private fun offusca(colore: String, privata: Boolean): Int {
        val ats = RegoleColori.daCambiare(store.history(), colore, privata)
        if (ats.isEmpty()) return 0
        store.cambia(ats) { if (it.colore == colore) it.copy(privata = privata) else it }
        if (privata) Titolatore.get(this).avvia()
        return ats.size
    }

    /**
     * Un'etichetta appena nominata (10 nov): in fondo si chiede a Groq, una volta, una regola per lei; si scrive solo se
     * intanto non ne hai scritta una tu e il nome è ancora quello ([Proposte.daSalvare]). Senza chiave o rete, niente.
     */
    private fun proponiRegola(colore: String, nome: String) {
        if (!store.regoleColori[colore]?.regola.isNullOrBlank()) return
        val key = store.apiKey ?: return
        thread {
            val proposta = runCatching { Groq(key).regolaPer(nome, store.cleanupModel).also { store.countUse(store.cleanupModel) } }.getOrNull()
                ?: return@thread
            val regole = store.regoleColori
            Proposte.daSalvare(proposta, regole[colore], nome, store.nomiColori[colore])?.let { store.regoleColori = RegoleColori.salva(regole, colore, it) }
        }
    }

    /** [RegoleColori.daColorare] in fondo; [fatto] riceve i loro «at» dal thread del lavoro. */
    private fun coloraRetro(colore: String, fatto: (List<Long>) -> Unit) = topics.coloraRetro(colore) { ats ->
        if (ats.isNotEmpty()) Titolatore.get(this).avvia()
        fatto(ats)
    }

    /** Le proposte accettate ([ats], null: tutte) prendono il loro colore, in una scrittura sola ([ProposteColore.accetta]). */
    private fun accettaProposte(ats: Set<Long>?) {
        val proposte = store.proposteColore
        val scelte = if (ats == null) proposte else proposte.filterKeys { it in ats }
        val regole = RegoleColori.effettive(store.regoleColori, store.nomiColori)
        store.cambia(scelte.keys) { t -> scelte[t.at]?.let { ProposteColore.accetta(t, it, regole) } ?: t }
        store.proposteColore = proposte - scelte.keys
        // Una diventata privata ha il titolo per prima (la sua scheda mostra solo quello).
        Titolatore.get(this).avvia()
    }

    private fun modelsFrom(json: String): List<Map<String, Any>> {
        val arr = org.json.JSONArray(json)
        return (0 until arr.length()).map { arr.getJSONObject(it) }.map {
            mapOf("id" to it.getString("id"), "owner" to it.optString("owner"), "context" to it.optInt("context"), "speech" to it.getBoolean("speech"))
        }
    }

    /**
     * Le letture delle liste (file + JSON) fuori dal thread principale, che con Flutter è anche quello
     * dell'interfaccia: leggere lì faceva saltare i fotogrammi. Una alla volta, così arrivano in ordine.
     */
    private val letture = Executors.newSingleThreadExecutor()

    /** Lavoro di rete (o una lettura, in [on]) fuori dal thread principale; gli errori di Groq tornano come messaggi leggibili. */
    private fun background(result: MethodChannel.Result, on: Executor = Executor { thread(block = it::run) }, work: () -> Any?) {
        on.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("groq", e.message ?: "Errore", null) }
            }
        }
    }
}
