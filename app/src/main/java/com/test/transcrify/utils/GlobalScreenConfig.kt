package com.test.transcrify.utils

import android.content.Context
import android.util.Log

object GlobalScreenConfig {
    private var isInitialized = false

    // Variabili globali
    var screenWidthPx: Float = 0f
        private set
    var screenWidthDp: Float = 0f
        private set
    var screenHeightPx: Float = 0f
        private set
    var screenHeightDp: Float = 0f
        private set
    var density: Float = 0f
        private set

    // Inizializzazione con un Context
    fun initialize(context: Context) {
        if (!isInitialized) {
            val displayMetrics = context.resources.displayMetrics
            screenWidthPx = displayMetrics.widthPixels.toFloat()
            screenHeightPx = displayMetrics.heightPixels.toFloat()
            density = displayMetrics.density
            screenWidthDp = screenWidthPx / density
            screenHeightDp = screenHeightPx / density
            isInitialized = true
            Log.d("GlobalScreenConfig", "Initialized: widthDp=$screenWidthDp, heightDp=$screenHeightDp, density=$density")
        }
    }

    // Funzione helper per ottenere un’altezza percentuale (non richiede Context dopo inizializzazione)
    fun heightPercentageDp(percentage: Float): Float {
        checkInitialized()
        return screenHeightDp * percentage
    }

    fun widthPercentageDp(percentage: Float): Float {
        checkInitialized()
        return screenWidthDp * percentage
    }

    // Controllo per assicurarsi che sia inizializzato
    private fun checkInitialized() {
        if (!isInitialized) {
            throw IllegalStateException("GlobalScreenConfig non è stato inizializzato. Chiama initialize(context) prima.")
        }
    }
}