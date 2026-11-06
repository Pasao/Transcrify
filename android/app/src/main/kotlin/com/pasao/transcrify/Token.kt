@file:SuppressLint("RestrictedApi")

package com.pasao.transcrify

import android.annotation.SuppressLint
import android.content.Context
import android.content.res.Configuration
import com.google.android.material.color.utilities.Blend
import com.google.android.material.color.utilities.Hct
import com.google.android.material.color.utilities.MaterialDynamicColors
import com.google.android.material.color.utilities.SchemeFidelity
import com.google.android.material.color.utilities.TonalPalette

/**
 * La FONTE UNICA dei colori di Transcrify: i 28 token del design system (Figma B2), calcolati dal colore
 * scelto nel telefono ([Seme]) con lo stile «Fidelity» di Android. Li usano la pillola, il widget e l'app
 * Flutter (che li riceve da qui): se cambia il colore del telefono, cambia tutto insieme.
 *
 * Lo stesso calcolo di Figma (24-ds-2-stili.calcolo.mjs); TokenTest controlla che i valori coincidano.
 */
data class Token(
    val pagina: Int, val scheda: Int, val isola: Int,
    val testo: Int, val testoSecondario: Int, val linea: Int,
    val azione: Int, val suAzione: Int, val azioneTenue: Int, val suAzioneTenue: Int, val azioneFondo: Int, val suAzioneFondo: Int,
    val successo: Int, val successoTenue: Int, val attenzione: Int, val attenzioneTenue: Int, val errore: Int, val erroreTenue: Int,
    val argomenti: List<Int>,
    val transcriA: Int, val transcriB: Int, val floater: Int, val suFloater: Int,
) {
    /** Per l'app Flutter: nome del token → colore. */
    fun mappa(): Map<String, Any> = mapOf(
        "pagina" to pagina, "scheda" to scheda, "isola" to isola,
        "testo" to testo, "testoSecondario" to testoSecondario, "linea" to linea,
        "azione" to azione, "suAzione" to suAzione, "azioneTenue" to azioneTenue, "suAzioneTenue" to suAzioneTenue, "azioneFondo" to azioneFondo, "suAzioneFondo" to suAzioneFondo,
        "successo" to successo, "successoTenue" to successoTenue, "attenzione" to attenzione, "attenzioneTenue" to attenzioneTenue,
        "errore" to errore, "erroreTenue" to erroreTenue, "argomenti" to argomenti,
        "transcriA" to transcriA, "transcriB" to transcriB, "floater" to floater, "suFloater" to suFloater,
    )

    companion object {
        // L'arancione di Transcri, i colori degli stati e degli argomenti prima di avvicinarli al telefono.
        private const val TRANSCRI = 0xFFF5873C.toInt()
        private const val SUCCESSO = 0xFF1E9E5A.toInt()
        private const val ATTENZIONE = 0xFFD99A00.toInt()
        private const val ERRORE = 0xFFE5432A.toInt()
        private val ARGOMENTI = listOf(0xFFE07A9A, 0xFF8E7CC3, 0xFF5FA778, 0xFF5C93C9, 0xFFC9A24B, 0xFF4FA6A0).map { it.toInt() }

        fun dal(seme: Int, scuro: Boolean): Token {
            val s = SchemeFidelity(Hct.fromInt(seme), scuro, 0.0)
            val m = MaterialDynamicColors()
            // Gli stati: avvicinati di al massimo 15° al telefono, ma l'errore resta rosso (≤32°) e l'attenzione gialla (≥62°).
            fun stato(base: Int, massimo: Double? = null, minimo: Double? = null): TonalPalette {
                var h = Hct.fromInt(Blend.harmonize(base, seme))
                if (massimo != null && h.hue > massimo && h.hue < 120) h = Hct.from(massimo, h.chroma, h.tone)
                if (minimo != null && h.hue < minimo) h = Hct.from(minimo, h.chroma, h.tone)
                return TonalPalette.fromHct(h)
            }
            val ok = stato(SUCCESSO)
            val att = stato(ATTENZIONE, minimo = 62.0)
            val err = stato(ERRORE, massimo = 32.0)
            val pieno = if (scuro) 80 else 40
            val tenue = if (scuro) 30 else 90
            val tr = Hct.fromInt(Blend.harmonize(TRANSCRI, seme))
            return Token(
                // La scheda stacca dalla pagina (6 nov, giro 7: «le schede e lo sfondo sembrano uguali»): non più
                // surfaceContainer (tono 94 / 12) ma il neutro più lontano dalla pagina, 89 di giorno e 18 di notte;
                // almeno 1,25:1 col fondo (TokenTest). Qui ci si stacca da Figma B2, che va aggiornato.
                pagina = m.surface().getArgb(s), scheda = s.neutralPalette.tone(if (scuro) 18 else 89), // L'isola sta SOPRA la pagina: di giorno il bianco più chiaro, di notte il fondo più alto (se no sembra un buco).
                isola = (if (scuro) m.surfaceContainerHighest() else m.surfaceContainerLowest()).getArgb(s),
                testo = m.onSurface().getArgb(s), testoSecondario = m.onSurfaceVariant().getArgb(s), linea = m.outlineVariant().getArgb(s),
                azione = m.primary().getArgb(s), suAzione = m.onPrimary().getArgb(s),
                azioneTenue = m.primaryContainer().getArgb(s), suAzioneTenue = m.onPrimaryContainer().getArgb(s),
                // Il colore del telefono come FONDO grande (il widget): tenue e col tema, scuro di notte. Non azioneTenue:
                // in Fidelity quello è il colore del telefono pari pari, cioè lo stesso arancione di Transcri.
                azioneFondo = s.primaryPalette.tone(tenue), suAzioneFondo = s.primaryPalette.tone(if (scuro) 90 else 10),
                successo = ok.tone(pieno), successoTenue = ok.tone(tenue),
                attenzione = att.tone(pieno), attenzioneTenue = att.tone(tenue),
                errore = err.tone(pieno), erroreTenue = err.tone(tenue),
                argomenti = ARGOMENTI.map { TonalPalette.fromHct(Hct.fromInt(Blend.harmonize(it, seme))).tone(if (scuro) 30 else 90) },
                transcriA = Hct.from(tr.hue, maxOf(tr.chroma, 48.0), 76.0).toInt(),
                transcriB = Hct.from(tr.hue, maxOf(tr.chroma, 56.0), 62.0).toInt(),
                floater = s.neutralPalette.tone(10), suFloater = s.neutralPalette.tone(90),
            )
        }

        /** I token di adesso: colore del telefono e tema chiaro o scuro. */
        fun di(ctx: Context): Token = dal(Seme.di(ctx), scuro(ctx))

        fun scuro(ctx: Context) = (ctx.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    }
}
