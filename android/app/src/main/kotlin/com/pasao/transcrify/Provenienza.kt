package com.pasao.transcrify

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.core.graphics.drawable.toBitmap
import java.io.File

/**
 * Da quale app arriva un audio condiviso: il suo pacchetto (la «source» salvata con la trascrizione),
 * il suo nome e la sua icona vera. Nome e icona si salvano nel momento in cui l'app ce lo manda:
 * dopo Android potrebbe non farcela più vedere (visibilità dei pacchetti).
 */
object Provenienza {
    private const val WHATSAPP = "com.whatsapp"
    private const val ICONA_PX = 96

    /** Prima di novembre 2026 si salvava solo «whatsapp». */
    fun pacchetto(source: String?): String? = if (source == "whatsapp") WHATSAPP else source

    /**
     * Chi ha mandato [uri]: prima l'app padrona del file (WhatsApp, Telegram… lo servono da un loro
     * archivio), poi l'app che ha aperto il Condividi. Vale solo un'app che si apre dal telefono:
     * così non scambiamo per mittente l'archivio di sistema o il foglio di Condividi di Samsung.
     */
    fun dalCondividi(activity: Activity, uri: Uri): String? {
        val pm = activity.packageManager
        val candidati = listOfNotNull(
            uri.authority?.let { runCatching { pm.resolveContentProvider(it, 0)?.packageName }.getOrNull() },
            activity.referrer?.takeIf { it.scheme == "android-app" }?.host,
        )
        val chi = candidati.firstOrNull { it != activity.packageName && pm.getLaunchIntentForPackage(it) != null } ?: return null
        ricorda(activity, chi)
        return chi
    }

    /** Il nome dell'app («WhatsApp», «Telegram»), o null se non la conosciamo. */
    fun nome(ctx: Context, source: String?): String? {
        val p = pacchetto(source) ?: return null
        return runCatching { File(cartella(ctx), "$p.txt").readText() }.getOrNull()
            ?: runCatching { ctx.packageManager.run { getApplicationLabel(getApplicationInfo(p, 0)).toString() } }.getOrNull()
    }

    /** L'icona dell'app, quadrata, o null se non la conosciamo. */
    fun icona(ctx: Context, source: String?): Bitmap? {
        val p = pacchetto(source) ?: return null
        return File(cartella(ctx), "$p.png").takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) }
            ?: runCatching { ctx.packageManager.getApplicationIcon(p).toBitmap(ICONA_PX, ICONA_PX) }.getOrNull()
    }

    /** Come si presenta un audio condiviso: «Vocale di WhatsApp», «Audio da Registratore», o solo «Audio». */
    fun titolo(ctx: Context, origin: Origin): String {
        val app = nome(ctx, origin.source)
        val base = when {
            app == null -> "Audio"
            origin.vocale -> "Vocale di $app"
            else -> "Audio da $app"
        }
        return base + if (origin.toNote) " · nei Pensieri" else ""
    }

    private fun ricorda(ctx: Context, p: String) = runCatching {
        val pm = ctx.packageManager
        val dir = cartella(ctx)
        File(dir, "$p.txt").writeText(pm.getApplicationLabel(pm.getApplicationInfo(p, 0)).toString())
        File(dir, "$p.png").outputStream().use { pm.getApplicationIcon(p).toBitmap(ICONA_PX, ICONA_PX).compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun cartella(ctx: Context) = File(ctx.filesDir, "provenienze").apply { mkdirs() }
}
