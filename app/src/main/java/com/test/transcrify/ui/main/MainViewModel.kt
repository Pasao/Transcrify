package com.test.transcrify.ui.main

import android.app.Application
// Rimuovi l'import se non serve più qui:
// import io.github.luiisca.floating.views.helpers.FloatingViewsManager
import android.content.Context // Serve ancora per Toast e SecureStorage
import android.util.Log
import android.widget.Toast
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.test.transcrify.R
//import com.test.transcrify.floating.OverlayConfigFactory
import com.test.transcrify.utils.SecureStorage
import io.github.luiisca.floating.views.helpers.FloatServiceStateManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull // Per leggere valore una tantum
import kotlinx.coroutines.launch

class MainViewModel(application: Application) : AndroidViewModel(application) {

    private val TAG = "MainViewModel"

    private val _apiKeyInput = MutableStateFlow("")
    val apiKeyInput: StateFlow<String> = _apiKeyInput.asStateFlow()

    val isServiceRunning: StateFlow<Boolean> = FloatServiceStateManager.isServiceRunning

    init {
        Log.d(TAG, "Initializing MainViewModel")
        loadInitialKey()
    }

    private fun loadInitialKey() {
        viewModelScope.launch {
            val key = SecureStorage.getApiKey(getApplication())
            Log.d(TAG, "Loaded initial API Key. Is blank: ${key.isBlank()}")
            _apiKeyInput.value = key
        }
    }

    fun updateApiKeyInput(newKey: String) {
        _apiKeyInput.value = newKey
    }

    fun saveApiKey() {
        val context = getApplication<Application>().applicationContext
        val keyToSave = _apiKeyInput.value.trim()
        if (keyToSave.isBlank()) {
            Toast.makeText(context, "La chiave API non può essere vuota", Toast.LENGTH_SHORT).show()
            return
        }
        viewModelScope.launch {
            SecureStorage.saveApiKey(context, keyToSave)
            Log.d(TAG, "API Key saved.")
            Toast.makeText(context, "Chiave API salvata", Toast.LENGTH_SHORT).show()
        }
    }

    // !! RIMOSSA LA LOGICA DI AVVIO SERVIZIO DA QUI !!
    // Questa funzione ora controlla solo la chiave API
    // Ritorna true se la chiave è valida, false altrimenti
    // La chiamata effettiva alla libreria avverrà nel Composable
    suspend fun canStartOverlay(): Boolean {
        val apiKey = SecureStorage.getApiKey(getApplication())
        val canStart = apiKey.isNotBlank()
        if (!canStart) {
            Log.w(TAG, "API Key is blank. Cannot start overlay.")
            // Mostriamo il Toast qui perché abbiamo il contesto dell'applicazione
            Toast.makeText(getApplication(), "Inserisci e salva prima la chiave API Groq", Toast.LENGTH_LONG).show()
        }
        return canStart
    }

    // Funzione per fermare il servizio (può rimanere qui se preferisci)
    // Anche se chiamarla dal Composable con LocalContext è coerente con l'avvio
    fun stopOverlayService() {
        val context = getApplication<Application>().applicationContext
        Log.d(TAG, "Attempting to stop service from ViewModel...")
        // ATTENZIONE: Questo potrebbe potenzialmente avere lo stesso problema
        // se stopFloatService facesse qualcosa che richiede Activity Context.
        // Per sicurezza, è meglio chiamare stop anche dal Composable.
        // FloatingViewsManager.stopFloatService(context) // Meglio spostare nel Composable
    }

    override fun onCleared() {
        super.onCleared()
        Log.d(TAG, "MainViewModel onCleared")
    }
}