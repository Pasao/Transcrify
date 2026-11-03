package com.pasao.transcrify

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader

/**
 * I colori del widget, dai token (la fonte unica): il fondo, il testo e i due toni di Transcri.
 * Li usano il widget (TranscriWidget) e la sua anteprima (WidgetSettings): sono gli stessi per costruzione.
 *
 * - «Del telefono»: il colore del telefono come fondo, tenue e col tema (azioneFondo / suAzioneFondo);
 * - «Chiaro» e «Scuro»: la pagina chiara o la scheda scura, col loro testo.
 */
data class WidgetColori(val fondo: Int, val fondoFine: Int, val testo: Int, val transcriA: Int, val transcriB: Int) {
    companion object {
        fun di(ctx: Context, style: String): WidgetColori {
            val seme = Seme.di(ctx)
            val t = when (style) {
                WidgetLook.LIGHT -> Token.dal(seme, scuro = false)
                WidgetLook.DARK -> Token.dal(seme, scuro = true)
                else -> Token.di(ctx)
            }
            val (fondo, testo) = when (style) {
                WidgetLook.LIGHT -> t.pagina to t.testo
                WidgetLook.DARK -> t.scheda to t.testo
                else -> t.azioneFondo to t.suAzioneFondo
            }
            // Il fondo è un gradiente in orizzontale, dentro la stessa famiglia: dal colore al suo tono verso la pagina.
            return WidgetColori(fondo, androidx.core.graphics.ColorUtils.blendARGB(fondo, t.pagina, 0.45f), testo, t.transcriA, t.transcriB)
        }
    }

    /** Il gradiente del fondo, da stendere dietro al contenuto (la pillola lo ritaglia). */
    fun sfondo(): Bitmap {
        val b = Bitmap.createBitmap(64, 4, Bitmap.Config.ARGB_8888)
        val p = Paint().apply { shader = LinearGradient(0f, 0f, 64f, 0f, fondo, fondoFine, Shader.TileMode.CLAMP) }
        Canvas(b).drawRect(0f, 0f, 64f, 4f, p)
        return b
    }

    /**
     * Transcri per il widget: il suo corpo (34 × 30, angoli 13) coi due toni dall'alto in basso, e gli occhi bianchi.
     * Disegnato come immagine perché il launcher non sa colorare un gradiente da codice. [px]: quanti pixel per dp.
     */
    fun transcri(px: Float): Bitmap {
        val w = 34f * px
        val h = 30f * px
        val b = Bitmap.createBitmap(w.toInt().coerceAtLeast(1), h.toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val corpo = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = LinearGradient(0f, 0f, 0f, h, transcriA, transcriB, Shader.TileMode.CLAMP) }
        c.drawRoundRect(RectF(0f, 0f, w, h), 13f * px, 13f * px, corpo)
        val occhio = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE } // ds:eccezione: gli occhi di Transcri
        for (x in listOf(9.9f, 21.5f)) c.drawOval(RectF(x * px, 9.2f * px, (x + 2.6f) * px, 12.3f * px), occhio)
        return b
    }
}
