package com.pasao.transcrify

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * A che punto è «l'ultimo respiro», il successo di Transcri (Figma D2, riga 1 · B, sua scelta del 5 nov):
 * [calma] da 0 a 1 = smette di ondulare; [scala] quanto è grande (1 = la sua misura); [verde] da 0 a 1 = quanto
 * è diventato verde. Lo usano tutte e due le forme: la pillola sul bordo e il cerchio del Floater aperto.
 */
class Respiro(val calma: Float, val scala: Float, val verde: Float)

/** Si stringe appena, poi si gonfia oltre la sua misura. */
private const val STRETTO = 0.86f
private const val PIENO = 1.08f

/**
 * L'ultimo respiro, quando [phase] diventa SUCCESS: l'onda si ferma mentre si stringe, si gonfia diventando verde,
 * torna calmo e resta verde finché dura il «Fatto». Se compare già in SUCCESS (il pannello aperto dopo) è già calmo:
 * il respiro si vede solo nel momento in cui finisce.
 */
@Composable
internal fun ultimoRespiro(phase: Phase): Respiro {
    val fatto = phase == Phase.SUCCESS
    val calma = remember { Animatable(if (fatto) 1f else 0f) }
    val scala = remember { Animatable(1f) }
    val verde = remember { Animatable(if (fatto) 1f else 0f) }
    var prima by remember { mutableStateOf(phase) }
    LaunchedEffect(phase) {
        val da = prima
        prima = phase
        if (!fatto) {
            calma.snapTo(0f)
            scala.snapTo(1f)
            verde.snapTo(0f)
            return@LaunchedEffect
        }
        if (da == Phase.SUCCESS) return@LaunchedEffect
        coroutineScope {
            launch { calma.animateTo(1f, tween(Durate.RESPIRO_STRINGE, easing = FastOutSlowInEasing)) }
            scala.animateTo(STRETTO, tween(Durate.RESPIRO_STRINGE, easing = FastOutSlowInEasing))
        }
        coroutineScope {
            launch { verde.animateTo(1f, tween(Durate.RESPIRO_GONFIA, easing = FastOutSlowInEasing)) }
            scala.animateTo(PIENO, tween(Durate.RESPIRO_GONFIA, easing = FastOutSlowInEasing))
        }
        scala.animateTo(1f, tween(Durate.RESPIRO_POSA, easing = FastOutSlowInEasing))
    }
    return Respiro(calma.value, scala.value, verde.value)
}
