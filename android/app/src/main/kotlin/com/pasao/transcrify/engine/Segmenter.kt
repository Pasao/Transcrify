package com.pasao.transcrify.engine


/** Le tre grane dei Pensieri: dal largo al fine. Il pizzico passa dall'una all'altra. Le soglie stanno nel profilo del modello. */
enum class Grain { COARSE, MEDIUM, FINE }

/**
 * Dove cambia argomento, dentro un testo: per ogni spazio tra due frasi, un byte che dice quanto
 * è profondo il confine (0 = stesso discorso, 255 = tutt'altro).
 *
 * Le grane non si salvano: si ricavano da qui. I confini si accettano dal più profondo al meno
 * profondo, saltando quelli che lascerebbero un pezzo più corto di [minLen] frasi: l'ordine di
 * accettazione è uno solo, quindi la grana fine contiene sempre i confini di quella larga.
 * È un albero (largo → fine) salvato in n−1 byte.
 */
class Segmentation(val depth: ByteArray, val minLen: Int = 2) {
    /** Quante frasi. */
    val sentences = depth.size + 1

    /** I confini nell'ordine in cui si accettano: dal più profondo. Il confine i sta tra la frase i e la i+1. */
    val order: IntArray by lazy {
        val byDepth = depth.indices.sortedWith(compareByDescending<Int> { depth[it].toInt() and 0xFF }.thenBy { it })
        // I confini già presi, ordinati: il vicino a sinistra e a destra si trova in O(log n).
        val taken = java.util.TreeSet<Int>()
        val out = IntArray(depth.size)
        var k = 0
        for (g in byDepth) {
            val left = taken.lower(g) ?: -1
            val right = taken.higher(g) ?: depth.size
            // Frasi tra il confine a sinistra e g, e tra g e quello a destra (o i bordi del testo).
            if (g - left >= minLen && right - g >= minLen) {
                taken.add(g)
                out[k++] = g
            }
        }
        out.copyOf(k)
    }

    /**
     * Le grane che vedi pizzicando: 1 larga, 2 media, 3 una frase per pezzo.
     * La media segue la soglia del modello: i cambi di argomento veri. La larga deve essere più
     * larga della media: se la sua soglia darebbe lo stesso taglio (succede nelle note corte),
     * si lascia via il confine meno netto, così due argomenti vicini si vedono insieme.
     * Così ogni pizzico cambia qualcosa, senza inventare confini che non ci sono.
     */
    fun levelCuts(level: Int, profile: EngineProfile): IntArray {
        val gaps = sentences - 1
        if (gaps <= 0) return IntArray(0)
        if (level >= 3) return IntArray(gaps) { it }
        var medium = cutsAtLeast(profile.medium)
        // Una nota lunga senza nessun confine sopra soglia ha almeno il suo confine più netto.
        if (medium.isEmpty() && gaps >= 5) medium = cuts(2)
        if (level == 2) return medium
        val wide = cutsAtLeast(profile.coarse)
        return if (wide.size < medium.size) wide else cuts(medium.size)
    }

    fun strength(gap: Int): Int = depth[gap].toInt() and 0xFF

    /** I primi [k]−1 confini: il testo in [k] pezzi (o meno, se è corto). */
    fun cuts(k: Int): IntArray = order.copyOf((k - 1).coerceIn(0, order.size)).sortedArray()

    /** I confini abbastanza profondi per una grana, con le soglie del modello. */
    fun cuts(grain: Grain, profile: EngineProfile): IntArray = cutsAtLeast(profile.threshold(grain))

    /** I confini profondi almeno [depth] (0–255), presi nell'ordine di sempre. */
    fun cutsAtLeast(depth: Int): IntArray = order.takeWhile { strength(it) >= depth }.toIntArray().sortedArray()

    /** I pezzi come intervalli di frasi [da, a), dati i confini. */
    fun pieces(cuts: IntArray): List<IntRange> {
        val out = ArrayList<IntRange>(cuts.size + 1)
        var from = 0
        for (c in cuts) {
            out.add(from until c + 1)
            from = c + 1
        }
        out.add(from until sentences)
        return out
    }
}

/**
 * Trova i confini tra argomenti con l'idea di TextTiling (Hearst 1997), sui vettori del senso:
 *
 * 1. Per ogni spazio tra due frasi si confrontano il blocco prima (le k frasi a sinistra)
 *    e il blocco dopo: coesione = coseno tra le loro medie. Le medie vengono dalle somme prefisse,
 *    quindi ogni spazio costa una sottrazione, non una somma di k vettori. k cresce col testo (1–3).
 * 2. Nei testi lunghi la coesione si liscia appena (media su tre), per non vedere confini nel rumore.
 * 3. La profondità di un avvallamento = quanto si scende dalla cima a sinistra + quanto dalla cima
 *    a destra. Le cime si trovano in un passaggio per lato: tutto O(n · dim).
 * 4. La profondità si salva in un byte dopo averla allargata di [scale] (dal profilo del modello):
 *    un modello che vede tutto simile ha avvallamenti bassi, e senza allargarli userebbe pochi gradini.
 *
 * È così economico che si rifà intero a ogni salvataggio: la parte cara (il senso delle frasi) è
 * già ricordata frase per frase dall'impronta.
 */
object Segmenter {
    fun segment(vectors: List<FloatArray>, scale: Float = 1f, window: Int? = null, minLen: Int = 2, smooth: Boolean? = null): Segmentation {
        val n = vectors.size
        // Una finestra larga in un testo corto scavalca due confini insieme e li confonde:
        // si allarga con il testo, da 1 a 3 frasi. Lisciare serve solo nei testi lunghi (le lezioni).
        val k = window ?: (n / 6).coerceIn(1, 3)
        val soft = smooth ?: (n >= 30)
        if (n < 2) return Segmentation(ByteArray(0), minLen)
        val dim = vectors[0].size
        // Somme prefisse: prefix[i] = v0 + … + v(i−1).
        val prefix = Array(n + 1) { FloatArray(dim) }
        for (i in 0 until n) {
            val p = prefix[i + 1]
            val q = prefix[i]
            val v = vectors[i]
            for (d in 0 until dim) p[d] = q[d] + v[d]
        }
        val gaps = n - 1
        val cohesion = FloatArray(gaps)
        val left = FloatArray(dim)
        val right = FloatArray(dim)
        for (g in 0 until gaps) {
            // Blocco sinistro: frasi (g−k, g]; destro: (g, g+k].
            val a = maxOf(0, g + 1 - k)
            val b = minOf(n, g + 1 + k)
            for (d in 0 until dim) {
                left[d] = prefix[g + 1][d] - prefix[a][d]
                right[d] = prefix[b][d] - prefix[g + 1][d]
            }
            cohesion[g] = Vec.cosine(left, right)
        }
        val smoothed = if (!soft) cohesion else FloatArray(gaps) { g ->
            val a = maxOf(0, g - 1)
            val b = minOf(gaps - 1, g + 1)
            var s = 0f
            for (k in a..b) s += cohesion[k]
            s / (b - a + 1)
        }
        // La cima raggiungibile salendo verso sinistra (e verso destra) da ogni spazio.
        val peakLeft = FloatArray(gaps)
        for (g in 0 until gaps) peakLeft[g] = if (g > 0 && smoothed[g - 1] >= smoothed[g]) peakLeft[g - 1] else smoothed[g]
        val peakRight = FloatArray(gaps)
        for (g in gaps - 1 downTo 0) peakRight[g] = if (g < gaps - 1 && smoothed[g + 1] >= smoothed[g]) peakRight[g + 1] else smoothed[g]
        val depth = ByteArray(gaps) { g ->
            val dep = ((peakLeft[g] - smoothed[g]) + (peakRight[g] - smoothed[g])) * scale
            // Una profondità di 1 / scale è già un cambio netto per questo modello: oltre si satura.
            (dep.coerceIn(0f, 1f) * 255f + 0.5f).toInt().toByte()
        }
        return Segmentation(depth, minLen)
    }
}
