package com.pasao.transcrify.engine

import kotlin.math.ln

/**
 * Le parole chiave: le parole che una nota usa e le altre note no (TF-IDF).
 * «Portfolio» detto tre volte in una nota e quasi mai altrove pesa; «cosa», «fare», «poi» no.
 *
 * Per ogni parola si tiene in quante note compare (df), aggiornato nota per nota quando la salvi:
 * togliere e rimettere una nota costa quante parole diverse ha. Nessun modello: microsecondi.
 */
class Keywords {
    private val df = HashMap<String, Int>()
    private val noteWords = HashMap<String, Set<String>>()

    val notes get() = noteWords.size

    /** La nota è stata salvata: le sue parole contano da adesso. */
    fun update(noteId: String, text: String) {
        forget(noteId)
        val set = words(text).mapTo(HashSet()) { it.first }
        for (w in set) df[w] = (df[w] ?: 0) + 1
        noteWords[noteId] = set
    }

    fun forget(noteId: String) {
        for (w in noteWords.remove(noteId).orEmpty()) {
            val n = (df[w] ?: 1) - 1
            if (n <= 0) df.remove(w) else df[w] = n
        }
    }

    /** Le [k] parole che contano di più in [text], dalla più importante. */
    fun top(text: String, k: Int): List<String> {
        val tf = HashMap<String, Int>()
        for ((w, _) in words(text)) tf[w] = (tf[w] ?: 0) + 1
        val n = noteWords.size + 1
        return tf.entries
            .sortedByDescending { (w, c) -> c * (ln((n + 1.0) / ((df[w] ?: 0) + 1.0)) + 1.0) }
            .take(k)
            .map { it.key }
    }

    /** Dove compaiono le parole chiave di [text], come coppie inizio–fine: le si illumina lì. */
    fun ranges(text: String): IntArray {
        val all = words(text)
        val k = (all.size / 12).coerceIn(3, 12)
        val keep = top(text, k).toHashSet()
        val out = ArrayList<Int>()
        for ((w, r) in all) if (w in keep) {
            out.add(r.first)
            out.add(r.last + 1)
        }
        return out.toIntArray()
    }

    companion object {
        /** Le parole di un testo (minuscole, senza le parole vuote) con dove stanno. */
        fun words(text: String): List<Pair<String, IntRange>> {
            val out = ArrayList<Pair<String, IntRange>>()
            var i = 0
            while (i < text.length) {
                if (!text[i].isLetter()) {
                    i++
                    continue
                }
                val start = i
                while (i < text.length && (text[i].isLetterOrDigit() || (text[i] == '-' && i + 1 < text.length && text[i + 1].isLetter()))) i++
                val w = text.substring(start, i).lowercase()
                if (w.length >= 3 && w !in STOP) out.add(w to (start until i))
            }
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
                "essenzialmente insomma comunque ok okay praticamente dire detto dici dico fai faccio fanno può puoi deve devo devi " +
                "the and for that this with you are was have has not but from they what when your can will would there their about " +
                "just like then than into also some"
            ).split(' ').toHashSet()
    }
}
