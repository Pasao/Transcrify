package com.pasao.transcrify

import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.snapshots.Snapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * «Detta qui» senza nessuna finestra di Compose (pillola mai uscita, o sepolta): il volume e i secondi scritti dalla
 * sessione devono arrivare a chi li guarda (lo `snapshotFlow` che li passa all'app), non restare fermi.
 */
class IstantaneeTest {
    @Test
    fun volumeESecondiArrivanoAncheSenzaFinestre() {
        val coda = ArrayDeque<Runnable>()
        Istantanee.avvia { coda.addLast(it) }
        val livello = mutableFloatStateOf(0f)
        val tempo = mutableLongStateOf(0)
        val visti = mutableListOf<Set<Any>>()
        val smetti = Snapshot.registerApplyObserver { cambiati, _ -> visti += cambiati }
        try {
            // Come il ticker della sessione: tre giri da 70 ms.
            for (giro in 1..3) {
                livello.floatValue = giro / 10f
                tempo.longValue = giro * 70L
                // Un avviso solo per giro, anche con due scritture.
                assertEquals(1, coda.size)
                coda.removeFirst().run()
            }
            assertEquals(3, visti.size)
            assertTrue(visti.all { livello in it && tempo in it })
        } finally {
            smetti.dispose()
        }
    }
}
