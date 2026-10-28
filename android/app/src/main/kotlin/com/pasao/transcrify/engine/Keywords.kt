package com.pasao.transcrify.engine

import kotlin.math.ln
import kotlin.math.sqrt

/**
 * Le parole chiave, anche di più parole: «product designer», non «product» e «designer» da soli.
 *
 * I tratti di testo tra le parole vuote e la punteggiatura (l'idea di RAKE, Rose et al. 2010) danno
 * i candidati: in «sono un product designer, e il portfolio» ci sono «product designer» e «portfolio»
 * (e le loro parti). Si sceglie l'espressione più lunga che torna, non le sue parole da sole.
 *
 * Ogni candidato pesa quanto torna in questa nota e quanto è raro nelle altre (TF-IDF, contando in
 * quante note compare), un po' di più se è fatto di più parole: dice di più.
 * Le note si aggiornano una alla volta quando le salvi: nessun modello, microsecondi.
 */
class Keywords {
    private val df = HashMap<String, Int>()
    private val notePhrases = HashMap<String, Set<String>>()

    val notes get() = notePhrases.size

    /** La nota è stata salvata: i suoi candidati contano da adesso. */
    fun update(noteId: String, text: String) {
        forget(noteId)
        val set = phrases(text).mapTo(HashSet()) { it.key }
        for (p in set) df[p] = (df[p] ?: 0) + 1
        notePhrases[noteId] = set
    }

    fun forget(noteId: String) {
        for (p in notePhrases.remove(noteId).orEmpty()) {
            val n = (df[p] ?: 1) - 1
            if (n <= 0) df.remove(p) else df[p] = n
        }
    }

    /**
     * Le [k] espressioni che contano di più in [text], dalla più importante. Se un'espressione ha
     * parole in comune con una già scelta si salta: «product designer» basta, senza «designer».
     */
    fun top(text: String, k: Int): List<String> {
        val out = ArrayList<List<String>>()
        for ((key, _) in ranked(phrases(text))) {
            if (out.size == k) break
            val words = key.split(' ')
            if (out.none { chosen -> chosen.any { it in words } }) out.add(words)
        }
        return out.map { it.joinToString(" ") }
    }

    /** Dove compaiono le parole chiave di [text], come coppie inizio–fine: le si illumina lì. */
    fun ranges(text: String): IntArray {
        val all = phrases(text)
        val words = all.count { it.words == 1 }
        val keep = top(text, (words / 12).coerceIn(3, 12))
        // Dalla più importante: ogni sua comparsa, se non si sovrappone a una già presa.
        val taken = java.util.TreeMap<Int, Int>()
        for (key in keep) for (p in all) {
            if (p.key != key) continue
            val before = taken.floorEntry(p.range.last)
            if (before != null && before.value >= p.range.first) continue
            taken[p.range.first] = p.range.last
        }
        val out = IntArray(taken.size * 2)
        var i = 0
        for ((a, b) in taken) {
            out[i++] = a
            out[i++] = b + 1
        }
        return out
    }

    private fun ranked(all: List<Phrase>): List<Pair<String, Double>> {
        val tf = HashMap<String, Int>()
        val size = HashMap<String, Int>()
        for (p in all) {
            tf[p.key] = (tf[p.key] ?: 0) + 1
            size[p.key] = p.words
        }
        val n = notePhrases.size + 1
        return tf.map { (key, c) ->
            val idf = ln((n + 1.0) / ((df[key] ?: 0) + 1.0)) + 1.0
            key to c * idf * sqrt(size.getValue(key).toDouble())
        }.sortedByDescending { it.second }
    }

    /** Un candidato: com'è scritto (minuscolo), dove sta, di quante parole è fatto. */
    class Phrase(val key: String, val range: IntRange, val words: Int)

    companion object {
        /** Al massimo tre parole: più lunga è una frase, non una parola chiave. */
        private const val MAX_WORDS = 3
        private val SPACES = Regex("""\s+""")

        /**
         * I candidati di un testo: dentro ogni tratto, tutte le sequenze di una, due o tre parole di fila.
         * Così «product designer» si conta in «il product designer pensa» e in «del product designer»,
         * e vince perché torna, mentre «designer pensa» compare una volta sola.
         */
        fun phrases(text: String): List<Phrase> {
            val out = ArrayList<Phrase>()
            val run = ArrayList<IntRange>()
            fun flush() {
                for (a in run.indices) for (b in a until minOf(run.size, a + MAX_WORDS)) {
                    val r = run[a].first..run[b].last
                    out.add(Phrase(text.substring(r.first, r.last + 1).lowercase().replace(SPACES, " "), r, b - a + 1))
                }
                run.clear()
            }
            var i = 0
            while (i < text.length) {
                val c = text[i]
                if (c.isLetterOrDigit()) {
                    val start = i
                    // Il trattino tiene unita una parola («e-mail»); l'apostrofo no: «l'idea» è «l'» e «idea».
                    while (i < text.length && (text[i].isLetterOrDigit() || text[i] == '-' && i + 1 < text.length && text[i + 1].isLetter())) i++
                    val w = text.substring(start, i).lowercase()
                    // Le parole vuote, i numeri soli e le parole cortissime spezzano il tratto.
                    if (w.length < 3 || w in STOP || w.all { it.isDigit() }) flush() else run.add(start until i)
                } else {
                    // Solo gli spazi tengono insieme un tratto; punteggiatura e a-capo lo chiudono.
                    if (c != ' ' && c != '\t') flush()
                    i++
                }
            }
            flush()
            return out
        }

        /** Le parole che ci sono in ogni discorso, in italiano e in inglese: non dicono di cosa parli. */
        private val STOP = (
            "allora anche ancora avere avevo aveva cioè che chi come con così cosa cose dal dalla dalle dei del della delle dello " +
                "dentro dopo dove essere fare fatto fra già gli hai hanno ieri loro lui lei magari mai meglio mentre mia mie mio miei " +
                "molto nei nel nella nelle nello noi non nostro oggi oppure ora per però perché più poi possa posso potrebbe proprio " +
                "qua quale quali qualche quando quanto quasi quella quelle quelli quello questa queste questi questo qui sarà sarebbe " +
                "sei sembra sempre senza sia siamo sono sopra sotto sta stai stanno stato stesso sto sua sue suo suoi sul sulla sulle " +
                "tanto teoricamente tipo tra tutta tutte tutti tutto una uno vabbè voglio vorrei vuoi abbiamo appunto bene boh ecco " +
                "essenzialmente insomma comunque okay praticamente dire detto dici dico fai faccio fanno può puoi deve devo devi " +
                "the and for that this with you are was have has not but from they what when your can will would there their about " +
                "just like then than into also some https http www com"
            ).split(' ').toHashSet()
    }
}
