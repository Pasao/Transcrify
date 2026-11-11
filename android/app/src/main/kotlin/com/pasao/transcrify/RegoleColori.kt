package com.pasao.transcrify

import org.json.JSONObject

/**
 * La regola di un colore, scritta da te (7 nov, sua paura: «non so cosa fa, se posso tornare indietro, come accorgermi
 * degli errori»): al posto delle vicine misteriose, [regola] dice in poche parole cosa va in quel colore («lavoro,
 * preventivi, clienti»); [offuscaSempre]: quello che prende questo colore, da solo o messo da te, diventa privato.
 */
data class RegolaColore(val regola: String = "", val offuscaSempre: Boolean = false) {
    /** Niente da ricordare: si toglie. */
    val vuota get() = regola.isBlank() && !offuscaSempre

    fun toMap(): Map<String, Any> = mapOf("regola" to regola, "offuscaSempre" to offuscaSempre)
}

/**
 * Quello che cambi su una o più trascrizioni con un gesto («segnaHistory»): c'è solo quello che cambia. [colore] e
 * [titolo] true: cambiano in [nuovoColore] e [nuovoTitolo] (null li toglie); [privata] null: resta com'è.
 */
data class Segno(
    val colore: Boolean = false, val nuovoColore: String? = null, val privata: Boolean? = null,
    val titolo: Boolean = false, val nuovoTitolo: String? = null,
)

object RegoleColori {
    fun daJson(s: String?): Map<String, RegolaColore> = s?.let { JSONObject(it) }?.let { j ->
        j.keys().asSequence().associateWith { k ->
            j.getJSONObject(k).let { RegolaColore(it.optString("regola"), it.optBoolean("offuscaSempre")) }
        }
    } ?: emptyMap()

    fun inJson(regole: Map<String, RegolaColore>): String =
        JSONObject(regole.mapValues { (_, r) -> JSONObject(r.toMap()) }).toString()

    /** [regole] con quella di [colore] cambiata: vuota se ne va. */
    fun salva(regole: Map<String, RegolaColore>, colore: String, regola: RegolaColore): Map<String, RegolaColore> =
        regole.toMutableMap().apply { if (regola.vuota) remove(colore) else put(colore, regola.copy(regola = regola.regola.trim())) }

    /**
     * Le regole che valgono davvero (10 nov, sua richiesta: «il nome è la regola»): quella scritta da te, o, se non
     * l'hai scritta, il NOME del colore ([nomi], «tinta:luce» → nome). La cambi poi nelle Impostazioni ([salva]).
     */
    fun effettive(regole: Map<String, RegolaColore>, nomi: Map<String, String>): Map<String, RegolaColore> =
        (regole.keys + nomi.keys).associateWith { c ->
            val r = regole[c] ?: RegolaColore()
            r.copy(regola = r.regola.ifBlank { nomi[c]?.trim().orEmpty() })
        }.filterValues { !it.vuota }

    /**
     * «Offusca sempre» di [colore] acceso ([privata] true) o spento (false), 10 nov: vale per tutte quelle che hanno quel
     * colore, di prima e nuove («offusca» e «togli offusca» retroattivi). Quali cambiano: quelle che non lo sono già.
     * Quella che poi offuschi o rimetti in vista a mano resta come la lasci, fino al prossimo cambio dell'etichetta.
     */
    fun daCambiare(storia: List<Transcription>, colore: String, privata: Boolean): Set<Long> =
        storia.filter { it.colore == colore && it.privata != privata }.map { it.at }.toSet()

    /**
     * Le trascrizioni di prima da colorare con [colore] («colora le sue di prima», 10 nov): quelle senza colore e non
     * private ([Transcription.colorataDaSola]) per cui la regola rigida ([com.pasao.transcrify.engine.ColoreRegole],
     * qui [decidi]) sceglie proprio [colore]. Prudente come per le nuove: nel dubbio niente.
     */
    fun daColorare(storia: List<Transcription>, colore: String, decidi: (Transcription) -> String?): List<Long> =
        storia.filter { it.colorataDaSola(colore) != null && it.text.isNotBlank() && decidi(it) == colore }.map { it.at }

    /**
     * L'«Annulla» di [daColorare]: torna esattamente com'era (senza colore; non privata, se a renderla privata era il
     * colore, [offusca]), ma solo se il colore è ancora quello messo da sola: se l'hai cambiato tu, resta com'è adesso.
     */
    fun annullaColorata(t: Transcription, offusca: Boolean): Transcription =
        if (t.coloreAuto && t.colore != null) t.copy(colore = null, coloreAuto = false, privata = t.privata && !offusca) else t

    /**
     * Il segno messo da te su [t]. Toccati da te: il titolo è tuo ([Transcription.titoloUtente], non si richiede più),
     * il colore non è più «messo da sola». Un colore con «offusca sempre» la rende privata (se non dici tu altro); togliere
     * il colore messo da sola (l'«Annulla») toglie anche la privata che quel colore aveva messo.
     */
    fun segna(t: Transcription, s: Segno, regole: Map<String, RegolaColore>): Transcription {
        val colore = if (s.colore) s.nuovoColore else t.colore
        val privata = s.privata ?: when {
            s.colore && colore != null && regole[colore]?.offuscaSempre == true -> true
            s.colore && colore == null && t.coloreAuto && t.colore?.let { regole[it]?.offuscaSempre } == true -> false
            else -> t.privata
        }
        val titolo = if (s.titolo) s.nuovoTitolo?.trim()?.ifEmpty { null } else t.titolo
        return t.copy(
            colore = colore, privata = privata, titolo = titolo,
            titoloChiesto = t.titoloChiesto || s.titolo, titoloUtente = t.titoloUtente || s.titolo,
            coloreAuto = t.coloreAuto && !s.colore,
        )
    }
}
