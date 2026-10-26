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
import android.widget.RemoteViews
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect

/**
 * Il widget: la casa di Transcri sulla schermata home. Toccandolo Transcri esce dal widget
 * e vola al bordo; se è già fuori, rientra nel widget. Mentre è fuori la casa è tratteggiata.
 */
class TranscriWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)

    /** La casella è cambiata (griglia, rotazione, ridimensionamento): il quadrato si rifà su misura. */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refresh(context)

    companion object {
        /** Ridisegna tutti i widget: capsula piena se Transcri è a casa, tratteggiata se è fuori. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TranscriWidget::class.java))
            if (ids.isEmpty()) return
            for (id in ids) {
            // Ogni widget passa il suo id: serve per leggere il suo fattore di scala (vedi WidgetTrampoline).
            val tap = PendingIntent.getActivity(
                context, id,
                Intent(context, WidgetTrampoline::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id),
                // Mutabile di proposito: solo così il launcher può aggiungere il rettangolo del
                // widget (sourceBounds), da cui parte e in cui rientra la bolla.
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            // Il quadrato riempie la casella come gli altri widget: il lato più corto della casella
            // vera (misure in dp riportate dal fattore di scala di One UI, se c'è).
            val opts = manager.getAppWidgetOptions(id)
            val ratio = (opts.get("hsResizeRatio") as? Number)?.toFloat() ?: 1f
            val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) * ratio
            val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) * ratio
            val side = (if (w > 0 && h > 0) minOf(w, h) else 64f).coerceIn(48f, 96f)
            val views = RemoteViews(context.packageName, R.layout.widget_transcri).apply {
                setViewLayoutWidth(R.id.widget_square, side, android.util.TypedValue.COMPLEX_UNIT_DIP)
                setViewLayoutHeight(R.id.widget_square, side, android.util.TypedValue.COMPLEX_UNIT_DIP)
                // A casa la capsula respira; fuori resta il contorno tratteggiato, fermo.
                val away = PillService.running
                setViewVisibility(R.id.widget_breath, if (away) android.view.View.GONE else android.view.View.VISIBLE)
                setViewVisibility(R.id.widget_away, if (away) android.view.View.VISIBLE else android.view.View.GONE)
                setOnClickPendingIntent(R.id.widget_root, tap)
            }
            manager.updateAppWidget(id, views)
            }
        }
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
        val cx = bounds?.let { it.left + it.width() * ratio / 2f } ?: 0f
        val cy = bounds?.let { it.top + it.height() * ratio / 2f } ?: 0f
        // La capsula dentro il widget: 11 × 33 dp, al centro.
        val home = floatArrayOf(cx - 5.5f * d, cy - 16.5f * d, cx + 5.5f * d, cy + 16.5f * d)
        val pill = PillService.instance
        val ready = Settings.canDrawOverlays(this) &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
            Store(this).apiKey != null
        when {
            pill != null && bounds != null -> pill.recall(Offset(cx, cy), Rect(home[0], home[1], home[2], home[3]))
            // Senza la posizione del widget non c'è dove rientrare: si chiude e basta.
            pill != null -> PillService.stop(this)
            // Manca qualcosa (permessi o chiave): si apre l'app, che sa chiederlo.
            bounds == null || !ready -> startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            else -> PillService.start(this, cx, cy, home)
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
