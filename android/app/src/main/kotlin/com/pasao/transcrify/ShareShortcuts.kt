package com.pasao.transcrify

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon

/**
 * Le due scorciatoie del «Condividi», «Transcrify trascrizione» e «Transcrify pensiero»: Android le
 * mostra una accanto all'altra, così basta un tocco. Dal launcher aprono semplicemente l'app.
 */
object ShareShortcuts {
    fun publish(context: Context) {
        val open = Intent(context, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
        fun shortcut(id: String, label: String, category: String, icon: Int) = ShortcutInfo.Builder(context, id)
            .setShortLabel(label)
            .setLongLived(true)
            .setCategories(setOf("com.pasao.transcrify.category.$category"))
            .setIcon(Icon.createWithResource(context, icon))
            .setIntent(open)
            .build()
        context.getSystemService(ShortcutManager::class.java)?.dynamicShortcuts = listOf(
            shortcut("trascrizione", "Transcrify trascrizione", "TRANSCRIPTION", R.drawable.ic_share_transcription),
            shortcut("pensiero", "Transcrify pensiero", "THOUGHT", R.drawable.ic_share_thought),
        )
    }
}
