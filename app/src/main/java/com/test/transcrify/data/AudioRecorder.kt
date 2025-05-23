package com.test.transcrify.data

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

class AudioRecorder(private val context: Context) {

    private var mediaRecorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var startTimeMillis: Long = 0L
    private var _isRecording = false
    val isRecording: Boolean
        get() = _isRecording

    companion object {
        private const val TAG = "AudioRecorder"
        private const val FILENAME = "recording.m4a" // o .mp3, .ogg etc.
    }

    fun startRecording(): File? {
        if (_isRecording) {
            Log.w(TAG, "Already recording.")
            return outputFile
        }

        outputFile = File(context.cacheDir, FILENAME)
        Log.d(TAG, "Output file set to: ${outputFile?.absolutePath}")

        if (outputFile?.exists() == true) {
            if (outputFile!!.delete()) {
                Log.d(TAG, "Successfully deleted previous recording file.")
            } else {
                Log.w(TAG, "Failed to delete previous recording file.")
                // Potresti decidere di non procedere se la cancellazione fallisce?
                // Per ora, logghiamo solo e proviamo comunque.
            }
        }

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        mediaRecorder?.apply {
            try {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4) // Per .m4a
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000) // 16kHz
                setAudioChannels(1) // Mono
                setOutputFile(outputFile?.absolutePath)

                prepare()
                start()
                startTimeMillis = System.currentTimeMillis()
                _isRecording = true
                Log.d(TAG, "Recording started successfully.")
                return outputFile
            } catch (se: SecurityException) {
                    Log.e(TAG, "!!! SecurityException starting MediaRecorder !!! Likely permission or AppOps issue.", se)
                    // Gestisci errore
            } catch (e: IOException) {
                Log.e(TAG, "Prepare failed for MediaRecorder", e)
                release() // Pulisci in caso di errore
                outputFile?.delete()
                outputFile = null
                _isRecording = false
            } catch (e: IllegalStateException) {
                Log.e(TAG, "IllegalStateException for MediaRecorder", e)
                release()
                outputFile?.delete()
                outputFile = null
                _isRecording = false
            } catch (e: Exception) {
                Log.e(TAG, "Generic Exception starting MediaRecorder", e)
                release()
                outputFile?.delete()
                outputFile = null
                _isRecording = false
            }
        }
        return null // Se la registrazione non è partita
    }

    fun stopRecording(): File? {
        if (!_isRecording) {
            Log.w(TAG, "Not recording, cannot stop.")
            return null
        }
        try {
            mediaRecorder?.stop()
            mediaRecorder?.reset() // Resetta per poter riusare l'oggetto (o preparare di nuovo)
            _isRecording = false
            Log.d(TAG, "Recording stopped.")
            return outputFile // Ritorna il file registrato
        } catch (e: RuntimeException) { // stop() può lanciare RuntimeException
            Log.e(TAG, "RuntimeException on stop(). Recording might be corrupted.", e)
            outputFile?.delete() // File probabilmente inutile
            outputFile = null
            _isRecording = false
            mediaRecorder?.reset() // Prova a resettare comunque
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Exception on stop()", e)
            _isRecording = false
            mediaRecorder?.reset()
            return null // Non ritornare il file se c'è errore
        }
    }

    fun getCurrentDurationMillis(): Long {
        return if (_isRecording) {
            System.currentTimeMillis() - startTimeMillis
        } else {
            0L
        }
    }

    fun getCurrentFileSizeMb(): Double {
        return if (_isRecording && outputFile?.exists() == true) {
            outputFile!!.length() / (1024.0 * 1024.0) // Converti byte in MB (double)
        } else {
            0.0
        }
    }

    // Usato dopo stopRecording o cancel per ottenere la durata finale e resettare lo stato interno
    fun getDurationMillisAndReset(): Long {
        val duration = if (startTimeMillis > 0) System.currentTimeMillis() - startTimeMillis else 0L
        startTimeMillis = 0L
        // Non resettiamo _isRecording qui, viene fatto da stopRecording/cancel
        return duration
    }

    fun release() {
        Log.d(TAG, "Releasing MediaRecorder.")
        if (_isRecording) {
            try { mediaRecorder?.stop() } catch (e: Exception) { Log.e(TAG, "Error stopping on release", e)}
        }
        mediaRecorder?.release()
        mediaRecorder = null
        _isRecording = false
        startTimeMillis = 0L
        // Non cancelliamo outputFile qui, potrebbe servire per retry
    }
}