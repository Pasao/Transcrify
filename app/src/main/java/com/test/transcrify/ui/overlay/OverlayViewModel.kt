package com.test.transcrify.ui.overlay

import android.app.Application
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.test.transcrify.data.AudioRecorder // Assumi creato
import com.test.transcrify.data.DataStoreHelper // Assumi creato
import com.test.transcrify.data.TranscriptionRepository // Assumi creato
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import java.io.File
import java.util.Locale
import java.util.concurrent.TimeUnit

class OverlayViewModel(
    application: Application,
    private val apiKey: String,
    // Inietteremmo queste dipendenze con Hilt/Koin in un progetto completo
    // Per ora, le creiamo qui o le passiamo nel Factory (più semplice per ora)
    private val audioRecorder: AudioRecorder = AudioRecorder(application),
    private val repository: TranscriptionRepository = TranscriptionRepository(application, DataStoreHelper(application))
) : AndroidViewModel(application) {

    private val TAG = "OverlayViewModel"

    enum class UiState {
        IDLE, RECORDING, PROCESSING, ERROR, SUCCESS, LIMITED_HOURLY, LIMITED_DAILY
    }

    private val _uiState = MutableStateFlow(UiState.IDLE)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private val _recordingDurationFormatted = MutableStateFlow("00:00")
    val recordingDurationFormatted: StateFlow<String> = _recordingDurationFormatted.asStateFlow()

    private val _recordingSizeFormatted = MutableStateFlow("0 MB")
    val recordingSizeFormatted: StateFlow<String> = _recordingSizeFormatted.asStateFlow()

    private val _showCopyButton = MutableStateFlow(false)
    val showCopyButton: StateFlow<Boolean> = _showCopyButton.asStateFlow()

    private val _viewActions = MutableSharedFlow<ViewAction>()
    val viewActions: SharedFlow<ViewAction> = _viewActions.asSharedFlow()

    sealed class ViewAction {
        object CloseExpandedMenu : ViewAction()
        // data class ShowToast(val message: String): ViewAction() // Esempio per altri eventi
    }

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _limitStatusText = MutableStateFlow<String?>(null)
    val limitStatusText: StateFlow<String?> = _limitStatusText.asStateFlow()

    // Stato per la purificazione
    private val _isPurificationEnabled = MutableStateFlow(false) // Default a OFF
    val isPurificationEnabled: StateFlow<Boolean> = _isPurificationEnabled.asStateFlow()

    private var recordingJob: Job? = null
    private var currentAudioFile: File? = null
    private var audioFileForRetry: File? = null // File da usare se l'invio fallisce

    private val clipboardManager =
        application.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    init {
        Log.d(TAG, "Initializing - API Key present: ${apiKey.isNotEmpty()}")
        viewModelScope.launch {
            // Carica l'ultima trascrizione per mostrare/nascondere il pulsante copia
            repository.getLastTranscription().collect { transcription ->
                _showCopyButton.value = !transcription.isNullOrBlank()
            }
        }
        viewModelScope.launch { checkLimitsAndSetInitialState() }
    }

    // Funzione per attivare/disattivare la purificazione
    fun togglePurification(enabled: Boolean) {
        _isPurificationEnabled.value = enabled
        Log.d(TAG, "Purification enabled: $enabled")
    }

    private suspend fun checkLimitsAndSetInitialState() {
        Log.d(TAG, "Checking limits on init...")
        when (repository.checkUsageLimits()) {
            TranscriptionRepository.LimitStatus.OK -> {
                _uiState.value = UiState.IDLE
                _limitStatusText.value = null
                Log.d(TAG, "Limits OK.")
            }
            TranscriptionRepository.LimitStatus.HOURLY_EXCEEDED -> {
                _uiState.value = UiState.LIMITED_HOURLY
                _limitStatusText.value = "Limite Orario" // O testo più descrittivo
                Log.w(TAG, "Hourly limit reached.")
            }
            TranscriptionRepository.LimitStatus.DAILY_EXCEEDED -> {
                _uiState.value = UiState.LIMITED_DAILY
                _limitStatusText.value = "Limite Giornaliero" // O testo più descrittivo
                Log.w(TAG, "Daily limit reached.")
            }
        }
    }


    fun startRecording() {
        Log.d(TAG, "startRecording called")
        viewModelScope.launch {
            // Ricontrolla i limiti immediatamente prima di iniziare
            if (repository.checkUsageLimits() != TranscriptionRepository.LimitStatus.OK) {
                Log.w(TAG, "Attempted to record but limits reached.")
                checkLimitsAndSetInitialState() // Aggiorna UI allo stato LIMITED corretto
                return@launch
            }

            Log.d(TAG, "Cleaning up previous audio files before recording...")
            currentAudioFile?.delete()
            currentAudioFile = null
            audioFileForRetry?.delete()
            audioFileForRetry = null
            // Cancella anche il path salvato in DataStore, se esiste
            repository.saveRetryFilePath(null)

            // TODO: Verifica permesso RECORD_AUDIO qui

            try {
                currentAudioFile = audioRecorder.startRecording() // Ottiene il file dove si registra
                if (currentAudioFile == null) {
                    Log.e(TAG, "Failed to start recording, file is null")
                    _errorMessage.value = "Errore avvio registrazione"
                    _uiState.value = UiState.ERROR
                    return@launch
                }
                audioFileForRetry = null // Cancella il file precedente per retry
                _uiState.value = UiState.RECORDING
                startRecordingUpdates()
                Log.d(TAG, "Recording started: ${currentAudioFile?.absolutePath}")
            } catch (e: Exception) {
                Log.e(TAG, "Error starting recording", e)
                _errorMessage.value = "Errore: ${e.message}"
                _uiState.value = UiState.ERROR
                currentAudioFile = null // Assicura che non ci sia un file corrente
            }
        }
    }

    private fun startRecordingUpdates() {
        recordingJob?.cancel() // Cancella job precedente se esiste
        recordingJob = viewModelScope.launch {
            while (isActive && _uiState.value == UiState.RECORDING) {
                val durationMillis = audioRecorder.getCurrentDurationMillis()
                val fileSizeMb = audioRecorder.getCurrentFileSizeMb()

                _recordingDurationFormatted.value = formatDuration(durationMillis)
                _recordingSizeFormatted.value = String.format(Locale.US,"%.1f MB", fileSizeMb) // Formatta a 1 decimale

                // Controlla limite dimensione file (es. 39MB)
                if (fileSizeMb >= 39.0) {
                    Log.w(TAG, "Max file size reached (>= 39MB). Stopping recording.")
                    stopAndSend() // Ferma e invia automaticamente
                    break // Esce dal loop
                }

                // TODO: Controlla se la durata corrente + uso orario sfora il limite orario

                delay(500) // Aggiorna ogni mezzo secondo
            }
            Log.d(TAG, "Recording update loop finished.")
        }
    }

    private fun formatDuration(millis: Long): String {
        val minutes = TimeUnit.MILLISECONDS.toMinutes(millis)
        val seconds = TimeUnit.MILLISECONDS.toSeconds(millis) % 60
        return String.format(Locale.US,"%02d:%02d", minutes, seconds)
    }

    fun stopAndSend() {
        Log.d(TAG, "stopAndSend called")
        if (_uiState.value != UiState.RECORDING) {
            Log.w(TAG, "stopAndSend called but not in RECORDING state.")
            return
        }

        recordingJob?.cancel()
        recordingJob = null
        val isPurificationRequested = _isPurificationEnabled.value // Leggi lo stato del toggle

        viewModelScope.launch {
            var finalTranscription = "" // Variabile per il testo finale
            var transcriptionSuccessful = false
            val recordedFileRef = currentAudioFile // Riferimento temporaneo

            try {
                val recordedFile = audioRecorder.stopRecording() // Ottiene il file finale
                val durationMillis =
                    audioRecorder.getDurationMillisAndReset() // Prende durata e resetta recorder

                if (recordedFile == null) {
                    Log.e(TAG, "stopAndSend: Recorded file is null after stopping.")
                    _errorMessage.value = "Errore salvataggio audio"
                    _uiState.value = UiState.ERROR
                    return@launch
                }

                currentAudioFile = recordedFile // Assicura che abbiamo il riferimento corretto

                // Controlla durata minima (es. 50ms = 0.05s)
                if (durationMillis < 50) {
                    Log.w(TAG, "Recording too short (${durationMillis}ms). Deleting file.")
                    currentAudioFile?.delete()
                    currentAudioFile = null
                    audioFileForRetry = null
                    _uiState.value = UiState.IDLE // Torna a IDLE
                    // TODO: Mostrare messaggio "Troppo corto"?
                    return@launch
                }

                _uiState.value = UiState.PROCESSING
                Log.d(
                    TAG,
                    "Processing audio file: ${currentAudioFile?.name}, Duration: ${durationMillis}ms"
                )

                //--------------- Passo 1: Trascrizione ---------------
                val transcriptionResult = repository.transcribeAudio(apiKey, recordedFile)

                if (transcriptionResult.isSuccess) {
                    val rawTranscription = transcriptionResult.getOrNull() ?: ""
                    Log.i(TAG, "Raw Transcription SUCCESS: ${rawTranscription.take(50)}...")

                    if (rawTranscription.isBlank()) {
                        finalTranscription = "" // Trascrizione vuota, non purificare
                        transcriptionSuccessful = true
                    } else if (isPurificationRequested) {
                        Log.d(TAG, "Purification requested. Calling LLM...")
                        // --- Passo 2: Purificazione (se richiesta) ---
                        // Nota: Mostra ancora PROCESSING durante la purificazione
                        val purificationResult =
                            repository.purifyTranscription(apiKey, rawTranscription)
                        if (purificationResult.isSuccess) {
                            finalTranscription = purificationResult.getOrNull()
                                ?: rawTranscription // Usa purificata o fallback a grezza
                            Log.i(TAG, "Purification SUCCESS: ${finalTranscription.take(50)}...")
                            transcriptionSuccessful = true
                        } else {
                            Log.e(TAG, "Purification FAILED", purificationResult.exceptionOrNull())
                            // Errore durante la purificazione. Cosa fare?
                            // Opzione 1: Mostra errore specifico di purificazione
                            // _errorMessage.value = "Errore Purificazione: ${purificationResult.exceptionOrNull()?.message}"
                            // _uiState.value = UiState.ERROR
                            // Opzione 2: Usa la trascrizione grezza come fallback e segnala successo parziale?
                            _errorMessage.value =
                                "Purificazione fallita, testo grezzo usato." // Messaggio informativo
                            finalTranscription = rawTranscription // Fallback a grezza
                            transcriptionSuccessful = true // Considera comunque successo (parziale)
                        }
                    } else {
                        // Purificazione non richiesta, usa testo grezzo
                        finalTranscription = rawTranscription
                        transcriptionSuccessful = true
                    }

                    // --- Passo 3: Gestione Post-Successo ---
                    if (transcriptionSuccessful) {

                        repository.saveLastTranscription(finalTranscription) // Salva il testo finale
                        copyToClipboard() // Copia il testo finale //INVERTITO! FAI ATTENZIONE.
                        _showCopyButton.value = true
                        repository.updateUsageLimits(durationMillis)
                        recordedFile.delete() // Cancella file audio dopo successo
                        // currentAudioFile = null // Non serve più
                        audioFileForRetry = null
                        repository.saveRetryFilePath(null) // Pulisci path retry

                        _uiState.value = UiState.SUCCESS
                        delay(1000)
                        _viewActions.emit(ViewAction.CloseExpandedMenu)
                        checkLimitsAndSetInitialState()
                    }
                    // Se !transcriptionSuccessful ma eravamo nel blocco isSuccess di transcribeAudio,
                    // significa che la purificazione è fallita e abbiamo deciso di mostrare errore (vedi Opzione 1 sopra).
                    // In quel caso, lo stato è già ERROR.

                } else { // Trascrizione iniziale fallita
                    Log.e(
                        TAG,
                        "Initial Transcription FAILED",
                        transcriptionResult.exceptionOrNull()
                    )
                    _errorMessage.value =
                        transcriptionResult.exceptionOrNull()?.message ?: "Errore Trascrizione"
                    _uiState.value = UiState.ERROR
                    audioFileForRetry = recordedFile // Conserva per retry
                    // currentAudioFile = null
                    repository.saveRetryFilePath(audioFileForRetry) // Salva path per retry
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error in stopAndSend outer try-catch", e)
                _errorMessage.value = "Errore: ${e.message}"
                _uiState.value = UiState.ERROR
                if (recordedFileRef != null) { // Se avevamo un riferimento al file registrato
                    audioFileForRetry = recordedFileRef
                    repository.saveRetryFilePath(audioFileForRetry)
                }
                // currentAudioFile = null
            } finally {
                audioRecorder.getDurationMillisAndReset()
                if (_uiState.value != UiState.RECORDING) {
                    _recordingDurationFormatted.value = "00:00"
                    _recordingSizeFormatted.value = "0 MB"
                }
            }
        }
    }


    fun cancelOperation() {
        Log.d(TAG, "cancelOperation called, current state: ${_uiState.value}")
        recordingJob?.cancel()
        recordingJob = null

        viewModelScope.launch {
            // Cancella anche eventuali job di rete/processamento
            // (Questo è implicito se il job viene lanciato nello scope, ma per sicurezza)
            coroutineContext.cancelChildren() // Cancella job figli dello scope

            try {
                audioRecorder.stopRecording() // Prova a fermare se era attivo
            } catch (e: Exception) { Log.w(TAG, "Error stopping recorder on cancel: ${e.message}") }

            currentAudioFile?.delete()
            audioFileForRetry?.delete() // Cancella anche file per retry
            currentAudioFile = null
            audioFileForRetry = null

            _errorMessage.value = null
            // Resetta UI e ricontrolla limiti
            checkLimitsAndSetInitialState()
            // Resetta valori timer/size
            _recordingDurationFormatted.value = "00:00"
            _recordingSizeFormatted.value = "0 MB"
            Log.d(TAG, "Operation cancelled, state reset.")
        }
    }

    fun retryLastAudio() {
        Log.d(TAG, "retryLastAudio called")
        val fileToRetry = audioFileForRetry
        val isPurificationRequested = _isPurificationEnabled.value

        if (_uiState.value != UiState.ERROR || fileToRetry == null || !fileToRetry.exists()) {
            Log.w(TAG, "Retry called in invalid state or file missing/null.")
            _errorMessage.value = "Nessun audio da riprovare"
            // Potrebbe tornare a IDLE se non c'è nulla da fare
            viewModelScope.launch { checkLimitsAndSetInitialState() }
            return
        }

        viewModelScope.launch {
            var actualFileToRetry = fileToRetry
            if (actualFileToRetry == null || !actualFileToRetry.exists()) {
                Log.d(TAG, "audioFileForRetry is null or doesn't exist, checking DataStore...")
                actualFileToRetry = repository.getAndClearRetryFilePath() // Legge e cancella da DataStore
            }

            if (actualFileToRetry == null || !actualFileToRetry.exists()) {
                Log.w(TAG, "Retry: No valid audio file found locally or in DataStore.")
                _errorMessage.value = "Nessun audio da riprovare"
                audioFileForRetry = null // Assicura sia null
                checkLimitsAndSetInitialState()
                return@launch
            }

            // Trovato file valido, procedi con il retry
            audioFileForRetry = actualFileToRetry // Aggiorna variabile locale se letta da DataStore
            _uiState.value = UiState.PROCESSING
            _errorMessage.value = null
            Log.d(TAG, "Retrying audio file: ${actualFileToRetry.name}, Purify: $isPurificationRequested")

            var finalTranscription = ""
            var transcriptionSuccessful = false

            // --- Passo 1: Trascrizione Retry ---
            val transcriptionResult = repository.transcribeAudio(apiKey, actualFileToRetry)

            if (transcriptionResult.isSuccess) {
                val rawTranscription = transcriptionResult.getOrNull() ?: ""
                Log.i(TAG, "Retry Raw Transcription SUCCESS: ${rawTranscription.take(50)}...")

                if (rawTranscription.isBlank()) {
                    finalTranscription = ""
                    transcriptionSuccessful = true
                } else if (isPurificationRequested) {
                    Log.d(TAG, "Retry Purification requested...")
                    // --- Passo 2: Purificazione Retry ---
                    val purificationResult = repository.purifyTranscription(apiKey, rawTranscription)
                    if (purificationResult.isSuccess) {
                        finalTranscription = purificationResult.getOrNull() ?: rawTranscription
                        Log.i(TAG, "Retry Purification SUCCESS: ${finalTranscription.take(50)}...")
                        transcriptionSuccessful = true
                    } else {
                        Log.e(TAG, "Retry Purification FAILED", purificationResult.exceptionOrNull())
                        _errorMessage.value = "Purificazione fallita, testo grezzo usato."
                        finalTranscription = rawTranscription
                        transcriptionSuccessful = true // Successo parziale
                    }
                } else {
                    finalTranscription = rawTranscription
                    transcriptionSuccessful = true
                }

                // --- Passo 3: Gestione Successo Retry ---
                if(transcriptionSuccessful) {
                    repository.saveLastTranscription(finalTranscription)
                    copyToClipboard() //INVERTITO
                    _showCopyButton.value = true
                    // Non aggiorniamo i limiti nel retry
                    actualFileToRetry.delete()
                    audioFileForRetry = null
                    repository.saveRetryFilePath(null) // Pulisci path

                    _uiState.value = UiState.SUCCESS
                    delay(1000)
                    _viewActions.emit(ViewAction.CloseExpandedMenu)
                    checkLimitsAndSetInitialState()
                }

            } else { // Trascrizione Retry fallita
                Log.e(TAG, "Retry Initial Transcription FAILED", transcriptionResult.exceptionOrNull())
                _errorMessage.value = transcriptionResult.exceptionOrNull()?.message ?: "Errore Retry Trascrizione"
                _uiState.value = UiState.ERROR
                // Lascia audioFileForRetry e il path in DataStore intatti per riprovare ancora
                // Nota: getAndClearRetryFilePath lo ha già cancellato, quindi dobbiamo risalvarlo
                repository.saveRetryFilePath(actualFileToRetry)
            }
        }
    }

    fun copyToClipboard() {
        viewModelScope.launch(Dispatchers.IO) { // Leggi da repo su IO
            val textToCopy = repository.getLastTranscription().firstOrNull()
            if (!textToCopy.isNullOrBlank()) {
                withContext(Dispatchers.Main) { // Interagisci con ClipboardManager su Main
                    val clip = ClipData.newPlainText("Trascrizione", textToCopy)
                    clipboardManager.setPrimaryClip(clip)
                    Log.d(TAG, "Text copied to clipboard.")
                    // TODO: Mostrare un Toast? (Difficile da Service/ViewModel)
                    // Potremmo usare un altro StateFlow per un messaggio transitorio
                }
            } else {
                Log.w(TAG, "copyToClipboard called but no text available.")
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        Log.d(TAG, "onCleared called - releasing resources")
        recordingJob?.cancel()
        audioRecorder.release() // Assicura che il recorder sia rilasciato
        // Non cancelliamo i file qui, potrebbero servire per retry se l'app viene chiusa forzatamente
    }
}

// TODO: Gestire Toast/Feedback da ViewModel (alternativa?)
// TODO: Salvare durata audio per aggiornare limiti correttamente nel retry