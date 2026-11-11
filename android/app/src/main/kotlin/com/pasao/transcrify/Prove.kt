package com.pasao.transcrify

import android.content.Context
import android.content.pm.ApplicationInfo
import java.io.File

/**
 * Le prove (Impostazioni → Prove, i dati finti): nella versione di sviluppo ci sono sempre; in quella vera solo dopo
 * dieci tocchi sulla versione, in fondo alle Impostazioni (11 nov, suo: «come le opzioni sviluppatore»). Lo sblocco è
 * un file nella cartella vera dell'app; «Nascondi le prove» lo toglie. Un posto solo: lo usano le Impostazioni (dal
 * canale, `state`) e i dati finti ([Sandbox]).
 */
object Prove {
    private fun sblocco(context: Context) = File(context.filesDir, "prove_sbloccate")

    fun sviluppo(context: Context) = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    /** Sbloccate coi dieci tocchi (si possono nascondere di nuovo). */
    fun sbloccate(context: Context) = sblocco(context).exists()

    /** Le prove si vedono (e i dati finti si possono usare). */
    fun visibili(context: Context) = sviluppo(context) || sbloccate(context)

    fun sblocca(context: Context, on: Boolean) {
        if (on) sblocco(context).createNewFile() else sblocco(context).delete()
    }
}
