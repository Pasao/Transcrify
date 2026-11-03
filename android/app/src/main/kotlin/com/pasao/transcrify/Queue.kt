package com.pasao.transcrify

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * Una registrazione che aspetta di essere trascritta.
 * [mode]: la pulizia scelta quando è stata fatta. [appendTo]: la trascrizione a cui si attacca, se c'è.
 * [origin]: da dove arriva, se viene da fuori. Gli audio condivisi non toccano gli appunti: il testo lo vedi in una notifica.
 */
data class Pending(
    val id: String,
    val audio: File,
    val at: Long,
    val seconds: Long,
    val mode: String?,
    val appendTo: Long? = null,
    val origin: Origin? = null,
    val cursor: Int = -1,
    /** Il vocale a cui stai rispondendo (la carta aperta nel Floater): al pulitore, perché capisca nomi e riferimenti. */
    val contesto: String? = null,
)

/**
 * Un audio arrivato da «Condividi»: [source] è il pacchetto dell'app che lo manda, se si riconosce
 * (nome e icona in [Provenienza]); [vocale] se è un messaggio vocale (Opus/Ogg, come WhatsApp e Telegram).
 */
data class Origin(val source: String?, val toNote: Boolean, val vocale: Boolean = true)

/**
 * Le registrazioni non ancora trascritte. Stanno nei file dell'app, non nella cache:
 * Android non le cancella da solo, e ne escono solo quando la trascrizione è salvata
 * o quando le butti tu. Un audio di 40 minuti non si perde per una rete che manca.
 */
class Queue(context: Context) {
    private val dir = File(Sandbox.dir(context), "queue").apply { mkdirs() }

    @Synchronized
    fun add(src: File, seconds: Long, mode: String?, appendTo: Long? = null, origin: Origin? = null, cursor: Int = -1, contesto: String? = null): Pending {
        val at = System.currentTimeMillis()
        // Più audio condivisi insieme arrivano nello stesso millesimo di secondo.
        var id = at.toString()
        var n = 0
        while (File(dir, "$id.json").exists()) id = "$at-${++n}"
        val audio = File(dir, "$id.${src.extension}")
        if (!src.renameTo(audio)) {
            src.copyTo(audio, overwrite = true)
            src.delete()
        }
        val meta = JSONObject().put("at", at).put("seconds", seconds).put("mode", mode).put("ext", src.extension)
        appendTo?.let { meta.put("appendTo", it).put("cursor", cursor) }
        contesto?.let { meta.put("contesto", it) }
        origin?.let { meta.put("shared", true).put("source", it.source).put("toNote", it.toNote).put("vocale", it.vocale) }
        File(dir, "$id.json").writeText(meta.toString())
        return Pending(id, audio, at, seconds, mode, appendTo, origin, cursor, contesto)
    }

    /** Dalla più vecchia alla più nuova. */
    @Synchronized
    fun all(): List<Pending> = dir.listFiles { f -> f.extension == "json" }.orEmpty().mapNotNull { meta ->
        runCatching {
            val j = JSONObject(meta.readText())
            val id = meta.nameWithoutExtension
            Pending(
                id, File(dir, "$id.${j.optString("ext", "m4a")}"), j.getLong("at"), j.optLong("seconds"),
                if (j.isNull("mode")) null else j.getString("mode"),
                if (j.has("appendTo")) j.getLong("appendTo") else null,
                if (j.optBoolean("shared")) Origin(if (j.isNull("source")) null else j.getString("source"), j.optBoolean("toNote"), j.optBoolean("vocale", true)) else null,
                j.optInt("cursor", -1),
                if (j.has("contesto")) j.getString("contesto") else null,
            )
        }.getOrNull()
    }.filter { it.audio.exists() }.sortedWith(compareBy({ it.at }, { it.id }))

    @Synchronized
    fun remove(id: String) {
        dir.listFiles { f -> f.nameWithoutExtension == id }.orEmpty().forEach { it.delete() }
    }
}

/** Trascrive una registrazione in coda. Lo usano sia Transcri sia l'app (quando Transcri è chiuso). */
class Transcriber(private val context: Context, private val store: Store, private val queue: Queue) {
    private val impronte = Impronte(context, store)

    sealed interface Outcome {
        /** Fatto; [result] è null se non c'era niente da trascrivere (silenzio). */
        data class Done(val result: Transcription?) : Outcome
        data object Offline : Outcome
        data class Failed(val message: String) : Outcome
    }

    /** Bloccante: va chiamato fuori dal thread principale. */
    fun run(item: Pending): Outcome {
        // Un vocale condiviso già trascritto (stessa impronta, stessa pulizia): si riprende quella, senza chiamate.
        val impronta = if (item.origin != null) runCatching { impronte.di(item.audio) }.getOrNull() else null
        impronta?.let { impronte.cerca(it, item.mode) }?.let { già ->
            queue.remove(item.id)
            return Outcome.Done(già)
        }
        val key = store.apiKey ?: return Outcome.Failed("Manca la chiave Groq")
        val work = File(context.cacheDir, "pezzi-${item.id}")
        return try {
            val groq = Groq(key)
            // Un audio troppo grande, o in un formato che Groq non prende, si converte e si divide nei silenzi.
            val pieces = try {
                AudioPieces.of(item.audio, work)
            } catch (e: Exception) {
                return Outcome.Failed("Questo audio non si apre")
            }
            var text = collapseLoops(pieces.joinToString(" ") { groq.transcribe(it, store.transcriptionModel) }.trim())
            store.saveModelLimits(store.transcriptionModel, groq.lastLimits)
            store.countUse(store.transcriptionModel)
            var cleaned = false
            if (text.isNotEmpty() && item.mode != null) {
                // Se la pulizia fallisce si tiene il testo grezzo: meglio di niente.
                runCatching { groq.cleanLong(text, store.cleanupModel, conContesto(store.promptFor(item.mode), item.contesto), store.words, store.guardFor(item.mode)) }
                    .onSuccess { text = it; cleaned = true; store.countUse(store.cleanupModel) }
                store.saveModelLimits(store.cleanupModel, groq.lastLimits)
            }
            val result = if (isHallucination(text)) null else deliver(item, text, cleaned)
            if (result != null && impronta != null) impronte.ricorda(impronta, item.mode, result)
            store.addUsage(item.seconds)
            queue.remove(item.id)
            Outcome.Done(result)
        } catch (e: GroqError) {
            if (e.offline) Outcome.Offline else Outcome.Failed(e.message ?: "Errore")
        } finally {
            work.deleteRecursively()
        }
    }

    /** Un titolo per la nota, se si riesce: il testo non deve dipendere da questo. */
    fun titleFor(text: String): String {
        val key = store.apiKey ?: return ""
        return runCatching { Groq(key).title(text, store.cleanupModel) }.onSuccess { store.countUse(store.cleanupModel) }.getOrDefault("")
    }

    /** Il testo va dove deve: in fondo a una trascrizione, in una nota nuova o in una trascrizione nuova. */
    private fun deliver(item: Pending, text: String, cleaned: Boolean): Transcription {
        val now = System.currentTimeMillis()
        val mode = if (cleaned) item.mode else null
        item.appendTo?.let { at -> store.addToEntry(at, text, item.cursor)?.let { return it } }
        val source = item.origin?.source
        if (item.origin?.toNote == true) {
            val id = "$now-${item.id}"
            // Un titolo fa ritrovare la nota; se non arriva, resta senza.
            val title = titleFor(text)
            store.saveNote(Note(id, title, text, now, now, source))
            NoteTopicsWorker.get(context).request(id)
            return Transcription(text, now, cleaned, mode, source, noteId = id)
        }
        return Transcription(text, now, cleaned, mode, source).also { store.addToHistory(it) }
    }

    /** Whisper a volte s'incanta e ripete la stessa parola: più di tre volte di fila ne resta una. */
    private fun collapseLoops(text: String): String =
        text.replace(Regex("""(?i)\b(\p{L}[\p{L}'’]*)(?:[\s,.;:!?]+\1\b){3,}"""), "$1")

    /** Frasi che Whisper scrive quando sente solo silenzio o rumore: si buttano. */
    private fun isHallucination(text: String): Boolean {
        val t = text.lowercase().trim().trimEnd('.', '!', ' ')
        return t.length < 2 || HALLUCINATIONS.any { t.contains(it) && t.length < it.length + 25 }
    }

    companion object {
        private val HALLUCINATIONS = listOf(
            "sottotitoli creati dalla comunità amara.org",
            "sottotitoli a cura di",
            "grazie per la visione",
            "grazie per l'attenzione",
            "iscriviti al canale",
            "thanks for watching",
            "thank you for watching",
            "subtitles by",
        )
    }
}

/**
 * Le istruzioni del pulitore, più il vocale a cui stai rispondendo, se c'è: serve a capire nomi e riferimenti,
 * non a rispondere al posto tuo.
 */
fun conContesto(prompt: String, contesto: String?): String = if (contesto.isNullOrBlank()) prompt else prompt + """

Contesto: chi detta sta rispondendo a questo messaggio vocale che ha ricevuto: «$contesto».
Usalo solo per capire nomi, luoghi e riferimenti nel testo dettato. Non rispondere al messaggio e non aggiungere niente: pulisci solo il testo dettato."""
