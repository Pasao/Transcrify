package com.pasao.transcrify.engine

import java.text.Normalizer

/** Una cosa trovata: in quale fonte (una nota «n:id» o una trascrizione «t:quando»), quale frase, quanto somiglia. */
data class Trovato(val fonte: String, val span: Span, val punteggio: Float, val esatto: Boolean = false)

/**
 * La ricerca per senso: ogni frase delle note e delle trascrizioni, col suo senso in 8 bit.
 *
 * La domanda si confronta con tutte le frasi (qualche migliaio: pochi millisecondi), e di ogni fonte
 * si tiene la frase che le somiglia di più. Così trova quello che volevi dire anche con altre parole.
 */
class Ricerca {
    private val frasi = HashMap<String, List<Pair<Span, Int8Vec>>>()

    val fonti: Set<String> get() = frasi.keys

    fun metti(fonte: String, sensi: List<Pair<Span, Int8Vec>>) {
        if (sensi.isEmpty()) frasi.remove(fonte) else frasi[fonte] = sensi
    }

    fun togli(fonte: String) {
        frasi.remove(fonte)
    }

    /**
     * Le fonti più vicine alla [domanda] (lunga 1), dalla migliore. Si tengono quelle sopra [minimo]
     * e non troppo sotto la migliore ([banda]): oltre, sono risultati che non c'entrano.
     */
    fun cerca(domanda: FloatArray, quante: Int, minimo: Float, banda: Float): List<Trovato> {
        val migliori = punteggi(domanda)
        val primo = migliori.firstOrNull()?.punteggio ?: return emptyList()
        return migliori.filter { it.punteggio >= minimo && it.punteggio >= primo - banda }.take(quante)
    }

    /** Ogni fonte con la sua frase più vicina alla [domanda], dalla migliore: senza soglie (chi le usa sceglie le sue). */
    fun punteggi(domanda: FloatArray): List<Trovato> = frasi.mapNotNull { (fonte, sensi) ->
        sensi.maxByOrNull { it.second.dot(domanda) }?.let { (span, v) -> Trovato(fonte, span, v.dot(domanda)) }
    }.sortedByDescending { it.punteggio }
}

/** La ricerca per parola: tutte le parole cercate, senza badare a maiuscole e accenti. */
object Parole {
    fun pulite(testo: String): String =
        Normalizer.normalize(testo.lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")

    fun di(domanda: String): List<String> = pulite(domanda).split(Regex("\\s+")).filter { it.isNotEmpty() }

    /**
     * Dove sta la prima parola cercata, se nel testo ci sono tutte; altrimenti null.
     * La normalizzazione NFD toglie solo i segni sopra le lettere, quindi le posizioni restano quelle del testo
     * per le lettere accentate scritte già composte (il caso normale): se non coincidono si cade sull'inizio.
     */
    fun trova(testo: String, parole: List<String>): Int? {
        if (parole.isEmpty()) return null
        val t = pulite(testo)
        if (parole.any { it !in t }) return null
        val i = t.indexOf(parole.first())
        return if (t.length == testo.length) i else 0
    }

    /** Un testo dove cercare: da quale fonte, e quando è cambiato l'ultima volta. */
    data class Fonte(val fonte: String, val testo: String, val quando: Long)

    /**
     * Le fonti con tutte le [parole], dalla più recente (note e trascrizioni insieme, per data):
     * di ognuna la frase dove compare la prima parola. Vengono sempre prima di quelle trovate per senso.
     */
    fun esatti(fonti: List<Fonte>, parole: List<String>): List<Trovato> = fonti.sortedByDescending { it.quando }.mapNotNull { f ->
        val i = trova(f.testo, parole) ?: return@mapNotNull null
        Trovato(f.fonte, Sentences.split(f.testo).firstOrNull { i < it.end } ?: Span(0, f.testo.length), 1f, esatto = true)
    }
}
