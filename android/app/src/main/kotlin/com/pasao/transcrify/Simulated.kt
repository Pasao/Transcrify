package com.pasao.transcrify

import android.content.SharedPreferences

/**
 * I guasti finti delle «Prove» (solo nella versione di sviluppo): per vedere com'è l'app quando
 * manca la rete, quando Groq rifiuta la chiave, quando il microfono non è concesso, senza doverli
 * provocare davvero. Si ricordano nelle preferenze: valgono anche quando la pillola parte da sola.
 */
object Simulated {
    @Volatile var offline = false
    @Volatile var badKey = false
    @Volatile var noMic = false

    private var prefs: SharedPreferences? = null

    fun load(p: SharedPreferences) {
        prefs = p
        offline = p.getBoolean("sim_offline", false)
        badKey = p.getBoolean("sim_badkey", false)
        noMic = p.getBoolean("sim_nomic", false)
    }

    fun set(what: String, on: Boolean) {
        when (what) {
            "offline" -> offline = on
            "badKey" -> badKey = on
            "noMic" -> noMic = on
            else -> return
        }
        prefs?.edit()?.putBoolean(
            when (what) {
                "offline" -> "sim_offline"
                "badKey" -> "sim_badkey"
                else -> "sim_nomic"
            },
            on,
        )?.apply()
    }
}
