package com.test.transcrify.floating

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun CloseFloater() {
    Box(
        modifier = Modifier
            .size(60.dp) // Dimensione del cerchio (puoi aumentarla se vuoi)
            .border(2.dp, Color.LightGray, shape = CircleShape) // Bordo grigio
            .background(Color.Transparent, shape = CircleShape) // Sfondo trasparente
            .alpha(0.7f), // Rende tutto il Box (bordo e contenuto) leggermente trasparente
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.Close, // Icona "X" di Material Design
            contentDescription = "Chiudi il menù flottante",
            tint = Color.LightGray, // Colore grigio per coerenza con il bordo
            modifier = Modifier.size(32.dp) // Dimensione della "X" doppia rispetto all'originale
        )
    }
}
