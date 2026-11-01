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
)

/** Un audio arrivato da «Condividi»: [source] è l'app che lo manda ("whatsapp"), se si riconosce. */
data class Origin(val source: String?, val toNote: Boolean)

/**
 * Le registrazioni non ancora trascritte. Stanno nei file dell'app, non nella cache:
 * Android non le cancella da solo, e ne escono solo quando la trascrizione è salvata
 * o quando le butti tu. Un audio di 40 minuti non si perde per una rete che manca.
 */
class Queue(context: Context) {
    private val dir = File(context.filesDir, "queue").apply { mkdirs() }

    @Synchronized
    fun add(src: File, seconds: Long, mode: String?, appendTo: Long? = null, origin: Origin? = null): Pending {
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
        appendTo?.let { meta.put("appendTo", it) }
        origin?.let { meta.put("shared", true).put("source", it.source).put("toNote", it.toNote) }
        File(dir, "$id.json").writeText(meta.toString())
        return Pending(id, audio, at, seconds, mode, appendTo, origin)
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
                if (j.optBoolean("shared")) Origin(if (j.isNull("source")) null else j.getString("source"), j.optBoolean("toNote")) else null,
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
    sealed interface Outcome {
        /** Fatto; [result] è null se non c'era niente da trascrivere (silenzio). */
        data class Done(val result: Transcription?) : Outcome
        data object Offline : Outcome
        data class Failed(val message: String) : Outcome
    }

    /** Bloccante: va chiamato fuori dal thread principale. */
    fun run(item: Pending): Outcome {
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
                runCatching { groq.cleanLong(text, store.cleanupModel, store.promptFor(item.mode), store.words) }
                    .onSuccess { text = it; cleaned = true; store.countUse(store.cleanupModel) }
                store.saveModelLimits(store.cleanupModel, groq.lastLimits)
            }
            val result = if (isHallucination(text)) null else deliver(item, text, cleaned)
            store.addUsage(item.seconds)
            queue.remove(item.id)
            Outcome.Done(result)
        } catch (e: GroqError) {
            if (e.offline) Outcome.Offline else Outcome.Failed(e.message ?: "Errore")
        } finally {
            work.deleteRecursively()
        }
    }

    /** Il testo va dove deve: in fondo a una trascrizione, in una nota nuova o in una trascrizione nuova. */
    private fun deliver(item: Pending, text: String, cleaned: Boolean): Transcription {
        val now = System.currentTimeMillis()
        val mode = if (cleaned) item.mode else null
        item.appendTo?.let { at -> store.appendToEntry(at, text)?.let { return it } }
        val source = item.origin?.source
        if (item.origin?.toNote == true) {
            val id = "$now-${item.id}"
            store.saveNote(Note(id, "", text, now, now, source))
            NoteTopicsWorker.get(context).request(id)
            return Transcription(text, now, cleaned, mode, source)
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
