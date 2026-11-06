package com.pasao.transcrify

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.TweenSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween

/**
 * Il movimento del Floater, in un posto solo: si apre con uno scatto (svelto, supera appena e si posa) e si chiude
 * svelto, senza rimbalzo. Lo usano la pillola che diventa pannello e la carta dell'ultima trascrizione che esce
 * (6 nov, sua richiesta: «come quando apri e chiudi la pillola»).
 */
object Scatto {
    /** Aprire e crescere: la molla di [Durate.SCATTO_SMORZAMENTO] e [Durate.SCATTO_RIGIDITA]. */
    fun <T> molla(): SpringSpec<T> = spring(Durate.SCATTO_SMORZAMENTO, Durate.SCATTO_RIGIDITA)

    /** Chiudere e sfumare: [Durate.VELOCE], parte svelto e arriva morbido. */
    fun <T> svelto(): TweenSpec<T> = tween(Durate.VELOCE, easing = FastOutSlowInEasing)
}
