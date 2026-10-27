package com.pasao.transcrify

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import androidx.compose.ui.geometry.Rect

/** Come appare un widget: lo sceglie chi lo aggiunge (vedi [WidgetSettings]). */
data class WidgetLook(val style: String = PHONE, val text: Boolean = true, val filled: Boolean = true) {
    companion object {
        const val PHONE = "phone"
        const val LIGHT = "light"
        const val DARK = "dark"

        private fun prefs(context: Context) = context.getSharedPreferences("widgets", Context.MODE_PRIVATE)

        fun of(context: Context, id: Int) = prefs(context).let {
            WidgetLook(it.getString("style_$id", PHONE)!!, it.getBoolean("text_$id", true), it.getBoolean("filled_$id", true))
        }

        fun save(context: Context, id: Int, look: WidgetLook) = prefs(context).edit()
            .putString("style_$id", look.style).putBoolean("text_$id", look.text).putBoolean("filled_$id", look.filled).apply()

        fun forget(context: Context, id: Int) = prefs(context).edit().remove("style_$id").remove("text_$id").remove("filled_$id").apply()
    }
}

/**
 * Il widget: la casa di Transcri sulla schermata home, una pillola come i widget di Samsung.
 * 2 × 1 dice cosa fa ("Detta" / "È fuori"); stretto a 1 × 1, o senza scritta, resta lui al centro.
 * Toccandolo Transcri esce e vola al bordo; se è già fuori, rientra qui.
 */
class TranscriWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)

    /** La casella è cambiata (griglia, rotazione, ridimensionamento): si ridisegna su misura. */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refresh(context)

    override fun onDeleted(context: Context, ids: IntArray) = ids.forEach { WidgetLook.forget(context, it) }

    companion object {
        /** Da questa larghezza (dp) il widget è 2 × 1: il cerchio con lui e, accanto, cosa fa. */
        const val WIDE_FROM_DP = 140f

        /** Ridisegna tutti i widget: Transcri vivo se è a casa, il suo contorno tratteggiato se è fuori. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TranscriWidget::class.java))
            for (id in ids) {
                val look = WidgetLook.of(context, id)
                val away = PillService.running
                // Due disegni, e il launcher sceglie quello che entra nella casella.
                val small = views(context, id, look, away, wide = false)
                val views = if (look.text) {
                    RemoteViews(mapOf(SizeF(40f, 40f) to small, SizeF(WIDE_FROM_DP, 40f) to views(context, id, look, away, wide = true)))
                } else small
                manager.updateAppWidget(id, views)
            }
        }

        private fun views(context: Context, id: Int, look: WidgetLook, away: Boolean, wide: Boolean) =
            RemoteViews(context.packageName, if (wide) R.layout.widget_wide else R.layout.widget_small).apply {
                val (bg, text) = when (look.style) {
                    WidgetLook.LIGHT -> R.drawable.widget_bg_light to R.color.widget_light_text
                    WidgetLook.DARK -> R.drawable.widget_bg_dark to R.color.widget_dark_text
                    else -> R.drawable.widget_bg_phone to R.color.widget_phone_text
                }
                setInt(R.id.widget_root, "setBackgroundResource", if (look.filled) bg else 0)
                // I colori si risolvono nel launcher: lo stile "del telefono" segue anche il tema chiaro/scuro.
                setColorStateList(R.id.widget_title, "setTextColor", text)
                if (wide) {
                    setColorStateList(R.id.widget_line, "setTextColor", text)
                    setTextViewText(R.id.widget_title, if (away) "È fuori" else "Detta")
                    setTextViewText(R.id.widget_line, if (away) "Tocca per richiamarlo" else "Tocca e parla, poi incolla dove vuoi")
                } else {
                    setTextViewText(R.id.widget_title, if (away) "Richiama" else "Detta")
                    setViewVisibility(R.id.widget_title, if (look.text) View.VISIBLE else View.GONE)
                }
                // A casa respira; fuori resta il contorno tratteggiato, fermo.
                setViewVisibility(R.id.widget_breath, if (away) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.widget_away, if (away) View.VISIBLE else View.GONE)
                setOnClickPendingIntent(R.id.widget_root, tap(context, id))
            }

        // Ogni widget passa il suo id: serve per leggere il suo fattore di scala e il suo aspetto (vedi WidgetTrampoline).
        private fun tap(context: Context, id: Int) = PendingIntent.getActivity(
            context, id,
            Intent(context, WidgetTrampoline::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
            // Mutabile di proposito: solo così il launcher può aggiungere il rettangolo del
            // widget (sourceBounds), da cui parte e in cui rientra la bolla.
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}

/**
 * Un'activity invisibile che dura un istante: il tocco sul widget arriva qui con il
 * rettangolo del widget sullo schermo (sourceBounds), e da lì parte o rientra la bolla.
 * Passare da un'activity serve anche perché Android lascia usare il microfono in
 * sottofondo solo a chi è stato avviato mentre l'app era in primo piano.
 */
class WidgetTrampoline : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val bounds = intent.sourceBounds
        val d = resources.displayMetrics.density
        // One UI passa il rettangolo del widget ingrandito del suo fattore di ridimensionamento
        // (hsResizeRatio, per esempio 0,83): l'angolo è giusto, la misura no. Si riporta alla misura vera.
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val ratio = if (id == AppWidgetManager.INVALID_APPWIDGET_ID) 1f
        else (AppWidgetManager.getInstance(this).getAppWidgetOptions(id).get("hsResizeRatio") as? Number)?.toFloat() ?: 1f
        val home = bounds?.let { b ->
            val w = b.width() * ratio
            val h = b.height() * ratio
            val look = if (id == AppWidgetManager.INVALID_APPWIDGET_ID) WidgetLook() else WidgetLook.of(this, id)
            val wide = look.text && w / d >= TranscriWidget.WIDE_FROM_DP
            // Dov'è Transcri nel disegno: nel 2 × 1 a sinistra, grande (10 dp + metà del suo posto da 56),
            // nel 1 × 1 al centro, un po' più su per lasciare posto alla parola sotto.
            val cx = if (wide) b.left + 38f * d * ratio else b.left + w / 2f
            val cy = b.top + h / 2f - if (!wide && look.text) 9f * d * ratio else 0f
            val hw = (if (wide) 26f else 17f) * d * ratio
            val hh = (if (wide) 23f else 15f) * d * ratio
            Rect(cx - hw, cy - hh, cx + hw, cy + hh)
        }
        val pill = PillService.instance?.takeIf { !it.homecoming }
        val ready = Settings.canDrawOverlays(this) &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
            Store(this).apiKey != null
        when {
            pill != null && home != null -> pill.recall(home.center, home)
            // Senza la posizione del widget non c'è dove rientrare: si chiude e basta.
            pill != null -> PillService.stop(this)
            // Manca qualcosa (permessi o chiave): si apre l'app, che sa chiederlo.
            home == null || !ready -> startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            else -> PillService.start(this, home.center.x, home.center.y, floatArrayOf(home.left, home.top, home.right, home.bottom))
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
