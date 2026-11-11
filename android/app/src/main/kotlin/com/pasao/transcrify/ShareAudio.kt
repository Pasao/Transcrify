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
 * Un audio condiviso da un'altra app, per esempio un vocale di WhatsApp: una sola voce nel Condividi,
 * «Trascrivi» (10 nov, suo: niente più «Transcrify nota»). Non si vede niente: l'audio entra subito nella
 * coda, così non si perde, e Transcri ci lavora mentre tu resti dove sei. Se qualcosa non è ancora pronto
 * (il file dell'altra app, la chiave nel Keystore) si aspetta un poco ([Pronto]) invece di dare errore.
 */
class ShareAudio : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uris = sharedUris()
        val store = Store(this)
        thread {
            val queue = Queue(this)
            for (uri in uris) Pronto.attendi { enqueue(uri, store, queue) }
            val chiave = store.chiavePronta()
            runOnUiThread {
                // Senza chiave non si può trascrivere: l'audio resta in coda e l'app la chiede.
                if (chiave == null) {
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

    /** Copia l'audio e lo mette in coda; se il file non si legge ancora, la copia a metà si butta (e si riprova). */
    private fun enqueue(uri: Uri, store: Store, queue: Queue): Pending {
        val copy = File(Sandbox.dir(this), "condiviso-${System.nanoTime()}.${extensionOf(uri)}")
        try {
            contentResolver.openInputStream(uri)!!.use { input -> copy.outputStream().use { input.copyTo(it) } }
        } catch (e: Exception) {
            copy.delete()
            throw e
        }
        val mode = if (store.purify) store.cleanMode else null
        val vocale = copy.extension in VOCALI
        return queue.add(copy, secondsOf(copy), mode, origin = Origin(Provenienza.dalCondividi(this, uri), toNote = false, vocale))
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

    private companion object {
        /** I messaggi vocali (WhatsApp, Telegram, Signal…) sono Opus dentro un Ogg. */
        val VOCALI = setOf("ogg", "opus", "oga")
    }

    private fun secondsOf(file: File): Long = runCatching {
        MediaMetadataRetriever().run {
            setDataSource(file.absolutePath)
            val ms = extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            release()
            ms / 1000
        }
    }.getOrDefault(0)
}
