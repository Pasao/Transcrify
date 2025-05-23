package com.test.transcrify.data

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import retrofit2.HttpException
import retrofit2.Response
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class TranscriptionRepository(
    private val context: Context, // Potrebbe servire per vari motivi
    private val dataStoreHelper: DataStoreHelper,
    // Inietteremmo Retrofit/ApiService in un progetto reale
    private val apiService: GroqApiService = RetrofitClient.instance // Assumi un singleton RetrofitClient
) {

    private val TAG = "TranscriptionRepository"

    // Enum per lo stato dei limiti
    enum class LimitStatus { OK, HOURLY_EXCEEDED, DAILY_EXCEEDED }

    // --- Funzioni di Trascrizione ---

    suspend fun transcribeAudio(apiKey: String, audioFile: File): Result<String> = withContext(Dispatchers.IO) {
        Log.d(TAG, "Attempting to transcribe file: ${audioFile.name}")
        if (!audioFile.exists() || audioFile.length() == 0L) {
            Log.e(TAG, "Audio file does not exist or is empty.")
            return@withContext Result.failure(IOException("File audio non valido o vuoto"))
        }

        try {
            // 1. Prepara le parti della richiesta Multipart (come prima)
            val requestFile = audioFile.asRequestBody("audio/m4a".toMediaTypeOrNull()) // Verifica MIME type!
            val filePart = MultipartBody.Part.createFormData("file", audioFile.name, requestFile)
            val modelPart = "whisper-large-v3".toTextRequestBody()
            val responseFormatPart = "json".toTextRequestBody()
            // val languagePart = ...

            // 2. Esegui la chiamata API (come prima)
            val response = apiService.transcribeAudio(
                apiKey = "Bearer $apiKey",
                file = filePart,
                model = modelPart,
                responseFormat = responseFormatPart
                // language = languagePart
            )

            // 3. Gestisci la risposta CORRETTAMENTE
            if (response.isSuccessful) { // Controlla se la chiamata HTTP ha avuto successo (status 2xx)
                val transcriptionResponse = response.body() // Ottieni il corpo deserializzato (TranscriptionResponse?)
                val transcriptionText = transcriptionResponse?.text // Estrai il testo

                if (!transcriptionText.isNullOrBlank()) {
                    Log.i(TAG, "Transcription successful.")
                    dataStoreHelper.saveLastTranscription(transcriptionText)
                    Result.success(transcriptionText) // Ritorna il testo trascritto
                } else {
                    // Successo HTTP, ma corpo vuoto o senza testo
                    Log.w(TAG, "API call successful (code ${response.code()}) but response body or text is null/blank.")
                    Result.failure(IOException("Risposta API valida ma vuota"))
                }
            } else { // La chiamata HTTP NON ha avuto successo (status 4xx, 5xx)
                val errorBody = response.errorBody()?.string() ?: "Nessun corpo dell'errore disponibile"
                Log.e(TAG, "API Error: Status Code ${response.code()} - Body: $errorBody")
                // Crea un'eccezione più specifica o usa HttpException
                Result.failure(IOException("Errore API ${response.code()}: $errorBody"))
                // In alternativa, per mantenere HttpException: Result.failure(HttpException(response))
            }

        } catch (e: IOException) {
            Log.e(TAG, "Network/IO Error during transcription", e)
            Result.failure(e) // Errori di rete o file
        } catch (e: HttpException) { // Cattura specificamente errori HTTP se usi HttpException sopra
            Log.e(TAG, "HTTP Error during transcription: ${e.code()}", e)
            Result.failure(e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected Error during transcription", e)
            Result.failure(e) // Altri errori (es. problemi deserializzazione JSON)
        }
        // La chiusura della lambda withContext è qui
    }

    // --- Funzioni di Persistenza ---

    fun getLastTranscription(): Flow<String?> = dataStoreHelper.lastTranscriptionFlow
    suspend fun saveLastTranscription(text: String) = dataStoreHelper.saveLastTranscription(text)
    suspend fun saveRetryFilePath(file: File?) = dataStoreHelper.saveRetryFilePath(file?.absolutePath)
    suspend fun getAndClearRetryFilePath(): File? {
        val path = dataStoreHelper.getRetryFilePath()
        dataStoreHelper.saveRetryFilePath(null) // Cancella subito dopo aver letto
        return path?.let { File(it) }?.takeIf { it.exists() } // Ritorna File se esiste
    }


    // --- Funzioni Gestione Limiti ---

    suspend fun checkUsageLimits(): LimitStatus = withContext(Dispatchers.Default) {
        val now = System.currentTimeMillis()
        val hourlyUsage = dataStoreHelper.getHourlyUsageSeconds()
        val hourlyTimestamp = dataStoreHelper.getHourlyPeriodTimestamp()
        val dailyUsage = dataStoreHelper.getDailyUsageSeconds()
        val dailyTimestamp = dataStoreHelper.getDailyPeriodTimestamp()

        val oneHourMillis = TimeUnit.HOURS.toMillis(1)
        val oneDayMillis = TimeUnit.DAYS.toMillis(1)

        val hourLimit = 7200L
        val dayLimit = 28000L

        var resetHourly = false
        var resetDaily = false

        // Controlla reset orario
        if (hourlyTimestamp > 0 && now >= hourlyTimestamp + oneHourMillis) {
            Log.d(TAG, "Hourly limit period expired. Resetting hourly usage.")
            resetHourly = true
        }

        // Controlla reset giornaliero
        if (dailyTimestamp > 0 && now >= dailyTimestamp + oneDayMillis) {
            Log.d(TAG, "Daily limit period expired. Resetting daily usage.")
            resetDaily = true
        }

        // Applica i reset se necessario
        if (resetHourly) dataStoreHelper.saveHourlyLimitData(0L, 0L) // Resetta tempo e timestamp
        if (resetDaily) dataStoreHelper.saveDailyLimitData(0L, 0L)   // Resetta tempo e timestamp

        // Rileggi i valori dopo eventuali reset
        val currentHourlyUsage = if (resetHourly) 0L else hourlyUsage
        val currentDailyUsage = if (resetDaily) 0L else dailyUsage

        // Controlla i limiti
        if (currentDailyUsage >= dayLimit && dailyTimestamp > 0) { // Assicurati che il timestamp sia valido
            return@withContext LimitStatus.DAILY_EXCEEDED
        }
        if (currentHourlyUsage >= hourLimit && hourlyTimestamp > 0) {
            return@withContext LimitStatus.HOURLY_EXCEEDED
        }

        return@withContext LimitStatus.OK
    }

    suspend fun updateUsageLimits(durationMillis: Long) = withContext(Dispatchers.Default) {
        if (durationMillis <= 0) return@withContext // Non fare nulla se la durata non è valida

        val now = System.currentTimeMillis()
        val durationSeconds = TimeUnit.MILLISECONDS.toSeconds(durationMillis)
        Log.d(TAG, "Updating usage limits by ${durationSeconds}s")

        var currentHourlyUsage = dataStoreHelper.getHourlyUsageSeconds()
        var currentHourlyTimestamp = dataStoreHelper.getHourlyPeriodTimestamp()
        var currentDailyUsage = dataStoreHelper.getDailyUsageSeconds()
        var currentDailyTimestamp = dataStoreHelper.getDailyPeriodTimestamp()

        // Aggiornamento Orario
        if (currentHourlyTimestamp == 0L) { // Primo uso nell'ora
            currentHourlyTimestamp = now
        }
        currentHourlyUsage += durationSeconds
        dataStoreHelper.saveHourlyLimitData(currentHourlyUsage, currentHourlyTimestamp)
        Log.d(TAG, "New Hourly Usage: ${currentHourlyUsage}s (Timestamp: $currentHourlyTimestamp)")


        // Aggiornamento Giornaliero
        if (currentDailyTimestamp == 0L) { // Primo uso nel giorno
            currentDailyTimestamp = now
        }
        currentDailyUsage += durationSeconds
        dataStoreHelper.saveDailyLimitData(currentDailyUsage, currentDailyTimestamp)
        Log.d(TAG, "New Daily Usage: ${currentDailyUsage}s (Timestamp: $currentDailyTimestamp)")
    }

    // --- Funzione per Purificazione Testo ---
    suspend fun purifyTranscription(apiKey: String, rawText: String): Result<String> = withContext(Dispatchers.IO) {
        Log.d(TAG, "Attempting to purify text...")

        // Definisci il prompt di sistema
        val systemPrompt = """
    Sei un assistente AI specializzato nella pulizia e formattazione di trascrizioni audio grezze.

Il tuo compito è prendere il testo fornito, che proviene da una trascrizione automatica, e:
- riscriverlo in modo chiaro, grammaticalmente corretto e ben strutturato;
- aggiungere la punteggiatura appropriata (virgole, punti, punti interrogativi, ecc.);
- suddividere il testo in paragrafi logici per migliorarne la leggibilità;
- correggere eventuali errori grammaticali minori, senza alterare il significato originale;
- mantenere il linguaggio e il tono naturale del parlato originale;
- eliminare ripetizioni inutili, filler, esitazioni, perifrasi e tutto ciò che non aggiunge contenuto reale, ma **senza cambiare il modo di parlare** dell’originale.
- selezionare solo le informazioni realmente importanti o discorsive, scartando ciò che è superfluo o ridondante;

In altre parole, rendi il testo più scorrevole ed essenziale, ma resta fedele al linguaggio e allo stile con cui è stato detto.

NON aggiungere commenti, intestazioni o introduzioni tue. Rispondi SOLO con il testo purificato e condensato.
    """.trimIndent()

        // Crea la lista di messaggi per l'API Chat
        val messages = listOf(
            ChatMessage(role = "system", content = systemPrompt),
            ChatMessage(role = "user", content = rawText) // Il testo grezzo è l'input dell'utente
        )

        // Crea l'oggetto della richiesta
        val request = ChatCompletionRequest(
            model = "llama-3.3-70b-versatile", // Modello scelto //llama3-70b-8192
            messages = messages,
            temperature = 0.2, // Bassa temperatura per risposte più deterministiche/formali
            max_tokens = 6000, // Imposta un limite se necessario
            // top_p = 0.9
        )

        try {
            // Esegui la chiamata API Chat Completion
            val response = apiService.createChatCompletion("Bearer $apiKey", request)

            if (response.isSuccessful) {
                val purifiedText = response.body()?.choices?.firstOrNull()?.message?.content
                if (!purifiedText.isNullOrBlank()) {
                    Log.i(TAG, "Purification successful.")
                    Result.success(purifiedText.trim()) // Rimuovi spazi bianchi iniziali/finali
                } else {
                    Log.w(TAG, "Purification successful but response content is null or blank.")
                    Result.failure(IOException("Risposta LLM vuota"))
                }
            } else {
                val errorBody = response.errorBody()?.string() ?: "Errore sconosciuto LLM"
                Log.e(TAG, "LLM API Error: ${response.code()} - $errorBody")
                Result.failure(IOException("Errore LLM ${response.code()}: $errorBody"))
            }
        } catch (e: IOException) {
            Log.e(TAG, "Network/IO Error during purification", e)
            Result.failure(e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected Error during purification", e)
            Result.failure(e)
        }
    }
}