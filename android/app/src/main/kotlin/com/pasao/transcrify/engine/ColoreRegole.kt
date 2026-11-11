package com.pasao.transcrify.engine

/**
 * «Colora da sola» con le regole scritte da te (7 nov sera: «non so cosa fa, se posso tornare indietro, come accorgermi
 * degli errori»): il colore di una trascrizione nuova si decide da cose che vedi, la regola di ogni colore («lavoro,
 * preventivi, clienti») e le trascrizioni che hai già colorato. Prudente: meglio nessun colore che uno sbagliato.
 *
 * Un colore può vincere se la trascrizione somiglia alla sua regola almeno [soglia] (quella che tiene insieme un album,
 * `EngineProfile.pair`), oppure se lo hanno almeno due delle [VICINE] colorate più vicine (sopra la soglia). Tra
 * quelli che possono, vince il più forte (regola o esempio, il più vicino dei due), e solo se stacca il secondo colore
 * di almeno [margine]. Altrimenti niente.
 */
object ColoreRegole {
    const val VICINE = 3

    /**
     * [regole]: colore → quanto la trascrizione somiglia alla sua regola. [vicine]: (colore, quanto somiglia) delle
     * trascrizioni colorate, in qualunque ordine. [sogliaRegola] (11 nov): una regola è una frase corta contro un testo
     * lungo, come una categoria degli argomenti, e col modello vero non arriva mai a [soglia] (quella di due pezzi dello
     * stesso album, 0,80 o 0,94): per lei vale la soglia della ricerca (`EngineProfile.cercaMinimo`). Regole ed esempi
     * si confrontano per quanto superano ognuno la sua soglia.
     */
    fun decidi(regole: Map<String, Float>, vicine: List<Pair<String, Float>>, soglia: Float, margine: Float, sogliaRegola: Float = soglia): String? {
        val buone = vicine.sortedByDescending { it.second }.take(VICINE).filter { it.second >= soglia }
        val voti = buone.groupingBy { it.first }.eachCount()
        val esempio = vicine.groupBy({ it.first }, { it.second }).mapValues { (_, v) -> v.max() }
        val colori = regole.keys + esempio.keys
        fun forza(c: String) = maxOf(regole[c]?.minus(sogliaRegola) ?: -2f, esempio[c]?.minus(soglia) ?: -2f)
        val primo = colori.filter { (regole[it] ?: -1f) >= sogliaRegola || (voti[it] ?: 0) >= 2 }.maxByOrNull(::forza) ?: return null
        val secondo = colori.filter { it != primo }.maxOfOrNull(::forza) ?: return primo
        return primo.takeIf { forza(it) - secondo >= margine }
    }
}
