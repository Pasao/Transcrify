package com.pasao.transcrify

import android.content.Context
import android.content.pm.ApplicationInfo
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * I dati finti, solo nella versione di sviluppo: con lo switch acceso l'app legge e scrive in una
 * cartella a parte, con note e trascrizioni inventate. Quelle vere non vengono né lette né toccate,
 * e nemmeno gli appunti. Spegnendolo la cartella finta si butta: la prossima volta si riparte puliti.
 * Tutto passa da [dir], e cambiare richiede di riavviare l'app (vedi MainActivity).
 */
object Sandbox {
    private fun marker(context: Context) = File(context.filesDir, "usa_dati_finti")
    private fun folder(context: Context) = File(context.filesDir, "dati_finti")

    fun on(context: Context): Boolean =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 && marker(context).exists()

    /** Dove stanno i dati dell'utente: quella vera o quella finta. */
    fun dir(context: Context): File {
        if (!on(context)) return context.filesDir
        val folder = folder(context)
        if (!folder.exists()) {
            folder.mkdirs()
            seed(folder)
        }
        return folder
    }

    fun set(context: Context, on: Boolean) {
        if (on) {
            marker(context).createNewFile()
        } else {
            marker(context).delete()
            folder(context).deleteRecursively()
        }
    }

    private fun seed(folder: File) {
        val now = System.currentTimeMillis()
        val hour = 3_600_000L
        // Alcune con un colore («tinta:luce», vedi Tinte nell'app) e una privata, per provare cartelle e lucchetto.
        fun entry(text: String, ago: Long, mode: String?, source: String? = null, colore: String? = null, privata: Boolean = false) = JSONObject()
            .put("text", text).put("at", now - ago * hour).put("purified", mode != null).put("mode", mode).put("source", source)
            .put("colore", colore).put("privata", privata)
        File(folder, "history.json").writeText(
            JSONArray(
                listOf(
                    entry("Ciao, arrivo alle otto. Se ti serve qualcosa dal supermercato scrivimi prima delle sette.", 1, "pulita", colore = "0:4"),
                    entry("Il messaggio per il condominio: la riunione è spostata a giovedì alle 21, nella sala al piano terra.", 3, "pulita", colore = "4:4", privata = true),
                    entry("Vocale finto: domani passo a prendere le chiavi, poi andiamo insieme a vedere la macchina.", 5, "fedele", "whatsapp"),
                    entry("Ricordarsi di chiamare il meccanico.", 26, null, colore = "0:4"),
                    entry("Prova di un testo più lungo per vedere come sta nella scheda. " + "Una frase in più per riempire lo spazio. ".repeat(8), 30, "pulita"),
                ) + (2..40).map { day ->
                    entry("Trascrizione finta di $day giorni fa: la ferramenta chiude alle sette.", day * 24L + 3, "fedele", colore = if (day % 5 == 0) "3:4" else null)
                }
            ).toString()
        )
        fun note(id: String, title: String, text: String, ago: Long, source: String? = null, summary: String? = null) = JSONObject()
            .put("id", id).put("title", title).put("text", text).put("created", now - ago * hour).put("updated", now - ago * hour)
            .put("source", source).put("summary", summary)
        val long = (1..6).joinToString("\n\n") {
            "Paragrafo finto numero $it. Il treno delle nove è in ritardo e la stazione è piena di persone con le valigie. " +
                "Al bar servono il caffè in tazze di carta, e fuori comincia a piovere. Nessuno sa dire quando si riparte."
        }
        File(folder, "notes.json").writeText(
            JSONArray(
                listOf(
                    note("finta-vocale", "Il viaggio in treno", long, 1, "whatsapp", "- Il treno è in ritardo.\n- Piove e nessuno sa quando si riparte."),
                    note("finta-spesa", "Spesa", "• Pane\n• Latte\n• Dentifricio\n• Caffè", 4),
                    note("finta-breve", "", "Un'idea senza titolo: una lampada che si accende quando arriva il corriere.", 28),
                    note(
                        "finta-progetto", "Il progetto del giardino",
                        "Il giardino va diviso in tre parti. L'orto sta sul lato dove batte il sole. " +
                            "Vicino al muro metto i pomodori e le zucchine. Poi serve un impianto per l'acqua, con un timer. " +
                            "Il budget è di trecento euro, e i semi costano poco. https://esempio.it/semi",
                        50,
                    ),
                )
            ).toString()
        )
    }
}
