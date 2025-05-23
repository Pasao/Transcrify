package com.test.transcrify

import android.app.Application
import com.test.transcrify.utils.GlobalScreenConfig // Importa il tuo oggetto

class TranscrifyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // ---> INIZIALIZZA QUI <---
        GlobalScreenConfig.initialize(this)
        println("TranscrifyApplication onCreate: GlobalScreenConfig initialized.")
        // Qui puoi fare altre inizializzazioni globali (es. Librerie di logging, Dependency Injection, etc.)
    }
}