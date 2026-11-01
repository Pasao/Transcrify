package com.pasao.transcrify

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import kotlin.concurrent.thread

/**
 * Un audio condiviso da un'altra app, per esempio un vocale di WhatsApp. Compare due volte nel «Condividi»:
 * come trascrizione o come pensiero (vedi gli alias nel manifest). Non si vede niente: l'audio entra
 * subito nella coda, così non si perde, e Transcri ci lavora mentre tu resti dove sei.
 */
class ShareAudio : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uris = sharedUris()
        val toNote = intent.component?.className?.endsWith(THOUGHT) == true
        val store = Store(this)
        thread {
            val queue = Queue(this)
            for (uri in uris) runCatching { enqueue(uri, toNote, store, queue) }
            runOnUiThread {
                // Senza chiave non si può trascrivere: l'audio resta in coda e l'app la chiede.
                if (store.apiKey == null) {
                    startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } else if (uris.isNotEmpty()) {
                    PillService.workShared(this)
                }
                finish()
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun sharedUris(): List<Uri> = when (intent.action) {
        Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM))
        Intent.ACTION_SEND_MULTIPLE -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        else -> emptyList()
    }

    private fun enqueue(uri: Uri, toNote: Boolean, store: Store, queue: Queue) {
        val copy = File(filesDir, "condiviso-${System.nanoTime()}.${extensionOf(uri)}")
        contentResolver.openInputStream(uri)!!.use { input -> copy.outputStream().use { input.copyTo(it) } }
        // Una trascrizione usa la pulizia che hai scelto; un pensiero resta fedele, poi puoi riassumerlo dalla nota.
        val mode = if (toNote) "fedele" else if (store.purify) store.cleanMode else null
        queue.add(copy, secondsOf(copy), mode, origin = Origin(sourceOf(uri), toNote))
    }

    private fun extensionOf(uri: Uri): String {
        val name = runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0) else null
            }
        }.getOrNull() ?: uri.lastPathSegment.orEmpty()
        return name.substringAfterLast('.', "").lowercase().takeIf { it.length in 2..5 }
            ?: contentResolver.getType(uri)?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?: "audio"
    }

    /** I vocali di WhatsApp arrivano dal suo archivio, e l'indirizzo lo dice. */
    private fun sourceOf(uri: Uri): String? {
        val from = "${uri.authority} ${referrer?.host}".lowercase()
        return if ("whatsapp" in from) "whatsapp" else null
    }

    private fun secondsOf(file: File): Long = runCatching {
        MediaMetadataRetriever().run {
            setDataSource(file.absolutePath)
            val ms = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            release()
            ms / 1000
        }
    }.getOrDefault(0)

    private companion object {
        const val THOUGHT = "ShareAsThought"
    }
}
