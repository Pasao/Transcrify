package com.pasao.transcrify

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * La trasparenza di Transcri fuori dall'app (sua richiesta, 2 nov): una pagina delle impostazioni con, in un
 * riquadro, il TUO sfondo (la finestra lo lascia vedere: windowShowWallpaper, nessun permesso) e sopra la pillola,
 * il Floater e la casa. Uno slider per ognuno; cambiano mentre lo muovi. «Fatto» salva, indietro lascia com'era.
 */
class Trasparenza : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = Store(this)
        val prima = Opacita.di(store)
        Palette.token = Token.dal(Seme.di(this), scuro = true)
        setContent {
            val dark = isSystemInDarkTheme()
            MaterialTheme(if (dark) dynamicDarkColorScheme(this) else dynamicLightColorScheme(this)) {
                BackHandler {
                    prima.applica()
                    esci()
                }
                Schermo {
                    Opacita.attuale().salva(store)
                    esci()
                }
            }
        }
    }

    /** Senza animazione d'uscita: niente stacco sullo sfondo mentre torni alle impostazioni. */
    private fun esci() {
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }
}

@Composable
private fun Schermo(onFatto: () -> Unit) {
    val c = MaterialTheme.colorScheme
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxWidth().background(c.surface).statusBarsPadding().padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 12.dp)) {
            Text("Trasparenza", style = Caratteri.titoloPagina, color = c.onSurface)
            Text("La pillola, il Floater e la casa, sul tuo sfondo.", style = Caratteri.piccolo, color = c.onSurfaceVariant)
        }
        // Il riquadro: tutto intorno è la pagina, dentro si vede lo sfondo del telefono.
        Box(
            Modifier
                .fillMaxWidth()
                .weight(1f)
                .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)
                .drawWithContent {
                    drawRect(c.surface)
                    val m = 16.dp.toPx()
                    drawRoundRect(
                        Color.Black, topLeft = androidx.compose.ui.geometry.Offset(m, 0f),
                        size = androidx.compose.ui.geometry.Size(size.width - 2 * m, size.height),
                        cornerRadius = CornerRadius(28.dp.toPx()), blendMode = BlendMode.Clear,
                    )
                    drawContent()
                },
        ) { Anteprima() }
        Column(
            Modifier.fillMaxWidth().background(c.surface).navigationBarsPadding().padding(horizontal = 24.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Cursore("Pillola", Palette.opacitaPillola) { Palette.opacitaPillola = it }
            Cursore("Floater", Palette.opacitaFloater) { Palette.opacitaFloater = it }
            Cursore("Casa", Palette.opacitaCasa) { Palette.opacitaCasa = it }
            Text("La casa: la tana in basso che compare quando trascini Transcri per toglierlo.", style = Caratteri.orario, color = c.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            Button(onClick = onFatto, modifier = Modifier.fillMaxWidth().height(48.dp)) { Text("Fatto", style = Caratteri.testoGrande) }
        }
    }
}

@Composable
private fun Cursore(nome: String, v: Float, onCambia: (Float) -> Unit) {
    val c = MaterialTheme.colorScheme
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(nome, Modifier.width(72.dp), style = Caratteri.etichetta, color = c.onSurface)
        Slider(v, onCambia, Modifier.weight(1f), valueRange = Palette.OPACITA_MIN..1f)
        Text("${(v * 100).roundToInt()}%", Modifier.width(44.dp).padding(start = 8.dp), style = Caratteri.piccolo, color = c.onSurfaceVariant)
    }
}

/** I tre pezzi come li vedrai, ben staccati: la pillola sul bordo, il Floater chiuso, la casa in basso. */
@Composable
private fun Anteprima() {
    Box(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
        Box(
            Modifier
                .align(Alignment.TopEnd)
                .padding(top = 40.dp, end = PillGeometry.BAR_INSET.dp)
                .size(PillGeometry.BAR_W.dp, PillGeometry.BAR_H.dp)
                .background(Palette.Smoke.copy(alpha = Palette.smokeAlpha), Forme.pillola)
                .border(1.dp, Palette.Stroke, Forme.pillola),
        )
        Column(
            Modifier
                .align(Alignment.CenterEnd)
                .padding(end = PillGeometry.MENU_MARGIN.dp)
                .width(PillGeometry.PANNELLO_STRETTO.dp)
                .background(Palette.Panel, RoundedCornerShape(PillGeometry.MENU_RADIUS.dp))
                .border(1.dp, Palette.Stroke, RoundedCornerShape(PillGeometry.MENU_RADIUS.dp))
                .padding(vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Icon(Icons.Rounded.ExpandLess, null, tint = Palette.Text, modifier = Modifier.background(Palette.Text.copy(alpha = 0.12f), Forme.pillola).padding(horizontal = 14.dp, vertical = 4.dp).size(16.dp))
            RoundButton(Icons.Rounded.Mic, "Registra", Palette.Blue, Palette.Text) {}
        }
        // La casa: la tana in basso, come quando trascini Transcri e lui ci arriva vicino.
        Box(
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 32.dp)
                .size(104.dp, 36.dp)
                .background(casaFumo(1f), Forme.pillola)
                .border(1.dp, Palette.Stroke, Forme.pillola),
        )
    }
}

/** Le tre trasparenze insieme: per ricordarle, salvarle o rimetterle com'erano. */
data class Opacita(val pillola: Float, val floater: Float, val casa: Float) {
    fun applica() {
        Palette.opacitaPillola = pillola
        Palette.opacitaFloater = floater
        Palette.opacitaCasa = casa
    }

    fun salva(store: Store) {
        store.opacitaPillola = pillola
        store.opacitaFloater = floater
        store.opacitaCasa = casa
    }

    companion object {
        fun di(store: Store) = Opacita(store.opacitaPillola, store.opacitaFloater, store.opacitaCasa)
        fun attuale() = Opacita(Palette.opacitaPillola, Palette.opacitaFloater, Palette.opacitaCasa)
    }
}
