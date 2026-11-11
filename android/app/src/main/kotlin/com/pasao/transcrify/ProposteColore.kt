package com.pasao.transcrify

import org.json.JSONObject

/**
 * «Colora da sola» propone, non cambia (10 nov, sua richiesta: «suggerimenti, non cambi silenziosi»). Con la regola
 * rigida ([com.pasao.transcrify.engine.ColoreRegole]) l'app calcola un colore per le trascrizioni senza colore, nuove
 * e di prima, ma non lo mette: lo tiene qui (quando → «tinta:luce») e in Trascrivi le vedi in cima, con ✓ e ✕.
 * Accettata prende il colore (e, se l'etichetta offusca sempre, diventa privata); rifiutata non si ripropone più
 * con quel colore. Senza Android: si prova.
 */
object ProposteColore {
    /** Una proposta rifiutata, da ricordare: quella trascrizione con quel colore. */
    fun chiave(at: Long, colore: String) = "$at=$colore"

    /**
     * Le proposte dopo un calcolo: [nuove] si aggiungono a [prima] (o, [tutte], la sostituiscono: le regole sono
     * cambiate), mai una che hai già rifiutato.
     */
    fun aggiorna(prima: Map<Long, String>, nuove: Map<Long, String>, rifiutate: Set<String>, tutte: Boolean): Map<Long, String> =
        (if (tutte) nuove else prima + nuove).filter { (at, c) -> chiave(at, c) !in rifiutate }

    /** Quelle che valgono ancora: la trascrizione c'è, è senza colore e non è privata (nel frattempo puoi averla toccata tu). */
    fun valide(proposte: Map<Long, String>, storia: List<Transcription>): Map<Long, String> {
        val libere = storia.filter { it.colorataDaSola("") != null }.map { it.at }.toSet()
        return proposte.filterKeys { it in libere }
    }

    /** Rifiutata: esce dalle proposte, e la sua [chiave] si ricorda in [rifiutate]. Torna (proposte, rifiutate). */
    fun rifiuta(proposte: Map<Long, String>, rifiutate: Set<String>, at: Long): Pair<Map<Long, String>, Set<String>> =
        (proposte - at) to (proposte[at]?.let { rifiutate + chiave(at, it) } ?: rifiutate)

    /** «Scarta tutte» (11 nov): ognuna come rifiutata, una per una ([rifiuta]). */
    fun rifiutaTutte(proposte: Map<Long, String>, rifiutate: Set<String>): Pair<Map<Long, String>, Set<String>> =
        proposte.keys.fold(proposte to rifiutate) { (p, r), at -> rifiuta(p, r, at) }

    /** Accettata: il colore come se l'avessi messo tu ([RegoleColori.segna]: «offusca sempre» la rende privata). */
    fun accetta(t: Transcription, colore: String, regole: Map<String, RegolaColore>): Transcription =
        if (t.colore != null) t else RegoleColori.segna(t, Segno(colore = true, nuovoColore = colore), regole)

    fun daJson(s: String?): Map<Long, String> = s?.let { JSONObject(it) }?.let { j ->
        j.keys().asSequence().associate { it.toLong() to j.getString(it) }
    } ?: emptyMap()

    fun inJson(proposte: Map<Long, String>): String = JSONObject(proposte.mapKeys { it.key.toString() }).toString()
}
