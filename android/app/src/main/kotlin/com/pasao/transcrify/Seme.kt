package com.pasao.transcrify

import android.content.Context
import android.provider.Settings
import org.json.JSONObject

/**
 * Il colore scelto nel telefono, il «seme» da cui Android calcola i colori di Material You.
 * Android lo scrive nelle impostazioni (anche One UI): «android.theme.customization.system_palette».
 * Se non c'è, il tono di mezzo dell'accento ci va vicino.
 */
object Seme {
    fun di(ctx: Context): Int {
        try {
            val json = Settings.Secure.getString(ctx.contentResolver, "theme_customization_overlay_packages")
            if (!json.isNullOrBlank()) {
                // Su One UI è scritto con l'alfa davanti («fff1917f»): contano le ultime 6 cifre.
                val hex = JSONObject(json).optString("android.theme.customization.system_palette").removePrefix("#").takeLast(6)
                if (hex.length == 6) return (0xFF000000L or hex.toLong(16)).toInt()
            }
        } catch (_: Exception) {
        }
        return ctx.getColor(android.R.color.system_accent1_500)
    }
}
