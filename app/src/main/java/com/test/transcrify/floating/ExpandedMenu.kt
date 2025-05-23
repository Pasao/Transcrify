package com.test.transcrify.floating

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.* // Importa tutte le icone di default
import androidx.compose.material.icons.outlined.AutoFixNormal
import androidx.compose.material3.* // Usa Material 3 components
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.outlined.Info
import com.test.transcrify.utils.Dimens
import com.test.transcrify.ui.overlay.OverlayViewModel // Assicurati che l'import sia corretto
//import kotlinx.coroutines.flow.collectAsState // Import corretto per collectAsState

@Composable
fun ExpandedMenu(
    viewModel: OverlayViewModel, // Accetta il ViewModel dell'Overlay
    close: () -> Unit // Funzione per chiudere fornita dalla libreria floating-views
) {
    // Osserva lo stato UI dal ViewModel
    val uiState by viewModel.uiState.collectAsState()
    // !! Osserva durata e dimensione !!
    val durationText by viewModel.recordingDurationFormatted.collectAsState()
    val sizeText by viewModel.recordingSizeFormatted.collectAsState()
    val menuWidth = Dimens.ExpandedMenuWidth
    val fixedHeight = Dimens.ExpandedMenuHeight
    val cornerRadius = Dimens.ExpandedMenuCornerRadius
    val showCopy by viewModel.showCopyButton.collectAsState()

    // !! Ascolta gli eventi one-shot dal ViewModel !!
    LaunchedEffect(Unit) { // Esegui solo una volta quando il Composable entra
        viewModel.viewActions.collect { action ->
            when (action) {
                is OverlayViewModel.ViewAction.CloseExpandedMenu -> {
                    Log.d("ExpandedMenu", "Received CloseExpandedMenu action, calling close().")
                    close() // Chiama la callback fornita dalla libreria
                }
                // Handle altri eventi futuri qui
            }
        }
    }

    Column(
        modifier = Modifier
            .width(menuWidth) // Larghezza fissa
            .height(fixedHeight) // Altezza fissa
            .clip(RoundedCornerShape(cornerRadius)) // Arrotonda come una pillola (metà larghezza)
            .background(Color.DarkGray.copy(alpha = 0.9f))
            // Padding *interno* per distanziare dagli bordi
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        // Usiamo SpaceBetween per spingere X in alto, Azione in basso, e il resto nel mezzo
        verticalArrangement = Arrangement.SpaceBetween
    ) {
            // --- 1. Pulsante X in Alto ---
            // Lo mostriamo sempre, ma la sua azione potrebbe dipendere dallo stato
            IconButton(
                onClick = {
                    if (uiState == OverlayViewModel.UiState.RECORDING ||
                        uiState == OverlayViewModel.UiState.PROCESSING ||
                        uiState == OverlayViewModel.UiState.ERROR
                    ) {
                        viewModel.cancelOperation()
                    }
                    close() // Chiama sempre la callback per chiudere l'expanded view
                },
                modifier = Modifier.size(Dimens.SmallIconButtonSize) // Dimensione piccola per la X
            ) {
                Icon(Icons.Default.Close, contentDescription = "Chiudi", tint = Color.White)
            }

        // --- 2. Contenuto Centrale (dipende dallo stato) ---
        // Usiamo un Box per centrare verticalmente il contenuto specifico dello stato
        // se non riempie tutto lo spazio centrale (anche se SpaceBetween aiuta)
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
            Column( // Colonna interna per gestire testo e indicatori nel mezzo
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center // Centra verticalmente il suo contenuto
            ) {
                when (uiState) {
                    OverlayViewModel.UiState.RECORDING -> {
                        Text(durationText,
                            color = Color.White,
                            style = MaterialTheme.typography.bodyMedium)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(sizeText,
                            color = Color.White,
                            style = MaterialTheme.typography.bodySmall)
                    }
                    OverlayViewModel.UiState.PROCESSING -> {
                        CircularProgressIndicator(modifier = Modifier.size(32.dp), color = Color.White, strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Process...", color = Color.White, style = MaterialTheme.typography.bodySmall)
                    }
                    OverlayViewModel.UiState.ERROR -> {
                        Icon(Icons.Default.ErrorOutline, contentDescription = "Errore", tint = Color.Red, modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.height(4.dp))
                        Text("Errore\nTrascrizione", color = Color.Red, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
                    }
                    OverlayViewModel.UiState.IDLE, // Anche IDLE, SUCCESS, LIMITED mostrano testo
                    OverlayViewModel.UiState.SUCCESS, // SUCCESS è transitorio, ma mettiamo testo placeholder
                    OverlayViewModel.UiState.LIMITED_HOURLY,
                    OverlayViewModel.UiState.LIMITED_DAILY -> {
                        val statusText = when(uiState) {
                            OverlayViewModel.UiState.IDLE -> "Pronto\nRegistra"
                            OverlayViewModel.UiState.SUCCESS -> "Fatto!" // Potrebbe non vedersi mai
                            else -> "Limite\nRaggiunto"
                        }
                        val statusColor = if(uiState == OverlayViewModel.UiState.IDLE) Color.White else Color.Gray
                        Spacer(modifier = Modifier.height(4.dp))
                        Icon(Icons.Outlined.Info, contentDescription = "Status", tint = statusColor, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(statusText, color = statusColor, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
                    }
                }
            }
        }


        // --- 3. Area Inferiore: Copia (condizionale), Azione Principale, Toggle ---
        Column( // Usiamo una colonna interna per raggruppare questi elementi in basso
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp) // Spazio tra Copia, Azione, Toggle
        ) {

            // --- 3a. Pulsante Copia (Condizionale) ---
            // Mostra solo se necessario e non in stato SUCCESS transitorio
            Box(modifier = Modifier.height(Dimens.SmallIconButtonSize)) { // Placeholder per mantenere altezza
                if (showCopy && uiState != OverlayViewModel.UiState.SUCCESS && uiState != OverlayViewModel.UiState.RECORDING && uiState != OverlayViewModel.UiState.PROCESSING) {
                    CopyButton(viewModel)
                }
            }
            when (uiState) {
                OverlayViewModel.UiState.IDLE -> {
                    CircularIconButton(
                        onClick = { viewModel.startRecording() },
                        buttonSize = Dimens.CircularButtonSize, // Usa Dimens
                        iconSize = Dimens.CircularButtonIconSize,  // Usa Dimens
                        icon = Icons.Default.Mic,
                        contentDescription = "Registra",
                        backgroundColor = Color.LightGray, // Sfondo grigio per IDLE
                        iconTint = Color.Black // Icona nera su grigio chiaro
                    )
                }

                OverlayViewModel.UiState.RECORDING -> {
                    CircularIconButton(
                        onClick = { viewModel.stopAndSend() },
                        buttonSize = Dimens.CircularButtonSize, // Usa Dimens
                        iconSize = Dimens.CircularButtonIconSize,  // Usa Dimens
                        icon = Icons.Default.Check,
                        contentDescription = "Ferma e Invia",
                        backgroundColor = Color.Green, // Sfondo verde per Stop
                        iconTint = Color.White
                    )
                }

                OverlayViewModel.UiState.ERROR -> {
                    CircularIconButton(
                        onClick = { viewModel.retryLastAudio() },
                        buttonSize = Dimens.CircularButtonSize, // Usa Dimens
                        iconSize = Dimens.CircularButtonIconSize,  // Usa Dimens
                        icon = Icons.Default.Refresh,
                        contentDescription = "Riprova",
                        backgroundColor = Color.Yellow, // Sfondo giallo per Retry
                        iconTint = Color.Black
                    )
                }
                // Stati senza azione circolare (Processing, Limite, Success)
                OverlayViewModel.UiState.PROCESSING,
                OverlayViewModel.UiState.LIMITED_HOURLY,
                OverlayViewModel.UiState.LIMITED_DAILY,
                OverlayViewModel.UiState.SUCCESS -> {
                    // Possiamo mettere un Box vuoto per mantenere lo spazio o
                    // un'icona disabilitata/informativa se preferito
                    Box(modifier = Modifier.size(56.dp)) // Mantiene l'altezza occupata dal pulsante
                }
            }

            // Toggle Purificazione
            val isPurificationOn by viewModel.isPurificationEnabled.collectAsState()
            IconToggleButton(
                checked = isPurificationOn,
                onCheckedChange = {
                    viewModel.togglePurification(it)
                },
                modifier = Modifier.size(Dimens.SmallIconButtonSize + 4.dp) // Leggermente più grande
            ) {
                val tintColor = if (isPurificationOn) Color.Cyan else Color.Gray // Grigio se OFF
                Icon(
                    imageVector = if (isPurificationOn) Icons.Filled.AutoFixHigh else Icons.Outlined.AutoFixNormal,
                    contentDescription = "Attiva/Disattiva Purificazione Testo",
                    tint = tintColor
                )
            }
        }
    }
}

// Helper Composable per i pulsanti circolari in basso nel menu espanso
@Composable
private fun CircularIconButton(
    onClick: () -> Unit,
    buttonSize: Dp = Dimens.CircularButtonSize, // Default da Dimens
    iconSize: Dp = Dimens.CircularButtonIconSize,   // Default da Dimens
    icon: ImageVector,
    contentDescription: String,
    backgroundColor: Color,
    iconTint: Color,
    modifier: Modifier = Modifier,
) {
    IconButton(
        onClick = onClick,
        modifier = modifier
            .size(buttonSize)
            .clip(CircleShape)
            .background(backgroundColor)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = iconTint,
            modifier = Modifier.size(iconSize)
        )
    }
}

@Composable
private fun CopyButton(viewModel: OverlayViewModel) { // ColumnScope per usare align ecc.
    Spacer(modifier = Modifier.height(8.dp)) // Spazio sopra copia
    Box(
        modifier = Modifier
            .size(Dimens.SmallIconButtonSize)
            .clickable { viewModel.copyToClipboard() }
            //.align(Alignment.CenterHorizontally),
        //contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.ContentCopy,
            contentDescription = "Copia ultima trascrizione",
            tint = Color.Gray,
            modifier = Modifier.size(Dimens.SmallIconButtonSize) // Dimensione standard dell'icona
        )
    }
}