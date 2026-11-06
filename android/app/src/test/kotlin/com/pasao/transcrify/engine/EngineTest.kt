package com.pasao.transcrify.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.SplittableRandom

class EngineTest {
    // --- impronte ---

    @Test
    fun xxHash64MatchesTheReference() {
        assertEquals(0xEF46DB3751D8E999uL.toLong(), XxHash64.hash(ByteArray(0)))
        assertEquals(0x44BC2CF5AD770999uL.toLong(), XxHash64.hash("abc".toByteArray()))
    }

    @Test
    fun sameSentenceSameFingerprint() {
        assertEquals(Fingerprint.of("Il Dock  più basso."), Fingerprint.of(" Il Dock più basso. "))
        assertTrue(Fingerprint.of("Il Dock più basso.") != Fingerprint.of("Il Dock più alto."))
        val f = Fingerprint.of("ciao")
        assertEquals(f, Fingerprint.fromBytes(f.toBytes()))
    }

    // --- frasi ---

    @Test
    fun splitsItalianSentences() {
        val t = "Domani finisco la pagina About. Poi sistemo i video, ecc. ecc. come dice il dott. Rossi! E il dentifricio?\n• Comprare il pane\n• Chiamare A. Bianchi"
        val s = Sentences.split(t).map { it.of(t) }
        assertEquals(
            listOf(
                "Domani finisco la pagina About.",
                "Poi sistemo i video, ecc. ecc. come dice il dott. Rossi!",
                "E il dentifricio?",
                "Comprare il pane",
                "Chiamare A. Bianchi",
            ),
            s,
        )
    }

    @Test
    fun longDictationIsBrokenAtACommaOrConjunction() {
        val t = (1..30).joinToString(" ") { "parola$it" } + ", " + (1..30).joinToString(" ") { "altra$it" } + " e poi " + (1..20).joinToString(" ") { "fine$it" }
        val s = Sentences.split(t)
        assertTrue(s.size >= 2)
        assertTrue(s.all { it.end - it.start <= Sentences.MAX_CHARS })
        assertEquals(t.replace(" ", ""), s.joinToString("") { it.of(t) }.replace(" ", ""))
    }

    // --- vettori ---

    @Test
    fun int8KeepsTheCosine() {
        val r = SplittableRandom(1)
        val a = Vec.normalized(FloatArray(256) { r.nextDouble(-1.0, 1.0).toFloat() })
        val b = Vec.normalized(FloatArray(256) { a[it] + r.nextDouble(-0.5, 0.5).toFloat() })
        val exact = Vec.dot(a, b)
        assertEquals(exact, Int8Vec.of(a).dot(Int8Vec.of(b)), 0.01f)
    }

    @Test
    fun simHashEstimatesTheAngle() {
        val sim = SimHash(256)
        val r = SplittableRandom(2)
        var err = 0f
        repeat(50) {
            val a = Vec.normalized(FloatArray(256) { r.nextDouble(-1.0, 1.0).toFloat() })
            val b = Vec.normalized(FloatArray(256) { a[it] + r.nextDouble(-0.8, 0.8).toFloat() })
            err += kotlin.math.abs(sim.cosineOf(sim.hamming(sim.code(a), sim.code(b))) - Vec.dot(a, b))
        }
        assertTrue("errore medio ${err / 50}", err / 50 < 0.08f)
    }

    // --- confini ---

    /**
     * Frasi finte: ogni argomento è una direzione a caso, ogni frase quella direzione più un rumore
     * a caso lungo [noise]. Con noise = 1 due frasi dello stesso argomento hanno coseno ≈ 0,5,
     * come i modelli veri su frasi vicine; argomenti diversi ≈ 0.
     */
    private class Fake(val dim: Int, topics: Int, seed: Long, private val noise: Float = 1f) {
        private val r = SplittableRandom(seed)
        val dirs = List(topics) { unit() }
        private fun gauss(): Float = (kotlin.math.sqrt(-2.0 * kotlin.math.ln(1.0 - r.nextDouble())) * kotlin.math.cos(2 * Math.PI * r.nextDouble())).toFloat()
        private fun unit() = Vec.normalized(FloatArray(dim) { gauss() })
        fun sentence(topic: Int): FloatArray {
            val e = unit()
            return Vec.normalized(FloatArray(dim) { dirs[topic][it] + noise * e[it] })
        }
    }

    @Test
    fun findsTheTopicBoundaries() {
        val f = Fake(256, 3, 3)
        val vs = List(6) { f.sentence(0) } + List(5) { f.sentence(1) } + List(7) { f.sentence(2) }
        val seg = Segmenter.segment(vs)
        assertArrayEquals(intArrayOf(5, 10), seg.cuts(3))
        assertEquals(listOf(0 until 6, 6 until 11, 11 until 18), seg.pieces(seg.cuts(3)))
    }

    @Test
    fun grainsAreNested() {
        val f = Fake(256, 6, 4)
        val vs = (0 until 6).flatMap { t -> List(3 + t % 3) { f.sentence(t) } }
        val seg = Segmenter.segment(vs)
        for (k in 2..6) assertTrue(seg.cuts(k).toSet().containsAll(seg.cuts(k - 1).toSet()))
        assertTrue(seg.cuts(Grain.FINE, EngineProfile.DEFAULT).toSet().containsAll(seg.cuts(Grain.COARSE, EngineProfile.DEFAULT).toSet()))
        // Nessun pezzo più corto di due frasi.
        assertTrue(seg.pieces(seg.cuts(20)).all { it.count() >= 2 })
    }

    @Test
    fun piecesAboutTheSameThingShareAGroup() {
        // Tre pezzi: A, B, poi di nuovo A più avanti nella nota. Il terzo prende il gruppo del primo (lo stesso colore).
        val f = Fake(256, 2, 7)
        val vs = List(4) { f.sentence(0) } + List(4) { f.sentence(1) } + List(4) { f.sentence(0) }
        val seg = Segmenter.segment(vs)
        val t = NoteTopics(emptyList(), seg, emptyList(), 0, vs)
        val cuts = seg.cuts(3)
        assertArrayEquals(intArrayOf(3, 7), cuts)
        assertArrayEquals(intArrayOf(0, 1, 0), t.groups(cuts, EngineProfile.DEFAULT.pair))
    }

    // --- album ---

    @Test
    fun groupsPiecesIntoAlbumsWhateverTheOrder() {
        val f = Fake(256, 12, 5)
        val topics = Topics(256)
        val truth = HashMap<Long, Int>()
        val order = (0 until 12 * 40).map { it.toLong() }.shuffled(java.util.Random(7))
        for (id in order) {
            val t = (id % 12).toInt()
            truth[id] = t
            topics.add(id, f.sentence(t))
        }
        topics.maintain()
        // Purezza: in ogni album mostrato, quasi tutti i pezzi vengono dallo stesso argomento.
        val shown = topics.shown()
        var good = 0
        var all = 0
        for ((_, members) in shown) {
            val counts = members.groupingBy { truth.getValue(it) }.eachCount()
            good += counts.values.max()
            all += members.size
        }
        assertTrue("purezza ${good.toFloat() / all}", good.toFloat() / all > 0.95f)
        assertTrue("album: ${shown.size}", shown.size in 12..16)
    }

    @Test
    fun removingGivesBackTheSameAlbums() {
        val f = Fake(256, 4, 8)
        val topics = Topics(256)
        for (id in 0L until 40L) topics.add(id, f.sentence((id % 4).toInt()))
        val before = topics.albumCount
        for (id in 40L until 60L) topics.add(id, f.sentence(1))
        for (id in 40L until 60L) topics.remove(id)
        assertEquals(before, topics.albumCount)
        assertEquals(40, topics.pieceCount)
    }

    @Test
    fun conceptsGroupEveryShownAlbumOnce() {
        val f = Fake(256, 12, 7)
        val topics = Topics(256)
        for (id in 0L until 12L * 30) topics.add(id, f.sentence((id % 12).toInt()))
        topics.maintain()
        val shown = topics.shown().map { it.first }.toSet()
        val concetti = topics.concetti()
        // Ogni album mostrato sta in un concetto, e uno solo.
        assertEquals(shown, concetti.flatten().toSet())
        assertEquals(shown.size, concetti.flatten().size)
        // Argomenti finti tutti diversi tra loro: niente li unisce.
        assertEquals(shown.size, topics.concetti(quanto = 10f).size)
    }

    @Test
    fun searchFindsTheRightTopic() {
        val f = Fake(256, 20, 9)
        val topics = Topics(256)
        for (id in 0L until 2000L) topics.add(id, f.sentence((id % 20).toInt()))
        val hits = topics.search(f.sentence(7), 10)
        assertTrue(hits.all { it.id % 20 == 7L })
    }

    // --- il commit ---

    /** Un modello finto: ogni parola chiave porta verso il suo argomento. Conta quante frasi riceve. */
    private class FakeEmbedder(private val f: Fake) : Embedder {
        override val dim = 256
        var calls = 0
        override fun embed(sentences: List<String>): List<FloatArray> {
            calls += sentences.size
            return sentences.map { s ->
                val t = when {
                    "Dock" in s -> 0
                    "promessa" in s -> 1
                    else -> 2
                }
                val r = SplittableRandom(s.hashCode().toLong())
                val e = Vec.normalized(FloatArray(dim) { r.nextDouble(-1.0, 1.0).toFloat() })
                Vec.normalized(FloatArray(dim) { f.dirs[t][it] + e[it] })
            }
        }
    }

    @Test
    fun aCommitOnlyEmbedsWhatChanged() {
        val emb = FakeEmbedder(Fake(256, 3, 10))
        val engine = Engine(emb, EngineProfile.DEFAULT)
        val text = buildString {
            for (i in 1..4) append("Il Dock numero $i va più basso. ")
            for (i in 1..4) append("La promessa numero $i è il minimo. ")
            for (i in 1..4) append("Il film numero $i da vedere. ")
        }
        val first = engine.commit("nota", text)
        assertEquals(12, first.embedded)
        assertEquals(3, first.pieces.size)
        // Una frase cambiata: una sola al modello, e solo il suo pezzo cambia negli album.
        val second = engine.commit("nota", text.replace("La promessa numero 2 è il minimo.", "La promessa numero 2 resta il minimo."))
        assertEquals(1, second.embedded)
        assertEquals(first.pieces[0].first, second.pieces[0].first)
        assertEquals(first.pieces[2].first, second.pieces[2].first)
        assertTrue(first.pieces[1].first != second.pieces[1].first)
        assertEquals(3, engine.topics.pieceCount)
        engine.forget("nota")
        assertEquals(0, engine.topics.pieceCount)
    }

    // --- quanto regge ---

    @Test
    fun scanningAMillionCodesIsFast() {
        val sim = SimHash(256)
        val index = HammingIndex(sim)
        val r = SplittableRandom(11)
        val code = LongArray(sim.words)
        for (id in 0L until 1_000_000L) {
            for (i in code.indices) code[i] = r.nextLong()
            index.put(id, code)
        }
        repeat(3) { index.nearest(code, 50) } // riscaldamento
        val t0 = System.nanoTime()
        val near = index.nearest(code, 50)
        val ms = (System.nanoTime() - t0) / 1e6
        println("1 milione di codici da 256 bit, i 50 più vicini: ${"%.1f".format(ms)} ms")
        assertEquals(0, near.first().second)
        assertTrue(ms < 400)
    }

    @Test
    fun addingAHundredThousandPieces() {
        val f = Fake(256, 2000, 12)
        val topics = Topics(256)
        val vs = List(100_000) { f.sentence(it % 2000) }
        val t0 = System.nanoTime()
        for (i in vs.indices) topics.add(i.toLong(), vs[i])
        val add = (System.nanoTime() - t0) / 1e6
        val t1 = System.nanoTime()
        topics.maintain()
        val keep = (System.nanoTime() - t1) / 1e6
        println("100 000 pezzi in 2000 argomenti: aggiunti in ${"%.0f".format(add)} ms (${"%.3f".format(add / 100_000)} ms l'uno), manutenzione ${"%.0f".format(keep)} ms, album mostrati ${topics.shown().size}")
        assertTrue(topics.shown().size in 1800..2300)
    }
}
