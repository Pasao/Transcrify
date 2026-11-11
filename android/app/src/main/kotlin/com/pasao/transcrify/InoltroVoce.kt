package com.pasao.transcrify

/**
 * Quello che Transcri sta facendo va a Flutter (11 nov, suo: «l'onda va a scatti»): prima partiva a ogni cambio del
 * volume, decine di volte al secondo, sul thread principale, lo stesso che disegna la pillola. Ora un cambio di stato
 * (fase, secondi, pausa, errore) parte subito; il solo volume al più ogni [Durate.VOCE_MS] (circa 30 al secondo, quanto
 * basta all'onda di Flutter). La pillola nativa il volume lo legge da sé, senza aspettare niente.
 */
object InoltroVoce {
    const val VOLUME = "level"

    fun daMandare(prima: Map<String, Any?>?, ora: Map<String, Any?>, msDaUltima: Long): Boolean =
        prima == null || (ora - VOLUME) != (prima - VOLUME) || msDaUltima >= Durate.VOCE_MS
}
