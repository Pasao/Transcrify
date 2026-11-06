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

/**
 * Come appare un widget: lo sceglie chi lo aggiunge (vedi [WidgetSettings]). [apri] (6 nov, giro 6: «se il 2 × 1 è
 * piccolo tenere il testo è inutile»): nel 2 × 1, accanto a Transcri, il tondo che apre l'app invece delle parole.
 */
data class WidgetLook(val style: String = PHONE, val text: Boolean = true, val filled: Boolean = true, val apri: Boolean = false) {
    /** C'è il disegno 2 × 1: con le parole o col tondo che apre l'app (senza nessuno dei due, resta lui al centro). */
    val dueXUno get() = text || apri

    companion object {
        const val PHONE = "phone"
        const val LIGHT = "light"
        const val DARK = "dark"

        private fun prefs(context: Context) = context.getSharedPreferences("widgets", Context.MODE_PRIVATE)

        fun of(context: Context, id: Int) = prefs(context).let {
            WidgetLook(it.getString("style_$id", PHONE)!!, it.getBoolean("text_$id", true), it.getBoolean("filled_$id", true), it.getBoolean("apri_$id", false))
        }

        fun save(context: Context, id: Int, look: WidgetLook) = prefs(context).edit()
            .putString("style_$id", look.style).putBoolean("text_$id", look.text).putBoolean("filled_$id", look.filled)
            .putBoolean("apri_$id", look.apri).apply()

        fun forget(context: Context, id: Int) =
            prefs(context).edit().remove("style_$id").remove("text_$id").remove("filled_$id").remove("apri_$id").apply()
    }
}

/**
 * Il widget: la casa di Transcri sulla schermata home, una pillola come i widget di Samsung.
 * 2 × 1 dice cosa fa ("Detta" / "Richiama") o, se l'hai scelto ([WidgetLook.apri]), ha il tondo che apre l'app;
 * stretto a 1 × 1, o senza scritta né tondo, resta lui al centro.
 * Toccandolo Transcri esce e vola al bordo; se è già fuori, rientra qui (e se stava registrando manda quello che ha sentito).
 * Il 4 × 1 ha anche «Apri» e, con lui a casa, il tasto che lo fa uscire già in ascolto.
 */
class TranscriWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)

    /** La casella è cambiata (griglia, rotazione, ridimensionamento): si ridisegna su misura. */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) = refresh(context)

    override fun onDeleted(context: Context, ids: IntArray) = ids.forEach { WidgetLook.forget(context, it) }

    companion object {
        /** Da questa larghezza (dp) il widget è 2 × 1: il cerchio con lui e, accanto, cosa fa. */
        const val WIDE_FROM_DP = 140f

        /** Da questa larghezza (dp) è 4 × 1: c'è posto anche per il bottone che apre l'app. */
        const val LONG_FROM_DP = 280f

        /** Ridisegna tutti i widget: Transcri vivo se è a casa, il suo contorno tratteggiato se è fuori. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TranscriWidget::class.java))
            for (id in ids) {
                val look = WidgetLook.of(context, id)
                val away = PillService.running
                // Due disegni, e il launcher sceglie quello che entra nella casella.
                val small = views(context, id, look, away, wide = false)
                val long = SizeF(LONG_FROM_DP, 40f) to views(context, id, look, away, wide = true, open = true)
                val views = if (look.dueXUno) {
                    RemoteViews(mapOf(SizeF(40f, 40f) to small, SizeF(WIDE_FROM_DP, 40f) to views(context, id, look, away, wide = true), long))
                } else {
                    RemoteViews(mapOf(SizeF(40f, 40f) to small, long))
                }
                manager.updateAppWidget(id, views)
            }
        }

        private fun views(context: Context, id: Int, look: WidgetLook, away: Boolean, wide: Boolean, open: Boolean = false) =
            RemoteViews(context.packageName, if (wide) R.layout.widget_wide else R.layout.widget_small).apply {
                // I colori dai token (WidgetColori, gli stessi dell'anteprima): la pillola si colora col fondo,
                // Transcri è disegnato coi suoi due toni.
                val col = WidgetColori.di(context, look.style)
                val text = android.content.res.ColorStateList.valueOf(col.testo)
                // Pieno: la pillola col gradiente dai token; vuoto: niente fondo (solo il contorno del launcher).
                setInt(R.id.widget_frame, "setBackgroundResource", if (look.filled) R.drawable.widget_bg_phone else 0)
                setViewVisibility(R.id.widget_bg, if (look.filled) View.VISIBLE else View.GONE)
                if (look.filled) setImageViewBitmap(R.id.widget_bg, col.sfondo())
                val corpo = col.transcri(context.resources.displayMetrics.density * (if (wide) 55f else 37f) / 34f)
                for (b in listOf(R.id.widget_blob_1, R.id.widget_blob_2, R.id.widget_blob_3, R.id.widget_blob_4)) setImageViewBitmap(b, corpo)
                // I colori si risolvono nel launcher: lo stile "del telefono" segue anche il tema chiaro/scuro.
                setColorStateList(R.id.widget_title, "setTextColor", text)
                if (wide) {
                    setColorStateList(R.id.widget_line, "setTextColor", text)
                    setTextViewText(R.id.widget_title, if (away) "Richiama" else "Detta")
                    setTextViewText(R.id.widget_line, if (away) "Tocca per richiamarlo" else "Tocca e parla, poi incolla dove vuoi")
                    // Nel 2 × 1 le parole o il tondo che apre l'app (a destra: le parole restano invisibili a fargli posto).
                    val tondo = !open && look.apri
                    setViewVisibility(R.id.widget_words, if (look.text && !tondo) View.VISIBLE else View.INVISIBLE)
                    setViewVisibility(R.id.widget_open, if (open) View.VISIBLE else View.GONE)
                    // Il tasto che detta c'è solo con lui a casa: è da lì che esce.
                    setViewVisibility(R.id.widget_record, if (open && !away) View.VISIBLE else View.GONE)
                    // Nel 2 × 1 l'app si apre dal tondo a destra (nel 4 × 1 da «Apri»): lo stesso PendingIntent.
                    setViewVisibility(R.id.widget_open_round, if (tondo) View.VISIBLE else View.GONE)
                    if (open) {
                        tasto(R.id.widget_open, R.id.widget_open_icon, text, openApp(context, id))
                        setColorStateList(R.id.widget_open_text, "setTextColor", text)
                        if (!away) tasto(R.id.widget_record, R.id.widget_record_icon, text, tap(context, id, record = true))
                    } else if (tondo) {
                        tasto(R.id.widget_open_round, R.id.widget_open_round_icon, text, openApp(context, id))
                    }
                } else {
                    setTextViewText(R.id.widget_title, if (away) "Richiama" else "Detta")
                    setViewVisibility(R.id.widget_title, if (look.text) View.VISIBLE else View.GONE)
                }
                // A casa respira; fuori resta il contorno tratteggiato, fermo.
                setViewVisibility(R.id.widget_breath, if (away) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.widget_away, if (away) View.VISIBLE else View.GONE)
                setOnClickPendingIntent(R.id.widget_root, tap(context, id))
            }

        private fun openApp(context: Context, id: Int) = PendingIntent.getActivity(
            context, OPEN_REQUEST + id,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        /** I tasti del 4 × 1 («Apri», detta): il fondo e l'icona col colore del testo, e cosa fanno. */
        private fun RemoteViews.tasto(fondo: Int, icona: Int, colore: android.content.res.ColorStateList, azione: PendingIntent) {
            setColorStateList(icona, "setImageTintList", colore)
            setColorStateList(fondo, "setBackgroundTintList", colore)
            setOnClickPendingIntent(fondo, azione)
        }

        private const val OPEN_REQUEST = 100_000
        private const val RECORD_REQUEST = 200_000

        // Ogni widget passa il suo id: serve per leggere il suo fattore di scala e il suo aspetto (vedi WidgetTrampoline).
        // Il tasto che detta ha un suo codice: con lo stesso, Android userebbe un PendingIntent solo per tutti e due.
        private fun tap(context: Context, id: Int, record: Boolean = false) = PendingIntent.getActivity(
            context, if (record) RECORD_REQUEST + id else id,
            Intent(context, WidgetTrampoline::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                .putExtra(PillService.EXTRA_RECORD, record),
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
        // Dal tasto che detta (4 × 1) il rettangolo è quello del tasto, non del widget: Transcri esce da lì, piccolo.
        val record = intent.getBooleanExtra(PillService.EXTRA_RECORD, false)
        val home = bounds?.let { b ->
            val w = b.width() * ratio
            val h = b.height() * ratio
            val look = if (id == AppWidgetManager.INVALID_APPWIDGET_ID) WidgetLook() else WidgetLook.of(this, id)
            val wide = !record && (w / d >= TranscriWidget.LONG_FROM_DP || (look.dueXUno && w / d >= TranscriWidget.WIDE_FROM_DP))
            // Dov'è Transcri nel disegno: nel 2 × 1 a sinistra, grande (10 dp + metà del suo posto da 56),
            // nel 1 × 1 al centro, un po' più su per lasciare posto alla parola sotto.
            val cx = if (wide) b.left + 38f * d * ratio else b.left + w / 2f
            val cy = b.top + h / 2f - if (!wide && !record && look.text) 9f * d * ratio else 0f
            val hw = (if (wide) 26f else 17f) * d * ratio
            val hh = (if (wide) 23f else 15f) * d * ratio
            Rect(cx - hw, cy - hh, cx + hw, cy + hh)
        }
        val pill = PillService.instance?.takeIf { !it.homecoming && it.out }
        val ready = Settings.canDrawOverlays(this) &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
            Store(this).apiKey != null
        when {
            // Il tasto che detta mentre lui è già fuori (il widget non s'era ancora ridisegnato): detta da dov'è.
            pill != null && record -> PillService.listen(this, null, -1, null)
            // Rientra nel widget; se stava registrando (anche in pausa), quello che ha sentito si trascrive e si copia.
            pill != null && home != null -> pill.recall(home.center, home)
            // Senza la posizione del widget rientra nella casa in basso: anche così non si butta niente.
            pill != null -> pill.rientra()
            // Manca qualcosa (permessi o chiave): si apre l'app, che sa chiederlo.
            home == null || !ready -> startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            else -> PillService.start(this, home.center.x, home.center.y, floatArrayOf(home.left, home.top, home.right, home.bottom), record)
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}
