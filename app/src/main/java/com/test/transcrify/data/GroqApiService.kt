package com.test.transcrify.data // O il tuo package network/data

import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.Response
import retrofit2.http.*
import retrofit2.Retrofit // Import classe Retrofit
import retrofit2.converter.gson.GsonConverterFactory // Import converter Gson
import okhttp3.OkHttpClient // Import OkHttp
import okhttp3.logging.HttpLoggingInterceptor // Import interceptor (se lo usi)

// Data class per mappare la risposta JSON (anche verbose se necessario)
// Se usi response_format="verbose_json", la struttura sarà più complessa
// Se usi solo "json", basta `val text: String?`
data class TranscriptionResponse(
    val text: String?
    // Aggiungi altri campi se usi "verbose_json" e ti servono (es. language, duration, segments, words)
    // val language: String? = null,
    // val duration: Double? = null,
    // val segments: List<Segment>? = null, // Dovresti definire la data class Segment
    // val words: List<Word>? = null // Dovresti definire la data class Word
)

data class ChatCompletionRequest(
    val model: String,
    val messages: List<ChatMessage>,
    val temperature: Double? = null, // Rendi opzionali altri parametri
    val max_tokens: Int? = null,
    val top_p: Double? = null,
    val stop: List<String>? = null,
    val stream: Boolean? = false
)

data class ChatMessage(
    val role: String, // "system", "user", "assistant"
    val content: String
)

data class ChatCompletionResponse(
    val choices: List<ChatChoice>?,
    val usage: UsageInfo?, // Opzionale per info token
    val id: String?, // Opzionale
    // Aggiungi altri campi se necessario
)

data class ChatChoice(
    val index: Int?,
    val message: ChatMessage?,
    val finish_reason: String?
)

data class UsageInfo(
    val prompt_tokens: Int?,
    val completion_tokens: Int?,
    val total_tokens: Int?
)

interface GroqApiService {

    companion object {
        const val BASE_URL = "https://api.groq.com/openai/v1/"
    }

    @Multipart // Richiesta multipart/form-data
    @POST("audio/transcriptions") // Endpoint
    suspend fun transcribeAudio(
        // 1. Header di Autenticazione
        @Header("Authorization") apiKey: String, // Formato "Bearer TUACHIAVE"

        // 2. File Audio (Obbligatorio)
        // Usa @Part. Il nome "file" nel createFormData deve corrispondere al nome del campo API.
        @Part file: MultipartBody.Part,

        // 3. Modello (Obbligatorio)
        // Usa @Part. Passiamo il nome del modello come RequestBody di tipo text/plain.
        @Part("model") model: RequestBody, // Es: "whisper-large-v3".toRequestBody("text/plain".toMediaTypeOrNull())

        // 4. Parametri Opzionali (come @Part)
        // Retrofit gestirà l'omissione se il valore è null.

        // Il formato della risposta (opzionale, default "json")
        @Part("response_format") responseFormat: RequestBody? = null, // Es: "verbose_json".toRequestBody(...)

        // La lingua dell'audio (opzionale)
        @Part("language") language: RequestBody? = null, // Es: "it".toRequestBody(...)

        // Prompt per guidare il modello (opzionale)
        @Part("prompt") prompt: RequestBody? = null, // Es: "Contesto specifico...".toRequestBody(...)

        // Temperatura (opzionale, default 0)
        @Part("temperature") temperature: RequestBody? = null, // Es: "0.2".toRequestBody(...)

        // Granularità Timestamp (opzionale, array, richiede response_format="verbose_json")
        // Retrofit gestisce le liste per i campi array se il nome finisce con []
        // MA per multipart è più sicuro inviarli come parti separate con lo stesso nome
        // o vedere se la libreria accetta una singola stringa separata da virgole.
        // Per semplicità, lo omettiamo qui, ma se necessario, si invia ogni valore come @Part("timestamp_granularities[]")
        // @Part("timestamp_granularities[]") timestampGranularities: List<RequestBody>? = null

    ): Response<TranscriptionResponse> // Ritorna la Response per controllare lo status code

    // --- Metodo Chat Completion (Nuovo) ---
    @POST("chat/completions") // Nuovo endpoint
    @Headers("Content-Type: application/json") // Imposta Content-Type JSON
    suspend fun createChatCompletion(
        @Header("Authorization") apiKey: String, // Stessa chiave API
        @Body request: ChatCompletionRequest // Passa il corpo della richiesta come JSON
    ): Response<ChatCompletionResponse> // Risposta specifica per chat
}

// Nello stesso file o in un file separato (es. RetrofitClient.kt)

// Helper per creare RequestBody da String
fun String.toTextRequestBody(): RequestBody =
    this.toRequestBody("text/plain".toMediaTypeOrNull())

// Singleton per l'istanza di Retrofit (o usa Hilt/Koin)
object RetrofitClient {
    val instance: GroqApiService by lazy {
        val logging = okhttp3.logging.HttpLoggingInterceptor().apply {
            level = okhttp3.logging.HttpLoggingInterceptor.Level.BODY // Logga corpo richiesta/risposta
        }
        val client = okhttp3.OkHttpClient.Builder()
            .addInterceptor(logging)
            // Aumenta i timeout se le trascrizioni sono lunghe
            .connectTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(60, java.util.concurrent.TimeUnit.SECONDS)
            .build()

        retrofit2.Retrofit.Builder()
            .baseUrl(GroqApiService.BASE_URL)
            .client(client)
            .addConverterFactory(retrofit2.converter.gson.GsonConverterFactory.create()) // Usa Gson
            .build()
            .create(GroqApiService::class.java)
    }
}