package com.test.transcrify.utils

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object SecureStorage {

    private const val TAG = "SecureStorage"
    private const val PREFS_FILE_NAME = "transcrify_secure_prefs"
    private const val KEY_GROQ_API = "groq_api_key"

    private suspend fun getEncryptedSharedPreferences(context: Context): EncryptedSharedPreferences =
        withContext(Dispatchers.IO) { // <--- Move to Dispatchers.IO
            try {
                val masterKey = MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()

                Log.d(TAG, "Creating EncryptedSharedPreferences instance")
                EncryptedSharedPreferences.create(
                    context,
                    PREFS_FILE_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
                ) as EncryptedSharedPreferences
            } catch (e: Exception) {
                Log.e(TAG, "Error creating EncryptedSharedPreferences", e)
                throw e // Re-throw the exception so that callers are aware of the problem
            }
        }


    suspend fun saveApiKey(context: Context, apiKey: String) = withContext(Dispatchers.IO) { // <--- Move to Dispatchers.IO
        try {
            if (apiKey.isBlank()) {
                // Opzionale: gestire il caso di salvataggio di chiave vuota (es. rimuovere)
                // getEncryptedSharedPreferences(context).edit().remove(KEY_GROQ_API).apply()
                return@withContext
            }
            Log.d(TAG, "Saving API Key securely")
            getEncryptedSharedPreferences(context).edit().putString(KEY_GROQ_API, apiKey).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving API Key", e)
        }
    }

    suspend fun getApiKey(context: Context): String = withContext(Dispatchers.IO) { // <--- Move to Dispatchers.IO
        try {
            Log.d(TAG, "Getting API Key securely")
            getEncryptedSharedPreferences(context).getString(KEY_GROQ_API, "") ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "Error getting API Key", e)
            "" // Or handle the error as you see fit - return a default value
        }
    }
}