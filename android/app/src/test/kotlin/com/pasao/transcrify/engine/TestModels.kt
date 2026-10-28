package com.pasao.transcrify.engine

import org.junit.Assume.assumeTrue
import java.io.File

/**
 * I modelli veri per i test sul PC. Non stanno nel repo (centinaia di MB): si scaricano in una
 * cartella fatta come quella dell'app, `<cartella>/preciso/…` e `<cartella>/leggero/…`, con gli
 * stessi nomi dei file, e la si indica con la variabile TRANSCRIFY_MODELS. Senza, i test che li
 * usano si saltano.
 *
 *   TRANSCRIFY_MODELS=C:/percorso/modelli ./gradlew :app:testDebugUnitTest --tests "com.pasao.transcrify.engine.*"
 *
 * I riferimenti calcolati con le librerie ufficiali si rifanno con gli script in `tool/motore/`.
 *
 * Su Windows ONNX Runtime vuole un msvcp140.dll dal 14.40 in su, e il Java di Android Studio ne
 * porta uno suo più vecchio (14.29) che carica all'avvio: ONNX Runtime si pianterebbe. Per i test
 * col modello si indica allora un altro Java con TRANSCRIFY_TEST_JAVA (per esempio Temurin 25:
 * `TRANSCRIFY_TEST_JAVA=C:/jdk-25/bin/java.exe`); senza, quei test si saltano invece di piantarsi.
 * Sul telefono non c'entra: lì la libreria C++ viaggia dentro l'app.
 */
object TestModels {
    val dir: File = File(System.getenv("TRANSCRIFY_MODELS") ?: System.getProperty("transcrify.models") ?: "modelli-assenti")

    /** Salta il test se questo Java farebbe piantare ONNX Runtime (vedi sopra). */
    fun assumeOnnxRuntimeLoads() {
        val dll = File(System.getProperty("java.home"), "bin/msvcp140.dll")
        if (!System.getProperty("os.name").startsWith("Windows") || !dll.exists()) return
        val (major, minor) = fileVersion(dll) ?: return
        assumeTrue(
            "questo Java porta msvcp140 $major.$minor, ONNX Runtime vuole almeno 14.40: indica un altro Java con TRANSCRIFY_TEST_JAVA",
            major > 14 || (major == 14 && minor >= 40),
        )
    }

    /** La versione di una DLL, dal blocco VS_FIXEDFILEINFO (si riconosce dalla firma 0xFEEF04BD). */
    private fun fileVersion(dll: File): Pair<Int, Int>? {
        val b = dll.readBytes()
        for (i in 0..b.size - 16) {
            if (le32(b, i) == 0xFEEF04BD.toInt()) return (le32(b, i + 8) ushr 16) to (le32(b, i + 8) and 0xFFFF)
        }
        return null
    }

    private fun le32(b: ByteArray, i: Int) =
        (b[i].toInt() and 0xFF) or ((b[i + 1].toInt() and 0xFF) shl 8) or ((b[i + 2].toInt() and 0xFF) shl 16) or ((b[i + 3].toInt() and 0xFF) shl 24)
}
