package com.pasao.transcrify

import android.content.Context
import org.json.JSONObject
import java.io.File

/** Una registrazione che aspetta di essere trascritta. [mode]: la pulizia scelta quando è stata fatta. */
data class Pending(val id: String, val audio: File, val at: Long, val seconds: Long, val mode: String?)

/**
 * Le registrazioni non ancora trascritte. Stanno nei file dell'app, non nella cache:
 * Android non le cancella da solo, e ne escono solo quando la trascrizione è salvata
 * o quando le butti tu. Un audio di 40 minuti non si perde per una rete che manca.
 */
class Queue(context: Context) {
    private val dir = File(context.filesDir, "queue").apply { mkdirs() }

    @Synchronized
    fun add(src: File, seconds: Long, mode: String?): Pending {
        val at = System.currentTimeMillis()
        val id = at.toString()
        val audio = File(dir, "$id.m4a")
        if (!src.renameTo(audio)) {
            src.copyTo(audio, overwrite = true)
            src.delete()
        }
        File(dir, "$id.json").writeText(JSONObject().put("at", at).put("seconds", seconds).put("mode", mode).toString())
        return Pending(id, audio, at, seconds, mode)
    }

    /** Dalla più vecchia alla più nuova. */
    @Synchronized
    fun all(): List<Pending> = dir.listFiles { f -> f.extension == "json" }.orEmpty().mapNotNull { meta ->
        runCatching {
            val j = JSONObject(meta.readText())
            val id = meta.nameWithoutExtension
            Pending(id, File(dir, "$id.m4a"), j.getLong("at"), j.optLong("seconds"), if (j.isNull("mode")) null else j.getString("mode"))
        }.getOrNull()
    }.filter { it.audio.exists() }.sortedBy { it.at }

    @Synchronized
    fun remove(id: String) {
        File(dir, "$id.m4a").delete()
        File(dir, "$id.json").delete()
    }
}

/** Trascrive una registrazione in coda. Lo usano sia Transcri sia l'app (quando Transcri è chiuso). */
class Transcriber(private val store: Store, private val queue: Queue) {
    sealed interface Outcome {
        /** Fatto; [result] è null se non c'era niente da trascrivere (silenzio). */
        data class Done(val result: Transcription?) : Outcome
        data object Offline : Outcome
        data class Failed(val message: String) : Outcome
    }

    /** Bloccante: va chiamato fuori dal thread principale. */
    fun run(item: Pending): Outcome {
        val key = store.apiKey ?: return Outcome.Failed("Manca la chiave Groq")
        return try {
            val groq = Groq(key)
            var text = collapseLoops(groq.transcribe(item.audio, store.transcriptionModel))
            store.saveModelLimits(store.transcriptionModel, groq.lastLimits)
            store.countUse(store.transcriptionModel)
            var cleaned = false
            if (text.isNotEmpty() && item.mode != null) {
                // Se la pulizia fallisce si tiene il testo grezzo: meglio di niente.
                runCatching { groq.clean(text, store.cleanupModel, store.promptFor(item.mode), store.words) }
                    .onSuccess { text = it; cleaned = true; store.countUse(store.cleanupModel) }
                store.saveModelLimits(store.cleanupModel, groq.lastLimits)
            }
            val result = if (isHallucination(text)) null
            else Transcription(text, System.currentTimeMillis(), cleaned, if (cleaned) item.mode else null)
            result?.let { store.addToHistory(it) }
            store.addUsage(item.seconds)
            queue.remove(item.id)
            Outcome.Done(result)
        } catch (e: GroqError) {
            if (e.offline) Outcome.Offline else Outcome.Failed(e.message ?: "Errore")
        }
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
