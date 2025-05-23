package com.test.transcrify.floating

import androidx.compose.animation.animateColor
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape // Usiamo CircleShape per una bolla
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic // Icona microfono
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import com.test.transcrify.utils.Dimens

@Composable
fun FloatingBase(isRecording: Boolean) {

    // --- Animazione Pulsante (Solo per stato recording) ---
    // Nota: rememberInfiniteTransition continua l'animazione anche se non usata,
    // ma è leggero. Applichiamo il colore animato solo se isRecording è true.
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val animatedColor by infiniteTransition.animateColor(
        initialValue = Color.Green.copy(alpha = 0.7f), // Leggermente più opaco
        targetValue = Color.Green.copy(alpha = 0.4f),
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 800, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ), label = "pulseColor"
    )
    // --- Fine Animazione ---

    // Definiamo dimensioni e forma del rettangolo
    val rectWidth = Dimens.FloatingBaseWidth
    val rectHeight = Dimens.FloatingBaseHeight
    val cornerRadius = Dimens.FloatingBaseCornerRadius

    // Determina il colore di sfondo
    val backgroundColor = when {
        isRecording -> animatedColor // Usa il colore animato se sta registrando
        else -> Color.LightGray.copy(alpha = 0.450f) // Grigio scuro semi-trasparente di default
    }
    val iconTint = Color.White // Colore icona

    Box(
        modifier = Modifier
            .width(rectWidth)   // Imposta larghezza
            .height(rectHeight) // Imposta altezza
            .clip(RoundedCornerShape(cornerRadius)) // Applica gli angoli arrotondati
            .background(color = backgroundColor)
            .focusable(false),// Imposta lo sfondo (colore pieno o animato)
        contentAlignment = Alignment.Center // Centra il contenuto (l'icona, se presente)
    ) {
        // Mostra l'icona SOLO se isRecording è true
        if (isRecording) {
            Icon(
                imageVector = Icons.Filled.Mic,
                contentDescription = "Recording",
                tint = iconTint,
                modifier = Modifier.size(30.dp) // Dimensione icona
            )
        }
        // Altrimenti, non viene mostrato nulla dentro il Box (solo lo sfondo)
    }
}