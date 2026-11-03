package com.pasao.transcrify

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

/**
 * Gli audio condivisi già trascritti (sua idea, 3 nov): per ogni file un'impronta (SHA-256 del contenuto) e la pulizia
 * scelta, e QUALE trascrizione (o nota) ne è uscita. Nessuna copia del testo: se condividi di nuovo lo stesso vocale
 * e quella trascrizione c'è ancora, si riprende da lì (niente seconda chiamata a Groq, nessun doppione); se l'hai
 * cancellata, si ritrascrive e torna tra le trascrizioni. Tiene gli ultimi [MASSIMO].
 */
class Impronte(context: Context, private val store: Store) {
    private val file = File(Sandbox.dir(context), "impronte-v2.json")

    init {
        // La prima versione teneva anche il testo: via, non deve restarne una copia nascosta.
        File(Sandbox.dir(context), "impronte.json").delete()
    }

    /** L'impronta del contenuto di [audio]: lo stesso vocale, anche con un altro nome, dà la stessa. */
    fun di(audio: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        audio.inputStream().use { input ->
            val buf = ByteArray(BLOCCO)
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    /** La trascrizione (o la nota) già fatta da questo vocale, se c'è ancora. */
    @Synchronized
    fun cerca(impronta: String, mode: String?): Transcription? {
        val j = tutte().optJSONObject(chiave(impronta, mode)) ?: return null
        val noteId = j.optString("noteId").ifEmpty { null }
        if (noteId != null) {
            return store.notes().firstOrNull { it.id == noteId }?.let { Transcription(it.text, it.created, mode != null, mode, it.source, noteId = it.id) }
        }
        val at = j.optLong("at")
        return store.history().firstOrNull { it.at == at }
    }

    @Synchronized
    fun ricorda(impronta: String, mode: String?, t: Transcription) {
        val tutte = tutte()
        tutte.put(chiave(impronta, mode), JSONObject().put("at", t.at).put("noteId", t.noteId))
        // Le più vecchie escono: l'ordine di inserimento è quello delle chiavi.
        val chiavi = tutte.keys().asSequence().toList()
        chiavi.take((chiavi.size - MASSIMO).coerceAtLeast(0)).forEach { tutte.remove(it) }
        file.writeText(tutte.toString())
    }

    private fun tutte(): JSONObject = runCatching { JSONObject(file.readText()) }.getOrDefault(JSONObject())

    private fun chiave(impronta: String, mode: String?) = "$impronta|${mode ?: "grezza"}"

    private companion object {
        const val MASSIMO = 300
        const val BLOCCO = 64 * 1024
    }
}
