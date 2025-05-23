package com.test.transcrify // Assicurati che il package sia corretto

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.test.transcrify.floating.OverlayConfigFactory
import androidx.appcompat.app.AlertDialog
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.core.app.ActivityCompat
import androidx.lifecycle.lifecycleScope
import com.test.transcrify.ui.main.App // Importa il tuo Composable principale
import com.test.transcrify.ui.main.MainViewModel
import com.test.transcrify.ui.theme.TranscrifyTheme // Importa il tuo tema
import com.test.transcrify.utils.SecureStorage
import io.github.luiisca.floating.views.FloatingViewsConfig
import io.github.luiisca.floating.views.helpers.FloatServiceStateManager
import io.github.luiisca.floating.views.helpers.FloatingViewsManager
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private lateinit var overlayPermissionLauncher: ActivityResultLauncher<Intent>
    private lateinit var requestPermissionLauncher: ActivityResultLauncher<String> // For audio
    private var waitingForPermissionsToStartOverlay by mutableStateOf(false)

    private val mainViewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Launcher Permesso Overlay
        overlayPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { _ -> // Non usiamo result qui
            if (hasOverlayPermission()) {
                Log.d("MainActivity", "Overlay permission granted/checked.")
                // Se stavamo aspettando, controlla anche l'audio ora
                if (waitingForPermissionsToStartOverlay) {
                    checkAndRequestAudioPermission() // Prossimo passo
                }
            } else {
                Log.w("MainActivity", "Overlay permission denied.")
                Toast.makeText(this, "Permesso overlay necessario", Toast.LENGTH_SHORT).show()
                waitingForPermissionsToStartOverlay = false // Resetta flag se negato
            }
        }

        // Launcher Permesso Audio
        requestPermissionLauncher =
            registerForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
                if (isGranted) {
                    Log.d("MainActivity", "RECORD_AUDIO permission granted.")
                    // Se stavamo aspettando E l'overlay è ok, possiamo provare a partire
                    if (waitingForPermissionsToStartOverlay && hasOverlayPermission()) {
                        tryStartOverlayNow() // Chiama la funzione di avvio finale
                    }
                } else {
                    Log.w("MainActivity", "RECORD_AUDIO permission denied")
                    Toast.makeText(this, "Permesso audio necessario", Toast.LENGTH_SHORT).show()
                    waitingForPermissionsToStartOverlay = false // Resetta flag se negato
                }
            }

        setContent {
            TranscrifyTheme {
                Surface( /*...*/ ) {
                    // Passa le funzioni che AVVIANO i check
                    App(
                        mainViewModel = mainViewModel,
                        onStartOverlayPermissionRequest = ::startPermissionChecksAndMaybeOverlay, // Avvia check overlay
                        onCheckAndRequestAudioPermission = ::checkAndRequestAudioPermission // Avvia check audio (chiamato da App)
                    )
                }
            }
        }
    }

    // Funzione per iniziare il flusso di check permessi dall'esterno
    fun startPermissionChecksAndMaybeOverlay() {
        Log.d("MainActivity", "startPermissionChecksAndMaybeOverlay called")
        waitingForPermissionsToStartOverlay = true // Indica che vogliamo avviare dopo i permessi
        checkOverlayPermissionAndRequest() // Inizia dal permesso overlay
    }


    // Controlla e richiede permesso OVERLAY
    private fun checkOverlayPermissionAndRequest() {
        if (!hasOverlayPermission()) {
            Log.d("MainActivity", "Requesting overlay permission...")
            requestOverlayPermission()
        } else {
            Log.d("MainActivity", "Overlay permission already granted.")
            // Se stavamo aspettando, passa al check audio
            if (waitingForPermissionsToStartOverlay) {
                checkAndRequestAudioPermission()
            }
        }
    }

    // Controlla e richiede permesso AUDIO
    fun checkAndRequestAudioPermission() { // Rendi pubblica o interna se chiamata solo internamente
        if (!hasAudioPermission()) {
            // Mostra rationale o richiedi direttamente
            if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)) {
                Log.i("MainActivity", "Showing rationale for RECORD_AUDIO...")
                AlertDialog.Builder(this)
                    .setTitle("Permesso Audio Necessario")
                    .setMessage("Questa app necessita del permesso per registrare audio.")
                    .setPositiveButton("OK") { _, _ -> requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO) }
                    .setNegativeButton("Annulla") { _, _ -> waitingForPermissionsToStartOverlay = false } // Resetta flag se annulla
                    .show()
            } else {
                Log.d("MainActivity", "Requesting RECORD_AUDIO permission...")
                requestPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
            }
        } else {
            Log.d("MainActivity", "RECORD_AUDIO permission already granted.")
            // Se stavamo aspettando E overlay ok, prova ad avviare
            if (waitingForPermissionsToStartOverlay && hasOverlayPermission()) {
                tryStartOverlayNow()
            }
        }
    }
    // Funzione helper per avviare l'overlay DOPO che tutti i permessi sono OK
    private fun tryStartOverlayNow() {
        Log.d("MainActivity", "==> tryStartOverlayNow called <==")
        lifecycleScope.launch {
            if (mainViewModel.canStartOverlay()) {
                try {
                    val apiKey = SecureStorage.getApiKey(this@MainActivity)

                    // 1. Definisci la lambda factory che usa il tuo OverlayConfigFactory
                    val factoryLambda: (Context, String) -> FloatingViewsConfig =
                        { serviceContext, key ->
                            // Questa lambda verrà eseguita DENTRO il Service
                            // OverlayConfigFactory userà serviceContext per ottenere il ViewModel
                            OverlayConfigFactory.createConfig(serviceContext, key)
                        }

                    // 2. Chiama il FloatingViewsManager modificato, passando la lambda
                    FloatingViewsManager.startFloatServiceIfPermitted(
                        context = this@MainActivity, // Il contesto Activity per il check permesso iniziale
                        apiKey = apiKey,
                        configFactory = factoryLambda // Passa la lambda
                    )

                    Log.i("MainActivity", "Overlay service start initiated with config factory.")

                } catch (e: Exception) {
                    Log.e("MainActivity", "Error initiating overlay service start", e)
                    Toast.makeText(this@MainActivity, "Errore avvio overlay", Toast.LENGTH_SHORT).show()
                }
            } else {
                Log.w("MainActivity", "API Key check failed, not starting overlay.")
            }
            waitingForPermissionsToStartOverlay = false
        }
    }


    // Helpers per controllare permessi
    private fun hasOverlayPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun hasAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    // Funzione per lanciare l'intent di richiesta overlay
    private fun requestOverlayPermission() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:${packageName}")
        )
        try {
            overlayPermissionLauncher.launch(intent)
        } catch (e: ActivityNotFoundException) {
            Log.e("MainActivity", "Could not launch overlay settings intent", e)
            Toast.makeText(this, "Impossibile aprire impostazioni overlay", Toast.LENGTH_LONG).show()
        }
    }



    override fun onDestroy() {
        super.onDestroy()
        // Tentativo di pulire il ViewModel dell'overlay quando l'activity principale viene distrutta.
        // Funziona solo se il servizio non è più attivo o se l'intero processo viene terminato.
        // La gestione del ciclo di vita del ViewModel nel service è delicata.
        if (!FloatServiceStateManager.isServiceRunning.value) {
            println("MainActivity onDestroy and service not running, clearing OverlayViewModel")
            // FloatingConfigProvider.clearOverlayViewModel() // Meglio gestirlo nel service onTaskRemoved o onDestroy
        }
    }
}

@Composable
fun Greeting(name: String) {
    Text(text = "Hello $name!")
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    TranscrifyTheme {
        Greeting("Android")
    }
}