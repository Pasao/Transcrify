package com.pasao.transcrify.engine

import com.pasao.transcrify.TopicModel
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.util.Locale
import java.util.Random

/**
 * La taratura delle soglie per ogni modello, sulle note finte di `calibrazione-note.txt`
 * (dettate, 2–4 argomenti l'una, gli stessi argomenti in note diverse). Col modello vero: vedi [TestModels].
 *
 * Stampa le distribuzioni e le soglie migliori trovate, e controlla che il profilo scritto in
 * [TopicModel] vada quasi come il migliore: se cambia il modello o il prefisso, questo test lo dice.
 *
 * - Confini: la profondità ai confini veri e altrove. depthScale = 1 / la profondità che solo un
 *   confine vero su dieci supera. Poi per ogni soglia precisione e richiamo (un confine conta solo
 *   se è proprio quello): media = il centro del tratto in cui l'F1 resta entro il 97% del massimo
 *   (la curva è piatta: il picco da solo è fortuna), larga = miglior F0,5 (pesa di più la precisione:
 *   taglia solo dove è sicura), fine = miglior F2 (pesa di più il richiamo: taglia anche nel dubbio).
 *   Una profondità 0 vuol dire nessun avvallamento: lì non si taglia mai, la soglia parte da 1.
 * - Album: i pezzi sono gli argomenti veri delle note; per ogni pair si aggiungono in 20 ordini
 *   diversi, si fa la manutenzione e si misura l'accordo con la verità (Adjusted Rand Index).
 *   Si prende il centro del tratto in cui l'ARI resta vicino al massimo, non il picco: con 34 pezzi
 *   il picco è fortuna. split = pair − (mediana − 10° percentile) delle somiglianze tra pezzi dello
 *   stesso argomento: un album si spezza solo quando scende sotto il rumore normale di un argomento.
 */
class CalibrationTest {
    @Test
    fun precise() = calibrate(TopicModel.PRECISE)

    @Test
    fun light() = calibrate(TopicModel.LIGHT)

    private class Block(val topic: String, val text: String)

    private fun notes(): List<List<Block>> {
        val out = ArrayList<List<Block>>()
        var note = ArrayList<Block>()
        for (line in javaClass.getResourceAsStream("/calibrazione-note.txt")!!.bufferedReader().readLines()) {
            if (line.startsWith("#")) continue
            if (line.isBlank()) {
                if (note.isNotEmpty()) out.add(note)
                note = ArrayList()
                continue
            }
            val m = Regex("""\[(\w+)] (.*)""").matchEntire(line.trim())!!
            note.add(Block(m.groupValues[1], m.groupValues[2]))
        }
        if (note.isNotEmpty()) out.add(note)
        return out
    }

    /** Una nota col suo testo, i vettori delle frasi e l'argomento di ogni frase. */
    private class Note(val text: String, val vectors: List<FloatArray>, val topics: List<String>) {
        /** I confini veri: lo spazio i sta tra la frase i e la i+1. */
        val truth: Set<Int> = (0 until topics.size - 1).filter { topics[it] != topics[it + 1] }.toSet()
    }

    private fun calibrate(model: TopicModel) {
        val dir = File(TestModels.dir, model.id)
        assumeTrue("manca il modello in $dir", File(dir, model.onnxFile).exists())
        TestModels.assumeOnnxRuntimeLoads()
        OnnxEmbedder(dir, model).use { emb ->
            val notes = notes().map { note ->
                val text = note.joinToString(" ") { it.text }
                val spans = Sentences.split(text)
                // L'argomento di una frase: il blocco in cui comincia.
                val starts = note.runningFold(0) { at, b -> at + b.text.length + 1 }
                val topics = spans.map { s -> note[starts.indexOfLast { it <= s.start }.coerceAtMost(note.size - 1)].topic }
                Note(text, emb.embed(spans.map { it.of(text) }), topics)
            }
            val report = StringBuilder("\n===== ${model.id} (${model.modelName}) =====\n")
            report.append("${notes.size} note, ${notes.sumOf { it.vectors.size }} frasi, ${notes.sumOf { it.truth.size }} confini veri\n")
            val bestF1 = boundaries(notes, report)
            val bestAri = albums(notes, model.embedding.dim, report)
            val p = model.profile
            val mine = scoreBoundaries(notes, p.depthScale, p.medium)
            val mineAri = ari(notes, model.embedding.dim, p.pair, p.split)
            report.append("profilo in TopicModel: $p\n  → confini media: precisione ${f(mine.precision)}, richiamo ${f(mine.recall)}, F1 ${f(mine.f1())}; album ARI ${f(mineAri)}\n")
            report.append("con Engine (pezzi trovati dal motore, non quelli veri): ").append(endToEnd(notes, model, emb))
            println(report)
            assertTrue("F1 ${mine.f1()} contro il migliore $bestF1", mine.f1() >= 0.9f * bestF1)
            assertTrue("ARI $mineAri contro il migliore $bestAri", mineAri >= 0.9f * bestAri)
        }
    }

    // --- confini ---

    private class Score(val precision: Float, val recall: Float) {
        fun f1() = fBeta(1f)
        fun fBeta(beta: Float): Float {
            val b2 = beta * beta
            val d = b2 * precision + recall
            return if (d == 0f) 0f else (1 + b2) * precision * recall / d
        }
    }

    private fun scoreBoundaries(notes: List<Note>, scale: Float, threshold: Int, window: Int? = null): Score {
        var hit = 0
        var cut = 0
        var real = 0
        for (n in notes) {
            val cuts = Segmenter.segment(n.vectors, scale, window = window).cutsAtLeast(threshold).toSet()
            hit += cuts.count { it in n.truth }
            cut += cuts.size
            real += n.truth.size
        }
        return Score(if (cut == 0) 1f else hit.toFloat() / cut, hit.toFloat() / real)
    }

    /** Stampa le soglie migliori e restituisce il miglior F1. */
    private fun boundaries(notes: List<Note>, out: StringBuilder): Float {
        val atTruth = ArrayList<Float>()
        val elsewhere = ArrayList<Float>()
        for (n in notes) {
            val seg = Segmenter.segment(n.vectors, scale = 1f)
            for (g in 0 until seg.sentences - 1) (if (g in n.truth) atTruth else elsewhere).add(seg.strength(g) / 255f)
        }
        out.append("profondità (senza allargare) ai confini veri: ${quantiles(atTruth)}\n")
        out.append("profondità (senza allargare) altrove:         ${quantiles(elsewhere)}\n")
        val sharp = atTruth.sorted()[((atTruth.size - 1) * 0.9).toInt()]
        val scale = Math.round(2f / sharp) / 2f
        out.append("depthScale = 1 / ${f(sharp)} ≈ $scale\n")
        val scores = (0..255).map { scoreBoundaries(notes, scale, it) }
        out.append("F1 per soglia: " + (1..255 step 6).joinToString(" ") { "$it→${f(scores[it].f1())}" } + "\n")
        // Come per gli album: il centro del tratto (intorno al massimo) che resta entro il 97% del massimo.
        val peak = (1..255).maxBy { scores[it].f1() }
        val top = scores[peak].f1()
        var lo = peak
        var hi = peak
        while (lo > 1 && scores[lo - 1].f1() >= 0.97f * top) lo--
        while (hi < 255 && scores[hi + 1].f1() >= 0.97f * top) hi++
        val medium = (lo + hi) / 2
        out.append("F1 massimo ${f(top)} a $peak; entro il 97% da $lo a $hi\n")
        val coarse = (medium..255).maxBy { scores[it].fBeta(0.5f) }
        val fine = (1..medium).maxBy { scores[it].fBeta(2f) }
        for ((name, t) in listOf("fine" to fine, "media" to medium, "larga" to coarse)) {
            out.append("  $name, soglia $t: precisione ${f(scores[t].precision)}, richiamo ${f(scores[t].recall)}, F1 ${f(scores[t].f1())}\n")
        }
        out.append("  per confronto, tagliare ovunque si può (soglia 0): F1 ${f(scores[0].f1())}\n")
        for (k in 1..3) {
            val best = (1..255).maxOf { scoreBoundaries(notes, scale, it, window = k).f1() }
            out.append("  con finestra fissa di $k frasi il miglior F1 sarebbe ${f(best)}\n")
        }
        out.append("grane migliori: coarse $coarse, medium $medium, fine $fine (depthScale $scale)\n")
        return top
    }

    // --- album ---

    private class Piece(val id: Long, val vector: FloatArray, val topic: String)

    private fun pieces(notes: List<Note>): List<Piece> {
        val out = ArrayList<Piece>()
        for (n in notes) {
            var from = 0
            for (i in 1..n.topics.size) {
                if (i < n.topics.size && n.topics[i] == n.topics[from]) continue
                val sum = FloatArray(n.vectors[0].size)
                for (k in from until i) Vec.addTo(sum, n.vectors[k])
                out.add(Piece(out.size.toLong(), sum, n.topics[from]))
                from = i
            }
        }
        return out
    }

    private fun ari(notes: List<Note>, dim: Int, pair: Float, split: Float): Float {
        val ps = pieces(notes)
        var total = 0f
        repeat(ORDERS) { seed ->
            val topics = Topics(dim, pair, split)
            for (p in ps.shuffled(Random(seed.toLong()))) topics.add(p.id, p.vector)
            topics.maintain()
            total += adjustedRand(ps.map { it.topic }, ps.map { topics.albumOf(it.id)!! })
        }
        return total / ORDERS
    }

    /** Stampa pair e split migliori e restituisce il miglior ARI. */
    private fun albums(notes: List<Note>, dim: Int, out: StringBuilder): Float {
        val ps = pieces(notes)
        val same = ArrayList<Float>()
        val other = ArrayList<Float>()
        for (i in ps.indices) for (j in i + 1 until ps.size) {
            val s = Vec.dot(Vec.normalized(ps[i].vector), Vec.normalized(ps[j].vector))
            (if (ps[i].topic == ps[j].topic) same else other).add(s)
        }
        out.append("${ps.size} pezzi veri in ${ps.map { it.topic }.distinct().size} argomenti\n")
        out.append("somiglianza tra pezzi, stesso argomento: ${quantiles(same)}\n")
        out.append("somiglianza tra pezzi, argomenti diversi: ${quantiles(other)}\n")
        val sorted = same.sorted()
        val noise = sorted[(sorted.size - 1) / 2] - sorted[((sorted.size - 1) * 0.1).toInt()]
        // Prima pair da solo (split = pair: non spezza mai un album appena fatto), al centesimo.
        val curve = (20..98).associateWith { ari(notes, dim, it / 100f, it / 100f) }
        val best = curve.values.max()
        val near = curve.filterValues { it >= 0.9f * best }.keys
        val pair = (near.min() + near.max()) / 2 / 100f
        out.append("ARI per pair: " + curve.filterValues { it > 0.01f }.entries.joinToString(" ") { "${it.key / 100f}→${f(it.value)}" } + "\n")
        out.append("massimo ${f(best)}; entro il 90% del massimo da ${near.min() / 100f} a ${near.max() / 100f}: pair ${f(pair)}\n")
        val split = pair - noise
        out.append("rumore di un argomento (mediana − 10%) ${f(noise)} → split ${f(split)}; ARI con questo split ${f(ari(notes, dim, pair, split))}, senza spezzare ${f(ari(notes, dim, pair, pair))}\n")
        return best
    }

    /** Adjusted Rand Index (Hubert e Arabie 1985): 1 = come la verità, 0 = come a caso. */
    private fun <A, B> adjustedRand(a: List<A>, b: List<B>): Float {
        fun c2(n: Int) = n.toDouble() * (n - 1) / 2
        val joint = a.indices.groupingBy { a[it] to b[it] }.eachCount().values.sumOf { c2(it) }
        val sa = a.groupingBy { it }.eachCount().values.sumOf { c2(it) }
        val sb = b.groupingBy { it }.eachCount().values.sumOf { c2(it) }
        val expected = sa * sb / c2(a.size)
        val max = (sa + sb) / 2
        return if (max == expected) 1f else ((joint - expected) / (max - expected)).toFloat()
    }

    // --- tutto insieme ---

    /** Ricorda i vettori già calcolati: per provare tanti profili senza ripassare dal modello. */
    private class Remember(private val inner: Embedder) : Embedder {
        private val seen = HashMap<String, FloatArray>()
        override val dim get() = inner.dim
        override fun embed(sentences: List<String>): List<FloatArray> {
            val missing = sentences.filter { it !in seen }.distinct()
            if (missing.isNotEmpty()) inner.embed(missing).forEachIndexed { i, v -> seen[missing[i]] = v }
            return sentences.map { seen.getValue(it) }
        }
    }

    /** Il motore vero con il profilo del modello: quanti pezzi trova e come li mette negli album. */
    private fun endToEnd(notes: List<Note>, model: TopicModel, emb: Embedder): String {
        val remember = Remember(emb)
        val p = model.profile
        // Le note arrivano in ordini diversi: la media su 10 ordini, perché un ordine solo è rumore.
        fun mean(profile: EngineProfile) = (0 until 10).map { engineRun(notes, remember, profile, it).second }.average().toFloat()
        val sweep = (70..98).joinToString(" ") { pi ->
            val pair = pi / 100f
            "$pair→${f(mean(p.copy(pair = pair, split = minOf(p.split, pair))))}"
        }
        val (line, _) = engineRun(notes, remember, p, 0)
        return line + "  ARI medio su 10 ordini con questo profilo ${f(mean(p))}; al variare di pair (stesse grane): $sweep\n"
    }

    private fun engineRun(notes: List<Note>, emb: Embedder, profile: EngineProfile, seed: Int): Pair<String, Float> {
        val engine = Engine(emb, profile)
        val labels = ArrayList<String>()
        val ids = ArrayList<Long>()
        var real = 0
        for ((i, n) in notes.withIndex().shuffled(Random(seed.toLong()))) {
            real += n.truth.size + 1
            for ((id, range) in engine.commit("nota$i", n.text).pieces) {
                // L'argomento di un pezzo: quello della maggior parte delle sue frasi.
                labels.add(range.map { n.topics[it] }.groupingBy { it }.eachCount().maxBy { it.value }.key)
                ids.add(id)
            }
        }
        engine.topics.maintain()
        val albums = ids.map { engine.topics.albumOf(it)!! }
        val pure = albums.indices.groupBy { albums[it] }.values.sumOf { m -> m.groupingBy { labels[it] }.eachCount().values.max() }
        val ari = adjustedRand(labels, albums)
        return "${ids.size} pezzi (veri $real), ${albums.distinct().size} album di cui ${engine.topics.shown().size} mostrati, " +
            "purezza ${f(pure.toFloat() / ids.size)}, ARI ${f(ari)}\n" to ari
    }

    private fun quantiles(xs: List<Float>): String {
        val s = xs.sorted()
        fun q(p: Double) = f(s[((s.size - 1) * p).toInt()])
        return "min ${q(0.0)} · 10% ${q(0.1)} · mediana ${q(0.5)} · 90% ${q(0.9)} · max ${q(1.0)} (n=${s.size})"
    }

    private fun f(x: Float) = "%.3f".format(Locale.ROOT, x)

    private companion object {
        const val ORDERS = 20
    }
}
