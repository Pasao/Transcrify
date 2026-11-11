package com.pasao.transcrify

import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.roundToInt

/**
 * Il Floater si muove tutto insieme (7 nov, sua richiesta: «il caret che si unisce si anima a pezzi»; «inizi a
 * registrare, il registratore si apre e poi il floater si allarga in ritardo»). Due valori soli, ognuno da una molla
 * sola ([Scatto.molla] aprendo, [Scatto.svelto] chiudendo), tenuti dal pannello: la CARTA (il cassetto aperto) e la
 * VOCE (il registratore acceso). Da loro, nello stesso fotogramma: la larghezza del pannello, la forma fusa, il colore
 * del cassetto, la freccia, il contenuto che compare, i tasti di lato, la riga dello stato e quella della pulizia.
 * L'altezza del pannello segue il contenuto: passo passo mentre carta o voce lo fanno crescere, con [Scatto.molla]
 * altrimenti. Aprire e chiudere il Floater (10 nov, «a fasi, prima in verticale e poi in orizzontale») è di nuovo come
 * in 95c2384: una forma sola tra la pillola e il pannello, larghezza e altezza dallo stesso scatto.
 * 10 nov: un terzo valore, il CAMBIO da un cassetto all'altro ([passo]): la carta resta aperta e ne morfano altezza,
 * ponte, colori dei cassetti e contenuto. Mentre uno qualunque dei tre scatti corre, l'altezza del pannello segue
 * il contenuto passo passo (non rincorre la larghezza con una molla sua).
 */
object Coreografia {
    /** Da quanto dello scatto della carta si vede il suo contenuto (chiudendo se ne va per primo). */
    const val CONTENUTO_DA = 0.6f

    /** Lo scatto tenuto tra 0 e 1: la molla può passare l'1 di poco. */
    fun pieno(p: Float) = p.coerceIn(0f, 1f)

    /** Il pannello: stretto (i cassetti e il microfono), largo con la carta aperta o col registratore acceso. */
    fun larghezza(carta: Float, voce: Float, stretta: Float, larga: Float) = stretta + (larga - stretta) * maxOf(pieno(carta), pieno(voce))

    /** Quanto si vede del contenuto della carta, dallo stesso scatto. */
    fun contenuto(p: Float) = ((p - CONTENUTO_DA) / (1f - CONTENUTO_DA)).coerceIn(0f, 1f)

    /** Che cosa fa la carta quando cambia quella aperta: da [mostrata] (quella che si vede) ad [aperta]. */
    fun passo(mostrata: Carta?, aperta: Carta?): Passo = when {
        aperta == mostrata -> Passo.RESTA
        aperta == null -> Passo.CHIUDE
        mostrata == null -> Passo.APRE
        else -> Passo.CAMBIA
    }

    /** Nel cambio da una carta all'altra: da [a] (quella che lascia) a [b] (quella che arriva) con lo scatto [c]. */
    fun tra(a: Float, b: Float, c: Float) = a + (b - a) * pieno(c)

    /** Il contenuto che lascia se ne va nella prima metà del cambio, quello che arriva compare nella seconda. */
    fun esce(c: Float) = (1f - 2f * pieno(c)).coerceIn(0f, 1f)
    fun entra(c: Float) = (2f * pieno(c) - 1f).coerceIn(0f, 1f)

    /**
     * Chi segue la voce (lo stato, i tasti di lato, la pulizia): mentre registri cresce con lei; finita (fermata o
     * buttata) se ne va con lei, dallo stesso scatto all'indietro, invece di sparire di colpo (11 nov, suo: «Butta»
     * passava al registratore a riposo a scatto). [visibile] fuori dalla registrazione (un errore, un avviso): c'è tutto.
     */
    fun conVoce(parla: Boolean, voce: Float, visibile: Boolean) = if (!parla && visibile) 1f else pieno(voce)
}

/**
 * I passi della carta (10 nov, suo: «chiude tutto e poi riapre, troppo movimentato»): da un cassetto all'altro è un
 * CAMBIA, la carta resta aperta e morfa; mai una chiusura e poi un'apertura.
 */
enum class Passo { APRE, CHIUDE, CAMBIA, RESTA }

/**
 * Un pezzo che compare con [quanto] (0–1, da uno scatto che c'è già): alto (o, [diLato], largo) quanto [quanto] della
 * sua misura, ritagliato e trasparente con lui. Niente molla sua: si muove insieme al resto.
 */
fun Modifier.comparsa(quanto: Float, diLato: Boolean = false): Modifier = this
    .graphicsLayer {
        alpha = Coreografia.pieno(quanto)
        clip = true
    }
    .layout { misurabile, vincoli ->
        val pezzo = misurabile.measure(vincoli)
        val f = Coreografia.pieno(quanto)
        val w = if (diLato) (pezzo.width * f).roundToInt() else pezzo.width
        val h = if (diLato) pezzo.height else (pezzo.height * f).roundToInt()
        layout(w, h) { pezzo.place((w - pezzo.width) / 2, 0) }
    }

/** Una capsula che si adatta a ogni misura: gli angoli metà del lato corto, mai oltre [massimo] (px). */
data class Capsula(val massimo: Float = Float.MAX_VALUE) : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density) =
        Outline.Rounded(RoundRect(size.toRect(), CornerRadius(minOf(size.minDimension / 2, massimo))))
}
