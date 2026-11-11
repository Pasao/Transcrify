package com.pasao.transcrify

import androidx.compose.ui.platform.LocalContext

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Le impostazioni di un widget: colore, scritta, cosa c'è nel 2 × 1 (le parole o il tondo che apre l'app), sfondo. Si aprono quando lo aggiungi
 * (ma si possono saltare) e, dopo, tenendolo premuto. Sopra c'è l'anteprima, che cambia
 * mentre scegli.
 */
class WidgetSettings : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()
        // Ogni scelta va subito sul widget (7 nov: «il widget non si aggiorna»): «Fatto» chiude e basta.
        setResult(Activity.RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
        setContent {
            val dark = isSystemInDarkTheme()
            MaterialTheme(if (dark) dynamicDarkColorScheme(this) else dynamicLightColorScheme(this)) {
                Screen(WidgetLook.of(this, id), onChange = { look ->
                    WidgetLook.save(this, id, look)
                    TranscriWidget.refresh(this)
                }) { finish() }
            }
        }
    }
}

@Composable
private fun Screen(start: WidgetLook, onChange: (WidgetLook) -> Unit, onDone: () -> Unit) {
    var look by remember { mutableStateOf(start) }
    LaunchedEffect(look) { if (look != start) onChange(look) }
    val c = MaterialTheme.colorScheme
    Column(
        Modifier
            .fillMaxSize()
            .background(c.surface)
            .systemBarsPadding()
            .padding(horizontal = 24.dp, vertical = 28.dp),
    ) {
        Text("Widget di Transcri", style = Caratteri.titoloPagina, color = c.onSurface)
        Spacer(Modifier.height(24.dp))
        // L'anteprima, su un muro neutro come la home.
        Box(
            Modifier
                .fillMaxWidth()
                .height(150.dp)
                .background(c.surfaceVariant, Forme.foglio),
            contentAlignment = Alignment.Center,
        ) { Preview(look) }
        Spacer(Modifier.height(28.dp))
        Choice("Colore", listOf(WidgetLook.PHONE to "Del telefono", WidgetLook.LIGHT to "Chiaro", WidgetLook.DARK to "Scuro"), look.style) {
            look = look.copy(style = it)
        }
        Choice("Scritta", listOf(true to "Con la scritta", false to "Solo Transcri"), look.text) { look = look.copy(text = it) }
        // 6 nov, giro 6: nel 2 × 1 piccolo le parole servono a poco; il tondo apre l'app.
        Choice("Nel 2 × 1", listOf(false to "Testo", true to "Apri l'app"), look.apri) { look = look.copy(apri = it) }
        Choice("Sfondo", listOf(true to "Pieno", false to "Trasparente"), look.filled) { look = look.copy(filled = it) }
        Spacer(Modifier.weight(1f))
        Button(onClick = onDone, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("Fatto", style = Caratteri.testoGrande) }
    }
}

@Composable
private fun <T> Choice(label: String, options: List<Pair<T, String>>, current: T, onPick: (T) -> Unit) {
    val c = MaterialTheme.colorScheme
    Text(label, style = Caratteri.etichetta, color = c.onSurfaceVariant)
    Spacer(Modifier.height(8.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (value, text) ->
            val on = value == current
            Box(
                Modifier
                    .background(if (on) c.onSurface else c.surfaceVariant, CircleShape)
                    .clickable { onPick(value) }
                    .padding(horizontal = 16.dp, vertical = 9.dp),
            ) { Text(text, style = Caratteri.testo.copy(fontWeight = FontWeight.Medium), color = if (on) c.surface else c.onSurface) }
        }
    }
    Spacer(Modifier.height(20.dp))
}

/** Il widget come lo disegna il launcher, in piccolo: stessi colori, stesse proporzioni. */
@Composable
private fun Preview(look: WidgetLook) {
    // Gli stessi colori del widget vero (WidgetColori, dai token).
    val col = WidgetColori.di(LocalContext.current, look.style)
    val bg = listOf(Color(col.fondo), Color(col.fondoFine))
    val text = Color(col.testo)
    val blob = Brush.verticalGradient(listOf(Color(col.transcriA), Color(col.transcriB)))
    val shape = CircleShape
    val base = Modifier
        .then(if (look.filled) Modifier.background(Brush.horizontalGradient(bg), shape) else Modifier.border(1.dp, text.copy(alpha = 0.2f), shape))
    if (look.dueXUno) {
        Row(base.width(260.dp).height(76.dp).padding(start = 10.dp, end = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(56.dp), contentAlignment = Alignment.Center) { Blob(blob, big = true) }
            Spacer(Modifier.width(12.dp))
            if (look.apri) {
                // Il tondo che apre l'app, a destra: come widget_open_round (il fondo è il testo, tenue).
                Spacer(Modifier.weight(1f))
                Box(Modifier.size(52.dp).background(text.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(painterResource(R.drawable.ic_widget_open), contentDescription = "Apri Transcrify", tint = text, modifier = Modifier.size(22.dp))
                }
            } else {
                Column {
                    Text("Detta", style = Caratteri.titoloScheda, color = text)
                    Text("Tocca e parla, poi incolla dove vuoi", style = Caratteri.piccolo, color = text.copy(alpha = 0.7f), maxLines = 2)
                }
            }
        }
    } else {
        Box(base.size(76.dp), contentAlignment = Alignment.Center) { Blob(blob) }
    }
}

@Composable
private fun Blob(brush: Brush, big: Boolean = false) {
    // Le stesse proporzioni del disegno del widget (34 × 30), ingrandite nel 2 × 1.
    val k = if (big) 52f / 34f else 1f
    Box(Modifier.size((34 * k).dp, (30 * k).dp).background(brush, RoundedCornerShape((13 * k).dp))) {
        Row(Modifier.align(Alignment.TopCenter).padding(top = (9 * k).dp), horizontalArrangement = Arrangement.spacedBy((9 * k).dp)) {
            repeat(2) { Box(Modifier.size((2.6 * k).dp, (3.1 * k).dp).background(Color.White, CircleShape)) } // ds:eccezione: gli occhi di Transcri
        }
    }
}
