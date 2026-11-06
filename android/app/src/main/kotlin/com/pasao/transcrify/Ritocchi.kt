package com.pasao.transcrify

// I ritocchi alla lista delle trascrizioni (dalla più nuova): calcoli puri, senza file, così si provano da soli.
// Li usa lo Store, che poi scrive la lista una volta sola.

/** Le trascrizioni in [ats] cambiate con [come]; le altre restano com'erano. */
fun segna(storia: List<Transcription>, ats: Set<Long>, come: (Transcription) -> Transcription): List<Transcription> =
    storia.map { if (it.at in ats) come(it) else it }

/**
 * Unisce le trascrizioni in [ordine] (la prima è quella da cui sei partito): i testi nell'ordine scelto,
 * separati da una riga vuota. La nuova tiene il giorno della più vecchia (il suo «at») e, della prima,
 * colore, privata, modo e provenienza. Le altre se ne vanno. Null se non ce ne sono almeno due.
 */
fun unisci(storia: List<Transcription>, ordine: List<Long>): Pair<List<Transcription>, Transcription>? {
    val perAt = storia.associateBy { it.at }
    val scelte = ordine.distinct().mapNotNull { perAt[it] }
    if (scelte.size < 2) return null
    val fusa = scelte.first().copy(
        text = scelte.joinToString("\n\n") { it.text.trim() },
        at = scelte.minOf { it.at },
    )
    val via = scelte.map { it.at }.toSet()
    return ordina(storia.filter { it.at !in via } + fusa) to fusa
}

/** Rimette [voci] com'erano: prendono il posto di quelle con lo stesso «at», le mancanti tornano. */
fun rimetti(storia: List<Transcription>, voci: List<Transcription>): List<Transcription> {
    val loro = voci.map { it.at }.toSet()
    return ordina(storia.filter { it.at !in loro } + voci)
}

/** Dalla più nuova alla più vecchia, come la scrive lo Store. */
private fun ordina(l: List<Transcription>) = l.sortedByDescending { it.at }
