package com.pasao.transcrify

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Una trascrizione salvata. [colore]: il suo colore («tinta:luce», lo legge solo l'app; null = nessuno).
 * [privata]: sulla scheda il testo non si vede. [titolo]: il suo titolo (6 nov), scritto da te o proposto dall'app col
 * riassunto estrattivo; null = non ne ha ancora uno (quelle di prima dei titoli). Dal 7 nov il titolo lo scrive Groq, una
 * volta sola ([Titolatore]). [titoloChiesto]: il titolo è già stato chiesto (o l'hai toccato tu): non si richiede più,
 * anche se è vuoto. [titoloUtente]: il titolo l'hai scritto (o tolto) tu: «Rifai i titoli» non lo tocca.
 * [coloreAuto]: il colore l'ha messo l'app da sola («Colora da sola»); lo tocchi tu e torna tuo.
 */
data class Transcription(
    val text: String, val at: Long, val purified: Boolean, val mode: String? = null, val source: String? = null, val noteId: String? = null,
    val colore: String? = null, val privata: Boolean = false, val titolo: String? = null,
    val titoloChiesto: Boolean = false, val coloreAuto: Boolean = false, val titoloUtente: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject().put("text", text).put("at", at).put("purified", purified).put("mode", mode).put("source", source)
        .put("colore", colore).put("privata", privata).put("titolo", titolo).put("titoloChiesto", titoloChiesto).put("coloreAuto", coloreAuto)
        .put("titoloUtente", titoloUtente)

    /**
     * Col [c] messo da sola, se può prenderlo: mai una privata, mai sopra un colore che c'è già. Null se no. [offusca]:
     * il colore ha «offusca sempre» (RegoleColori): diventa privata anche lei.
     */
    fun colorataDaSola(c: String, offusca: Boolean = false): Transcription? =
        if (colore == null && !privata) copy(colore = c, coloreAuto = true, privata = offusca) else null

    /** Quello che arriva all'app (e che l'app rimanda indietro per rimettere com'era). */
    fun toMap(): Map<String, Any?> =
        mapOf("text" to text, "at" to at, "purified" to purified, "mode" to mode, "source" to source, "colore" to colore, "privata" to privata, "titolo" to titolo,
            "titoloChiesto" to titoloChiesto, "coloreAuto" to coloreAuto, "titoloUtente" to titoloUtente)

    companion object {
        fun fromJson(j: JSONObject) = Transcription(
            j.getString("text"), j.getLong("at"), j.optBoolean("purified"),
            // Le trascrizioni di prima dei modi erano tutte "pulite".
            if (j.isNull("mode")) (if (j.optBoolean("purified")) "pulita" else null) else j.getString("mode"),
            if (j.isNull("source")) null else j.getString("source"),
            // Quelle di prima dei colori: nessun colore, non private.
            colore = if (j.isNull("colore")) null else j.getString("colore"),
            privata = j.optBoolean("privata"),
            // Quelle di prima dei titoli: nessun titolo.
            titolo = if (j.isNull("titolo")) null else j.getString("titolo"),
            titoloChiesto = j.optBoolean("titoloChiesto"), coloreAuto = j.optBoolean("coloreAuto"), titoloUtente = j.optBoolean("titoloUtente"),
        )

        /** Da quello che rimanda l'app (vedi [toMap]). */
        fun fromMap(m: Map<*, *>) = Transcription(
            m["text"] as String, (m["at"] as Number).toLong(), m["purified"] as? Boolean ?: false, m["mode"] as String?, m["source"] as String?,
            colore = m["colore"] as String?, privata = m["privata"] as? Boolean ?: false, titolo = m["titolo"] as String?,
            titoloChiesto = m["titoloChiesto"] as? Boolean ?: false, coloreAuto = m["coloreAuto"] as? Boolean ?: false,
            titoloUtente = m["titoloUtente"] as? Boolean ?: false,
        )
    }
}

/** Una nota: tua, da rileggere. Il titolo può restare vuoto. */
/** [privata]: offuscata (la copertina sulla scheda), come le trascrizioni. Le note di prima non ce l'hanno: false. */
data class Note(val id: String, val title: String, val text: String, val created: Long, val updated: Long, val source: String? = null, val summary: String? = null, val privata: Boolean = false) {
    fun toJson(): JSONObject = JSONObject().put("id", id).put("title", title).put("text", text).put("created", created).put("updated", updated).put("source", source).put("summary", summary).put("privata", privata)
    fun toMap(): Map<String, Any?> = mapOf("id" to id, "title" to title, "text" to text, "created" to created, "updated" to updated, "source" to source, "summary" to summary, "privata" to privata)

    companion object {
        fun fromJson(j: JSONObject) = Note(
            j.getString("id"), j.optString("title"), j.optString("text"), j.getLong("created"), j.getLong("updated"),
            if (j.isNull("source")) null else j.getString("source"),
            if (j.isNull("summary")) null else j.getString("summary"),
            j.optBoolean("privata"),
        )
    }
}

/**
 * Mette [piece] in [text] alla posizione [cursor]. Dentro il testo si attacca con uno spazio dove serve;
 * in fondo, o senza cursore (-1), diventa un paragrafo nuovo. Il cursore può essere vecchio: non si fida.
 */
fun insertPiece(text: String, piece: String, cursor: Int): String {
    if (cursor !in 0 until text.trimEnd().length) return if (text.isBlank()) piece else text.trimEnd() + "\n\n" + piece
    val before = text.substring(0, cursor)
    val after = text.substring(cursor)
    val left = if (before.isEmpty() || before.last().isWhitespace()) "" else " "
    val right = if (after.first().isWhitespace()) "" else " "
    return before + left + piece + right + after
}

enum class Limit { OK, HOURLY, DAILY }

/**
 * Tutto quello che l'app e la pillola ricordano. Vive nel processo nativo:
 * l'interfaccia Flutter lo legge e lo scrive attraverso MainActivity.
 */
class Store(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("transcrify", Context.MODE_PRIVATE)
    private val historyFile = File(Sandbox.dir(context), "history.json")
    private val notesFile = File(Sandbox.dir(context), "notes.json")

    // --- Chiave Groq, cifrata con una chiave del Keystore che non esce dal telefono ---

    var apiKey: String?
        get() {
            val iv = prefs.getString(K_KEY_IV, null) ?: return null
            val data = prefs.getString(K_KEY_DATA, null) ?: return null
            return try {
                val cipher = Cipher.getInstance(AES)
                cipher.init(Cipher.DECRYPT_MODE, vaultKey(), GCMParameterSpec(128, iv.b64()))
                String(cipher.doFinal(data.b64()))
            } catch (e: Exception) {
                null
            }
        }
        set(value) {
            if (value.isNullOrBlank()) {
                prefs.edit().remove(K_KEY_IV).remove(K_KEY_DATA).apply()
                return
            }
            val cipher = Cipher.getInstance(AES)
            cipher.init(Cipher.ENCRYPT_MODE, vaultKey())
            val data = cipher.doFinal(value.trim().toByteArray())
            prefs.edit().putString(K_KEY_IV, cipher.iv.b64()).putString(K_KEY_DATA, data.b64()).apply()
        }

    /**
     * La chiave, aspettandola se è salvata (vedi [Pronto]): appena svegliata dal Condividi il Keystore può non
     * rispondere al primo colpo. Se non c'è proprio, null subito.
     */
    fun chiavePronta(): String? = if (prefs.contains(K_KEY_DATA)) Pronto.attendi { apiKey } else null

    val maskedKey: String?
        get() = apiKey?.let { if (it.length < 12) "••••" else "${it.take(4)}••••••••${it.takeLast(4)}" }

    private fun vaultKey(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(VAULT_ALIAS, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(VAULT_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return gen.generateKey()
    }

    // --- Scelte ---

    /** L'introduzione è già stata vista (o saltata): non si ripropone a ogni avvio. */
    var introSeen: Boolean
        get() = prefs.getBoolean("intro_seen", false)
        set(v) = prefs.edit().putBoolean("intro_seen", v).apply()

    /** La trasparenza dei pezzi fuori dall'app (Trasparenza), uno per uno: da 0,5 a 1. */
    var opacitaFloater: Float
        get() = prefs.getFloat("opacita", Palette.OPACITA_BASE)
        set(v) = prefs.edit().putFloat("opacita", v).apply()
    var opacitaPillola: Float
        get() = prefs.getFloat("opacita_pillola", Palette.OPACITA_BASE)
        set(v) = prefs.edit().putFloat("opacita_pillola", v).apply()
    var opacitaCasa: Float
        get() = prefs.getFloat("opacita_casa", Palette.OPACITA_BASE)
        set(v) = prefs.edit().putFloat("opacita_casa", v).apply()

    var purify: Boolean
        get() = prefs.getBoolean("purify", false)
        set(v) = prefs.edit().putBoolean("purify", v).apply()

    var words: List<String>
        get() = prefs.getString("words", null)?.let { JSONArray(it).strings() } ?: emptyList()
        set(v) = prefs.edit().putString("words", JSONArray(v).toString()).apply()

    /** Come pulire: "fedele", "pulita" o "riassunto". Ogni modo ha il suo prompt. */
    var cleanMode: String
        get() = prefs.getString("clean_mode", null)?.takeIf { it in Groq.PROMPTS } ?: "pulita"
        set(v) = prefs.edit().putString("clean_mode", v).apply()

    /** Il prompt personalizzato del modo scelto; null = quello predefinito. */
    var customPrompt: String?
        get() = prefs.getString("prompt_$cleanMode", null)
        set(v) = prefs.edit().apply { if (v == null) remove("prompt_$cleanMode") else putString("prompt_$cleanMode", v) }.apply()

    val defaultPrompt: String get() = Groq.PROMPTS.getValue(cleanMode)
    val prompt: String get() = customPrompt ?: defaultPrompt

    /**
     * Quanto può cambiare il testo la pulizia prima che si tenga l'originale. Null se è giusto che cambi
     * molto: il riassunto, o un prompt scritto da te, che può chiedere qualunque cosa.
     */
    fun guardFor(mode: String): Double? = when {
        prefs.getString("prompt_$mode", null) != null -> null
        mode == "fedele" -> GUARD_FAITHFUL
        mode == "pulita" -> GUARD_CLEAN
        else -> null
    }

    /** Il prompt di un modo preciso (quello con cui è stata fatta una registrazione in coda). */
    fun promptFor(mode: String): String = prefs.getString("prompt_$mode", null) ?: Groq.PROMPTS[mode] ?: Groq.DEFAULT_PROMPT

    /** Elenco dei modelli di Groq, tenuto un giorno: la rotella si apre subito. */
    var modelsCache: String?
        get() = prefs.getString("models_cache", null)
            ?.takeIf { System.currentTimeMillis() - prefs.getLong("models_cache_at", 0) < DAY_MS }
        set(v) = prefs.edit().putString("models_cache", v).putLong("models_cache_at", System.currentTimeMillis()).apply()

    /**
     * Il modello che non ragiona con cui riprovare una pulizia tagliata ([Pulitura.riserva]), dall'ultima lista di Groq
     * anche se vecchia (serve solo sapere che c'è). Null se quello scelto non ragiona o la lista non si è mai letta.
     */
    val riservaPulizia: String?
        get() {
            val lista = prefs.getString("models_cache", null) ?: return null
            val ids = runCatching { JSONArray(lista).let { a -> (0 until a.length()).map { a.getJSONObject(it).getString("id") } } }.getOrDefault(emptyList())
            return Pulitura.riserva(cleanupModel, ids)
        }

    /** Solo per provare: fa finta che i minuti del giorno siano finiti. */
    init {
        Simulated.load(prefs)
    }

    var simulateLimit: Boolean
        get() = prefs.getBoolean("simulate_limit", false)
        set(v) = prefs.edit().putBoolean("simulate_limit", v).apply()

    var transcriptionModel: String
        get() = prefs.getString("model_stt", null) ?: Groq.DEFAULT_STT
        set(v) = prefs.edit().putString("model_stt", v).apply()

    var cleanupModel: String
        get() = prefs.getString("model_llm", null) ?: Groq.DEFAULT_LLM
        set(v) = prefs.edit().putString("model_llm", v).apply()

    /** Limiti letti dalle risposte di Groq, per modello (richieste/giorno, token/minuto…). */
    fun modelLimits(model: String): Map<String, String> =
        prefs.getString("limits_$model", null)?.let { JSONObject(it).let { j -> j.keys().asSequence().associateWith(j::getString) } }
            ?: emptyMap()

    fun saveModelLimits(model: String, limits: Map<String, String>) {
        if (limits.isNotEmpty()) prefs.edit().putString("limits_$model", JSONObject(limits).toString()).apply()
    }

    /** Usi di oggi per modello: si azzerano a mezzanotte. */
    fun usesToday(model: String): Int =
        if (prefs.getString("uses_day_$model", null) == today()) prefs.getInt("uses_$model", 0) else 0

    fun countUse(model: String) {
        prefs.edit().putString("uses_day_$model", today()).putInt("uses_$model", usesToday(model) + 1).apply()
    }

    private fun today() = java.time.LocalDate.now().toString()

    // --- I nomi dei colori delle trascrizioni («tinta:luce» → nome), si vedono nelle cartelle ---

    var nomiColori: Map<String, String>
        get() = prefs.getString("nomi_colori", null)?.let { JSONObject(it).let { j -> j.keys().asSequence().associateWith(j::getString) } } ?: emptyMap()
        set(v) = prefs.edit().putString("nomi_colori", JSONObject(v).toString()).apply()

    /** Le regole dei colori, scritte da te («tinta:luce» → [RegolaColore]): cosa ci va, e se offuscare sempre. */
    var regoleColori: Map<String, RegolaColore>
        get() = RegoleColori.daJson(prefs.getString("regole_colori", null))
        set(v) = prefs.edit().putString("regole_colori", RegoleColori.inJson(v)).apply()

    /** «Colora da sola» (Impostazioni, 7 nov; dal 10 nov propone soltanto, [proposteColore]). */
    var coloraDaSola: Boolean
        get() = prefs.getBoolean("colora_da_sola", false)
        set(v) = prefs.edit().putBoolean("colora_da_sola", v).apply()

    /** I colori proposti da «Colora da sola», non ancora messi (quando → «tinta:luce»): li decidi tu ([ProposteColore]). */
    var proposteColore: Map<Long, String>
        get() = ProposteColore.daJson(prefs.getString("proposte_colore", null))
        set(v) = prefs.edit().putString("proposte_colore", ProposteColore.inJson(v)).apply()

    /**
     * Con quali etichette e quale modello le proposte sono già state fatte su tutte (11 nov): uguale, all'avvio non si
     * rifanno ([NoteTopicsWorker.proponiColori]).
     */
    var proposteImpronta: String?
        get() = prefs.getString("proposte_impronta", null)
        set(v) = prefs.edit().putString("proposte_impronta", v).apply()

    /** Le proposte che hai rifiutato ([ProposteColore.chiave]): non tornano. */
    var rifiutateColore: Set<String>
        get() = prefs.getStringSet("rifiutate_colore", null).orEmpty().toSet()
        set(v) = prefs.edit().putStringSet("rifiutate_colore", v).apply()

    // --- Dove stava la pillola ---

    var pillRight: Boolean
        get() = prefs.getBoolean("pill_right", true)
        set(v) = prefs.edit().putBoolean("pill_right", v).apply()

    /** Centro verticale della pillola in frazione d'altezza dello schermo. */
    var pillY: Float
        get() = prefs.getFloat("pill_y", 0.42f)
        set(v) = prefs.edit().putFloat("pill_y", v).apply()

    // --- Audio da riprovare (vecchio: ora c'è la coda, qui solo per spostare quello rimasto) ---

    var retryFile: String?
        get() = prefs.getString("retry", null)
        set(v) = prefs.edit().apply { if (v == null) remove("retry") else putString("retry", v) }.apply()

    // --- Trascrizioni ---

    fun history(): List<Transcription> = synchronized(BLOCCO) {
        try {
            val arr = JSONArray(historyFile.readText())
            (0 until arr.length()).map { Transcription.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun addToHistory(t: Transcription) = synchronized(BLOCCO) { writeHistory((listOf(t) + history()).take(HISTORY_SIZE)) }

    fun removeFromHistory(at: Long) = synchronized(BLOCCO) { writeHistory(history().filter { it.at != at }) }

    /** Il testo l'hai cambiato tu: tutto il resto resta com'è. */
    fun editEntry(at: Long, text: String) = synchronized(BLOCCO) { writeHistory(segna(history(), setOf(at)) { it.copy(text = text) }) }

    /** Colore, privata o titolo, a una o più trascrizioni insieme: una scrittura sola. */
    fun cambia(ats: Set<Long>, come: (Transcription) -> Transcription) = synchronized(BLOCCO) { writeHistory(segna(history(), ats, come)) }

    /** Unisce le trascrizioni nell'ordine scelto (vedi [unisci]). Null se non ce ne sono almeno due. */
    fun unisci(ordine: List<Long>): Transcription? {
        return synchronized(BLOCCO) {
            val (resto, fusa) = com.pasao.transcrify.unisci(history(), ordine) ?: return null
            writeHistory(resto)
            fusa
        }
    }

    /** «Annulla»: le trascrizioni tornano com'erano (vedi [rimetti]). */
    fun rimetti(voci: List<Transcription>) = synchronized(BLOCCO) { writeHistory(com.pasao.transcrify.rimetti(history(), voci)) }

    /** Nuove parole in una trascrizione, dove c'era il cursore. Null se nel frattempo è stata eliminata. */
    fun addToEntry(at: Long, text: String, cursor: Int): Transcription? {
        return synchronized(BLOCCO) {
            val entry = history().firstOrNull { it.at == at } ?: return null
            val longer = entry.copy(text = insertPiece(entry.text, text, cursor))
            writeHistory(history().map { if (it.at == at) longer else it })
            longer
        }
    }

    private fun writeHistory(list: List<Transcription>) {
        val tmp = File(historyFile.parentFile, "history.tmp")
        tmp.writeText(JSONArray(list.map { it.toJson() }).toString())
        tmp.renameTo(historyFile)
    }

    // --- Note ---

    /** Dalla più recente: quella che hai toccato per ultima sta in cima. */
    fun notes(): List<Note> = synchronized(BLOCCO) {
        try {
            val arr = JSONArray(notesFile.readText())
            (0 until arr.length()).map { Note.fromJson(arr.getJSONObject(it)) }.sortedByDescending { it.updated }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** Nuova, o al posto di quella con lo stesso id. */
    fun saveNote(n: Note) = synchronized(BLOCCO) { writeNotes(listOf(n) + notes().filter { it.id != n.id }) }

    fun deleteNote(id: String) = synchronized(BLOCCO) { writeNotes(notes().filter { it.id != id }) }

    private fun writeNotes(list: List<Note>) {
        val tmp = File(notesFile.parentFile, "notes.tmp")
        tmp.writeText(JSONArray(list.map { it.toJson() }).toString())
        tmp.renameTo(notesFile)
    }

    // --- Limiti del piano gratuito sull'audio (secondi) ---

    fun checkLimits(): Limit {
        if (simulateLimit) return Limit.DAILY
        val now = System.currentTimeMillis()
        if (prefs.getLong(K_HOUR_START, 0) in 1..(now - HOUR_MS)) {
            prefs.edit().putLong(K_HOUR_START, 0).putLong(K_HOUR_USED, 0).apply()
        }
        if (prefs.getLong(K_DAY_START, 0) in 1..(now - DAY_MS)) {
            prefs.edit().putLong(K_DAY_START, 0).putLong(K_DAY_USED, 0).apply()
        }
        return when {
            prefs.getLong(K_DAY_USED, 0) >= DAY_LIMIT -> Limit.DAILY
            prefs.getLong(K_HOUR_USED, 0) >= HOUR_LIMIT -> Limit.HOURLY
            else -> Limit.OK
        }
    }

    /** Quando tornano i minuti, se sono finiti. */
    fun resetAt(): Long? = when (checkLimits()) {
        Limit.DAILY -> if (simulateLimit) System.currentTimeMillis() + 3 * HOUR_MS else prefs.getLong(K_DAY_START, 0) + DAY_MS
        Limit.HOURLY -> prefs.getLong(K_HOUR_START, 0) + HOUR_MS
        Limit.OK -> null
    }

    /** Quando si azzerano i minuti dell'ora e del giorno (null se la finestra non è ancora partita). */
    fun windowsEnd(): Pair<Long?, Long?> {
        checkLimits()
        val hour = prefs.getLong(K_HOUR_START, 0).takeIf { it > 0 }?.plus(HOUR_MS)
        val day = prefs.getLong(K_DAY_START, 0).takeIf { it > 0 }?.plus(DAY_MS)
        return hour to day
    }

    fun usage(): Pair<Long, Long> {
        checkLimits()
        return prefs.getLong(K_HOUR_USED, 0) to prefs.getLong(K_DAY_USED, 0)
    }

    fun addUsage(seconds: Long) {
        if (seconds <= 0) return
        val now = System.currentTimeMillis()
        prefs.edit().apply {
            if (prefs.getLong(K_HOUR_START, 0) == 0L) putLong(K_HOUR_START, now)
            if (prefs.getLong(K_DAY_START, 0) == 0L) putLong(K_DAY_START, now)
            putLong(K_HOUR_USED, prefs.getLong(K_HOUR_USED, 0) + seconds)
            putLong(K_DAY_USED, prefs.getLong(K_DAY_USED, 0) + seconds)
        }.apply()
    }

    companion object {
        /**
         * Il lucchetto dei file delle trascrizioni e delle note: uno per tutto il processo. Ognuno ha il suo Store (l'app,
         * la pillola, la coda, i titoli…): con un lucchetto per Store due scritture insieme si perdevano a vicenda, o si
         * mescolavano nello stesso file .tmp (e una storia illeggibile diventava vuota alla scrittura dopo).
         */
        private val BLOCCO = Any()

        const val HOUR_LIMIT = 7200L

        /** Fedele corregge e tiene tutte le parole; Pulita toglie intercalari e ripetizioni, quindi può cambiare di più. */
        const val GUARD_FAITHFUL = 0.35
        const val GUARD_CLEAN = 0.60
        const val DAY_LIMIT = 28800L
        private const val HOUR_MS = 3_600_000L
        private const val DAY_MS = 86_400_000L
        private const val HISTORY_SIZE = 100
        private const val AES = "AES/GCM/NoPadding"
        private const val VAULT_ALIAS = "transcrify_vault"
        private const val K_KEY_IV = "key_iv"
        private const val K_KEY_DATA = "key_data"
        private const val K_HOUR_START = "hour_start"
        private const val K_HOUR_USED = "hour_used"
        private const val K_DAY_START = "day_start"
        private const val K_DAY_USED = "day_used"
    }
}

private fun String.b64(): ByteArray = Base64.decode(this, Base64.NO_WRAP)
private fun ByteArray.b64(): String = Base64.encodeToString(this, Base64.NO_WRAP)
private fun JSONArray.strings(): List<String> = (0 until length()).map(::getString)
