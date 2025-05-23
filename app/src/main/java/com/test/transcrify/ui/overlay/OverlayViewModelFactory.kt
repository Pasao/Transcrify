package com.test.transcrify.ui.overlay

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

class OverlayViewModelFactory(
    private val application: Application,
    private val apiKey: String
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(OverlayViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return OverlayViewModel(application, apiKey) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}