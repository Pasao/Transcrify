package com.pasao.transcrify

import android.content.SharedPreferences

/**
 * Le «Prove» che servono anche alla parte nativa (solo nella versione di sviluppo): i guasti finti, per vedere
 * com'è l'app quando manca la rete, quando Groq rifiuta la chiave, quando il microfono non è concesso, senza
 * doverli provocare davvero; e le scelte da confrontare (il successo «l'ultimo respiro» o quello di prima).
 * Si ricordano nelle preferenze: valgono anche quando la pillola parte da sola.
 */
object Simulated {
    @Volatile var offline = false
    @Volatile var badKey = false
    @Volatile var noMic = false

    /** Il successo: «l'ultimo respiro» (acceso, la sua scelta del 5 nov) o il salto di prima (spento). */
    @Volatile var respiro = true

    private var prefs: SharedPreferences? = null

    /** Il nome di ogni prova (quello che manda l'app) → la sua chiave nelle preferenze e il valore di base. */
    private val chiavi = mapOf(
        "offline" to ("sim_offline" to false),
        "badKey" to ("sim_badkey" to false),
        "noMic" to ("sim_nomic" to false),
        "respiro" to ("prova_respiro" to true),
    )

    fun load(p: SharedPreferences) {
        prefs = p
        chiavi.forEach { (what, kv) -> metti(what, p.getBoolean(kv.first, kv.second)) }
    }

    fun set(what: String, on: Boolean) {
        val (chiave, _) = chiavi[what] ?: return
        metti(what, on)
        prefs?.edit()?.putBoolean(chiave, on)?.apply()
    }

    private fun metti(what: String, on: Boolean) {
        when (what) {
            "offline" -> offline = on
            "badKey" -> badKey = on
            "noMic" -> noMic = on
            else -> respiro = on
        }
    }
}
