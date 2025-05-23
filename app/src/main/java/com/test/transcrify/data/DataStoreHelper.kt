package com.test.transcrify.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.io.IOException

// Definisci l'istanza DataStore a livello di file (singleton per context)
private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "transcrify_settings")

class DataStoreHelper(private val context: Context) {

    // --- Chiavi per le Preferenze ---
    private object PrefKeys {
        val LAST_TRANSCRIPTION = stringPreferencesKey("last_transcription")
        val HOURLY_USAGE_SECONDS = longPreferencesKey("hourly_usage_seconds")
        val HOURLY_PERIOD_TIMESTAMP = longPreferencesKey("hourly_period_timestamp")
        val DAILY_USAGE_SECONDS = longPreferencesKey("daily_usage_seconds")
        val DAILY_PERIOD_TIMESTAMP = longPreferencesKey("daily_period_timestamp")
        val RETRY_FILE_PATH = stringPreferencesKey("retry_file_path") // Salviamo il path come stringa
    }

    // --- Funzioni per interagire con DataStore ---

    // Ultima Trascrizione
    val lastTranscriptionFlow: Flow<String?> = context.dataStore.data
        .catch { exception -> // Gestisci errori di lettura
            if (exception is IOException) emit(emptyPreferences()) else throw exception
        }
        .map { preferences -> preferences[PrefKeys.LAST_TRANSCRIPTION] }

    suspend fun saveLastTranscription(transcription: String) {
        context.dataStore.edit { settings ->
            settings[PrefKeys.LAST_TRANSCRIPTION] = transcription
        }
    }

    // Limiti Orari
    val hourlyUsageSecondsFlow: Flow<Long> = context.dataStore.data.map { it[PrefKeys.HOURLY_USAGE_SECONDS] ?: 0L }
    val hourlyPeriodTimestampFlow: Flow<Long> = context.dataStore.data.map { it[PrefKeys.HOURLY_PERIOD_TIMESTAMP] ?: 0L }

    suspend fun saveHourlyLimitData(usageSeconds: Long, timestamp: Long) {
        context.dataStore.edit { settings ->
            settings[PrefKeys.HOURLY_USAGE_SECONDS] = usageSeconds
            settings[PrefKeys.HOURLY_PERIOD_TIMESTAMP] = timestamp
        }
    }

    // Limiti Giornalieri
    val dailyUsageSecondsFlow: Flow<Long> = context.dataStore.data.map { it[PrefKeys.DAILY_USAGE_SECONDS] ?: 0L }
    val dailyPeriodTimestampFlow: Flow<Long> = context.dataStore.data.map { it[PrefKeys.DAILY_PERIOD_TIMESTAMP] ?: 0L }

    suspend fun saveDailyLimitData(usageSeconds: Long, timestamp: Long) {
        context.dataStore.edit { settings ->
            settings[PrefKeys.DAILY_USAGE_SECONDS] = usageSeconds
            settings[PrefKeys.DAILY_PERIOD_TIMESTAMP] = timestamp
        }
    }

    // File per Retry
    val retryFilePathFlow: Flow<String?> = context.dataStore.data.map { it[PrefKeys.RETRY_FILE_PATH] }

    suspend fun saveRetryFilePath(path: String?) {
        context.dataStore.edit { settings ->
            if (path == null) settings.remove(PrefKeys.RETRY_FILE_PATH)
            else settings[PrefKeys.RETRY_FILE_PATH] = path
        }
    }

    // Helper per leggere un valore una tantum (utile per check iniziali)
    suspend fun getHourlyUsageSeconds(): Long = hourlyUsageSecondsFlow.first()
    suspend fun getHourlyPeriodTimestamp(): Long = hourlyPeriodTimestampFlow.first()
    suspend fun getDailyUsageSeconds(): Long = dailyUsageSecondsFlow.first()
    suspend fun getDailyPeriodTimestamp(): Long = dailyPeriodTimestampFlow.first()
    suspend fun getRetryFilePath(): String? = retryFilePathFlow.first()

}