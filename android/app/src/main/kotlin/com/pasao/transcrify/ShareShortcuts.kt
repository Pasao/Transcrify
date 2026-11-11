package com.pasao.transcrify

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon

/**
 * Nel «Condividi» c'è solo «Trascrivi» (10 nov, suo): tra le app (`ShareAsTranscription`) e come scorciatoia in cima,
 * tra i contatti (la condivisione diretta, `share_shortcuts.xml`). Niente più «Transcrify nota»: quella di prima si
 * ritira, Android la terrebbe a lungo accanto all'app. Dal launcher la scorciatoia apre semplicemente l'app.
 */
object ShareShortcuts {
    private const val TRASCRIZIONE = "trascrizione"
    private val VECCHIE = listOf("pensiero")

    fun publish(context: Context) {
        val sm = context.getSystemService(ShortcutManager::class.java) ?: return
        val trascrivi = ShortcutInfo.Builder(context, TRASCRIZIONE)
            .setShortLabel("Trascrivi")
            .setLongLived(true)
            .setCategories(setOf("com.pasao.transcrify.category.TRANSCRIPTION"))
            .setIcon(Icon.createWithResource(context, R.drawable.ic_share_transcription))
            .setIntent(Intent(context, MainActivity::class.java).setAction(Intent.ACTION_MAIN))
            .build()
        runCatching {
            sm.removeLongLivedShortcuts(VECCHIE)
            sm.dynamicShortcuts = listOf(trascrivi)
        }
    }
}
