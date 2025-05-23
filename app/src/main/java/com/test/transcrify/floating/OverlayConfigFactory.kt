package com.test.transcrify.floating // Assicurati che il package sia corretto

import android.app.Application
import android.content.Context
import android.graphics.PointF // Import PointF per le coordinate
import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import com.test.transcrify.ui.overlay.OverlayViewModel
import com.test.transcrify.ui.overlay.OverlayViewModelFactory
// Importa Dimens per usare le dimensioni centralizzate
import com.test.transcrify.utils.Dimens
// Import classi libreria
import io.github.luiisca.floating.views.FloatingViewsConfig
import io.github.luiisca.floating.views.CloseFloatConfig // Nota: Corretto da CloseFloaterConfig a CloseFloatConfig
import io.github.luiisca.floating.views.ExpandedFloatConfig
import io.github.luiisca.floating.views.MainFloatConfig

object OverlayConfigFactory {

    private const val TAG = "OverlayConfigFactory"

    // ViewModelStoreOwner per mantenere vivo il ViewModel dell'overlay
    private val overlayViewModelStoreOwner = object : ViewModelStoreOwner {
        override val viewModelStore: ViewModelStore = ViewModelStore()
    }

    // Riferimento al ViewModel corrente per potenziale riutilizzo o debug
    // (Anche se getOverlayViewModel attualmente usa sempre lo StoreOwner)
    private var currentViewModel: OverlayViewModel? = null

    // Funzione helper per ottenere il ViewModel usando il nostro StoreOwner dedicato
    private fun getOverlayViewModel(context: Context, apiKey: String): OverlayViewModel {
        Log.d(TAG, "Requesting OverlayViewModel instance via custom StoreOwner using ApplicationContext")
        val factory = OverlayViewModelFactory(context.applicationContext as Application, apiKey)
        return ViewModelProvider(overlayViewModelStoreOwner, factory)[OverlayViewModel::class.java]
            .also { currentViewModel = it }
    }

    // Funzione per creare la configurazione completa per la libreria
    fun createConfig(context: Context, apiKey: String): FloatingViewsConfig {
        Log.d(TAG, "--- Creating FloatingViewsConfig ---")

        // 1. Ottieni l'istanza del ViewModel (condivisa tra main e expanded)
        val overlayViewModel = getOverlayViewModel(context, apiKey)
        Log.d(TAG, "OverlayViewModel instance: ${overlayViewModel.hashCode()}") // Log hashcode per verifica istanza

        // --- 2. Calcolo Posizione Iniziale per MainFloatConfig usando Dimens ---
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val displayMetrics = DisplayMetrics()

        // Ottieni le dimensioni reali dello schermo in modo sicuro
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.display?.getRealMetrics(displayMetrics)
                    ?: windowManager.defaultDisplay.getMetrics(displayMetrics) // Fallback se display è null
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getRealMetrics(displayMetrics)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting real display metrics, using default metrics as fallback", e)
            // Fallback più robusto se getRealMetrics fallisce
            try {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getMetrics(displayMetrics)
            } catch (e2: Exception) {
                Log.e(TAG, "Error getting default display metrics as well!", e2)
                // In caso estremo, potresti impostare dimensioni fisse o gestire l'errore
            }
        }

        val screenWidthPx = displayMetrics.widthPixels
        val screenHeightPx = displayMetrics.heightPixels
        val density = displayMetrics.density

        // Usa le dimensioni da Dimens per il calcolo (accedi con .value per ottenere Float)
        val floatingBaseWidthPx = (Dimens.FloatingBaseWidth.value * density)
        val floatingBaseHeightPx = (Dimens.FloatingBaseHeight.value * density)
        val marginRightPx = (Dimens.FloatingBaseMarginEnd.value * density)

        // Calcola coordinate iniziali (in pixel) per MainFloatConfig
        val mainStartX = screenWidthPx - floatingBaseWidthPx - marginRightPx
        val mainStartY = (screenHeightPx / 2f) - (floatingBaseHeightPx / 2f) // Usa float per divisione
        val mainStartPointPx = PointF(mainStartX, mainStartY)

        val expandedMenuWidthPx = (Dimens.ExpandedMenuWidth.value * density)
        val expandedMenuHeightPx = (Dimens.ExpandedMenuHeight.value * density)

        // Calcola la Y per l'Expanded in modo che i centri verticali coincidano
        val expandedStartY = mainStartY + (floatingBaseHeightPx / 2f) - (expandedMenuHeightPx / 2f)

        // Calcola la X per l'Expanded in modo che i centri orizzontali coincidano
        // Potrebbe farla uscire dallo schermo se la base è vicina al bordo!
        // val expandedStartX_Centered = mainStartX + (floatingBaseWidthPx / 2f) - (expandedMenuWidthPx / 2f)

        // Alternativa: Calcola la X per l'Expanded per allinearla al bordo SINISTRO della base
        // Questo è forse più sicuro vicino ai bordi
        val expandedStartX_AlignedLeft = mainStartX

        // Scegliamo l'allineamento a sinistra per ora, è più sicuro vicino ai bordi
        val expandedStartX = expandedStartX_AlignedLeft

        // Controlla se l'expanded esce dallo schermo a sinistra o destra con questa X
        val finalExpandedX = expandedStartX.coerceIn(0f, (screenWidthPx - expandedMenuWidthPx))
        // Controlla se l'expanded esce dallo schermo in alto o in basso con questa Y
        val finalExpandedY = expandedStartY.coerceIn(0f, (screenHeightPx - expandedMenuHeightPx))

        val expandedStartPointPx = PointF(finalExpandedX, finalExpandedY)
        Log.d(TAG, "Calculated Expanded Start Point (Px): $expandedStartPointPx")
        Log.d(TAG, "Screen(Px): ${screenWidthPx}x${screenHeightPx}, Density: $density")
        Log.d(TAG, "FloatingBase(Px): ${floatingBaseWidthPx}x${floatingBaseHeightPx}, MarginEnd(Px): $marginRightPx")
        Log.d(TAG, "Calculated Main Start Point (Px): $mainStartPointPx")
        // --- Fine Calcolo Posizione ---

        // 3. Costruisci e ritorna l'oggetto FloatingViewsConfig
        return FloatingViewsConfig(
            enableAnimations = true, // Manteniamo le animazioni

            // Configurazione per la bolla/pillola principale (visibile inizialmente)
            main = MainFloatConfig(
                composable = {
                    // Accedi allo stesso ViewModel ottenuto sopra
                    val vm = overlayViewModel
                    val uiState by vm.uiState.collectAsState()
                    // Chiama il tuo Composable per la vista base
                    FloatingBase(isRecording = uiState == OverlayViewModel.UiState.RECORDING)
                },
                isSnapToEdgeEnabled = true, // Aggancia ai bordi dopo trascinamento
                startPointPx = mainStartPointPx // Imposta la posizione iniziale calcolata
            ),

            // Configurazione per il cerchio di chiusura (appare trascinando)
            close = CloseFloatConfig(
                enabled = true, // Abilita il cerchio
                composable = { CloseFloater() }, // Usa il tuo Composable per l'aspetto
                // Puoi aggiungere altre opzioni come closingThresholdDp, bottomPaddingDp etc.
            ),

            // Configurazione per la vista espansa (appare al tocco sulla principale)
            expanded = ExpandedFloatConfig(
                enabled = true, // Abilita l'espansione
                tapOutsideToClose = true, // Chiudi toccando fuori
                dimAmount = 0.35f, // Oscuramento sfondo personalizzato
                composable = { closeCallback ->
                    // Accedi allo stesso ViewModel ottenuto sopra
                    val vm = overlayViewModel
                    // Chiama il tuo Composable per la vista espansa
                    ExpandedMenu(
                        viewModel = vm,
                        close = closeCallback
                    )
                },
                // !! NON impostiamo startPointPx qui !!
                // Ci affidiamo alla logica interna della libreria per posizionare
                // l'ExpandedMenu relativo alla posizione CORRENTE del MainFloat
                // quando viene toccato. Questo è l'approccio più probabile
                // per ottenere l'effetto "espansione da" e gestire il trascinamento.
                // Se il posizionamento di default della libreria non è soddisfacente
                // (esce dallo schermo, è molto disallineato), allora è un limite
                // della libreria o richiede un approccio più avanzato (se possibile).
                startPointPx = expandedStartPointPx
            )
        )
    }

    // Funzione per pulire il ViewModel Store quando il servizio viene fermato/distrutto
    fun clearOverlayViewModelStore() {
        Log.d(TAG, "Clearing OverlayViewModelStore...")
        overlayViewModelStoreOwner.viewModelStore.clear()
        currentViewModel = null // Rimuovi riferimento esplicito
    }
}