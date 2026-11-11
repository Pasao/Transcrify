package com.pasao.transcrify

import androidx.compose.runtime.snapshots.Snapshot
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Lo stato della sessione (fase, volume, secondi) sta in variabili di Compose, e chi lo guarda ([PillService] con
 * `snapshotFlow`, per l'app) viene avvisato solo quando qualcuno «manda gli avvisi» delle scritture. Di solito lo fa
 * Compose stesso, ma solo dopo che una sua finestra si è vista almeno una volta. Con l'app appena aperta e Transcri
 * nel Dock (nessuna pillola mai uscita, es. dopo il cambio dati finti/veri in Prove, che riavvia tutto) nessuno li
 * mandava: «Detta qui» partiva, ma il tempo, l'onda e Transcri restavano fermi. Qui li mandiamo noi, sempre.
 */
object Istantanee {
    private val avviato = AtomicBoolean(false)
    private val inArrivo = AtomicBoolean(false)

    /** Una volta per processo. [dopo] mette in coda un lavoro sul thread principale (`Handler.post`). */
    fun avvia(dopo: (Runnable) -> Unit) {
        if (!avviato.compareAndSet(false, true)) return
        Snapshot.registerGlobalWriteObserver {
            // Tante scritture di fila (ogni 70 ms il volume e i secondi) diventano un avviso solo.
            if (inArrivo.compareAndSet(false, true)) dopo(Runnable {
                inArrivo.set(false)
                Snapshot.sendApplyNotifications()
            })
        }
    }
}
