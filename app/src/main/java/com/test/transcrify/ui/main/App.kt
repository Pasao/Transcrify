package com.test.transcrify.ui.main // Assicurati che il package sia corretto

import android.util.Log
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.test.transcrify.floating.OverlayConfigFactory
import com.test.transcrify.utils.SecureStorage
import io.github.luiisca.floating.views.helpers.FloatingViewsManager
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun App(
    mainViewModel: MainViewModel = viewModel(),
    // Modifica le lambda passate: ora triggerano solo l'inizio dei check
    onStartOverlayPermissionRequest: () -> Unit, // Punta a startPermissionChecksAndMaybeOverlay in MainActivity
    onCheckAndRequestAudioPermission: () -> Unit // Questa potrebbe non servire più da qui
) {

    // !! USA LocalContext.current QUI !!
    val context = LocalContext.current
    val scope = rememberCoroutineScope() // Scope per lanciare coroutine da onClick

    val isServiceRunning by mainViewModel.isServiceRunning.collectAsState() // Usa lo stato dal ViewModel
    val apiKeyInput by mainViewModel.apiKeyInput.collectAsState()

    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // not
            Text("Transcrify Overlay Settings", style = MaterialTheme.typography.headlineSmall)
            Spacer(modifier = Modifier.height(24.dp))

            OutlinedTextField(
                value = apiKeyInput,
                onValueChange = { mainViewModel.updateApiKeyInput(it) },
                label = { Text("Chiave API Groq") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(0.8f)
            )
            Spacer(modifier = Modifier.height(8.dp))

            Button(
                onClick = { mainViewModel.saveApiKey() },
                enabled = apiKeyInput.isNotBlank(),
                modifier = Modifier.fillMaxWidth(0.6f)
            ) {
                Text("Salva Chiave")
            }


            Spacer(modifier = Modifier.height(32.dp))

            // Bottone per Avviare l'Overlay
            Button(
                onClick = {
                    onStartOverlayPermissionRequest()
                },
                enabled = !isServiceRunning, // Abilitato solo se il servizio non è attivo
                modifier = Modifier.fillMaxWidth(0.6f)
            ) {
                Text("Apri Overlay Trascrizione")
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Bottone per Fermare l'Overlay
            if (isServiceRunning) {
                Button(
                    onClick = {
                        // Chiama stopFloatService con LocalContext per coerenza
                        Log.d("AppComposable", "Stopping service...")
                        FloatingViewsManager.stopFloatService(context)
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                    modifier = Modifier.fillMaxWidth(0.6f)
                ) {
                    Text("Chiudi Overlay")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = if (isServiceRunning) "Servizio Overlay: Attivo" else "Servizio Overlay: Non Attivo",
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}