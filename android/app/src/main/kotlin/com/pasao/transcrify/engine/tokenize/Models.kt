package com.pasao.transcrify.engine.tokenize

/** Da una parola agli id del vocabolario. */
internal interface WordModel {
    fun tokenize(word: String, out: IntList)
}

/**
 * Unigram di SentencePiece (e5, XLM-RoBERTa): tra tutti i modi di dividere la parola in pezzi
 * del vocabolario si prende quello con la probabilità più alta (Viterbi). Ogni pezzo ha il suo
 * punteggio (logaritmo della probabilità); i caratteri che non ci sono diventano «sconosciuto»,
 * con un punteggio peggiore di ogni pezzo vero, e gli sconosciuti di fila si fondono in uno.
 * Rifà passo per passo `Unigram::encode_optimized` di Hugging Face, anche negli spareggi.
 */
internal class Unigram(private val pieces: PieceTable, private val scores: DoubleArray, private val unkId: Int) : WordModel {
    private val unkScore = scores.min() - UNK_PENALTY

    override fun tokenize(word: String, out: IntList) {
        val n = word.length
        // Il cammino migliore che finisce in ogni posizione: punteggio, da dove parte l'ultimo pezzo, quale pezzo.
        val best = DoubleArray(n + 1)
        val from = IntArray(n + 1) { -1 }
        val piece = IntArray(n + 1)
        var start = 0
        while (start < n) {
            val here = best[start]
            val charLen = Character.charCount(word.codePointAt(start))
            var single = false
            var h = 0
            val limit = minOf(n, start + pieces.maxLength)
            for (end in start + 1..limit) {
                h = 31 * h + word[end - 1].code
                // Un pezzo non finisce mai a metà di un carattere fuori dal piano base.
                if (end < n && Character.isLowSurrogate(word[end]) && Character.isHighSurrogate(word[end - 1])) continue
                val id = pieces.get(word, start, end, h)
                if (id < 0) continue
                val score = here + scores[id]
                if (from[end] < 0 || score > best[end]) {
                    best[end] = score
                    from[end] = start
                    piece[end] = id
                }
                if (end - start == charLen) single = true
            }
            if (!single) {
                val end = start + charLen
                val score = here + unkScore
                if (from[end] < 0 || score > best[end]) {
                    best[end] = score
                    from[end] = start
                    piece[end] = unkId
                }
            }
            start += charLen
        }
        // All'indietro dalla fine, poi si rovescia.
        val mark = out.size
        var end = n
        var lastUnk = false
        while (end > 0) {
            val id = piece[end]
            if (!(id == unkId && lastUnk)) out.add(id)
            lastUnk = id == unkId
            end = from[end]
        }
        out.reverse(mark)
    }

    private companion object {
        // Come in SentencePiece: lo sconosciuto vale 10 punti (logaritmici) meno del pezzo più raro.
        const val UNK_PENALTY = 10.0
    }
}

/**
 * BPE con le fusioni in ordine di rango (Gemma): si parte dai singoli caratteri e si fonde
 * sempre la coppia vicina col rango più basso, la più a sinistra a parità. Un carattere che non è
 * nel vocabolario diventa i suoi byte UTF-8 («<0xE2>»…), così nessun testo resta sconosciuto.
 * Rifà `Word::merge_all` di Hugging Face, con lo stesso controllo delle voci scadute nella coda.
 */
internal class Bpe(
    private val vocab: PieceTable,
    private val merges: PairMap,
    private val unkId: Int,
    private val fuseUnk: Boolean,
    /** L'id di «<0xXX>» per ogni byte, o null senza ripiego sui byte. */
    private val byteIds: IntArray?,
) : WordModel {

    override fun tokenize(word: String, out: IntList) {
        val n = word.length
        // I simboli in una lista doppia su array: fondere = un simbolo assorbe quello a destra.
        val ids = IntArray(n * 4)
        var count = 0
        val bytes = ByteArray(4)
        var i = 0
        while (i < n) {
            val next = i + Character.charCount(word.codePointAt(i))
            val id = vocab.get(word, i, next)
            val nb = if (id < 0 && byteIds != null) utf8(word, i, next, bytes) else 0
            if (id >= 0) {
                ids[count++] = id
            } else if (byteIds != null && (0 until nb).all { byteIds[bytes[it].toInt() and 0xFF] >= 0 }) {
                for (k in 0 until nb) ids[count++] = byteIds[bytes[k].toInt() and 0xFF]
            } else if (!(fuseUnk && count > 0 && ids[count - 1] == unkId)) {
                ids[count++] = unkId
            }
            i = next
        }
        val prev = IntArray(count) { it - 1 }
        val nextOf = IntArray(count) { if (it + 1 < count) it + 1 else -1 }
        val alive = BooleanArray(count) { true }

        val queue = MergeQueue(count)
        for (p in 0 until count - 1) {
            val s = merges.find(ids[p], ids[p + 1])
            if (s >= 0) queue.push(merges.rank(s), p, merges.newId(s))
        }
        while (queue.isNotEmpty()) {
            val pos = queue.topPos()
            val newId = queue.topId()
            queue.pop()
            if (!alive[pos]) continue
            val right = nextOf[pos]
            if (right < 0) continue
            // Una voce scaduta: nel frattempo la coppia è cambiata.
            val s = merges.find(ids[pos], ids[right])
            if (s < 0 || merges.newId(s) != newId) continue
            ids[pos] = newId
            alive[right] = false
            nextOf[pos] = nextOf[right]
            if (nextOf[pos] >= 0) prev[nextOf[pos]] = pos
            val before = prev[pos]
            if (before >= 0) {
                val sb = merges.find(ids[before], ids[pos])
                if (sb >= 0) queue.push(merges.rank(sb), before, merges.newId(sb))
            }
            val after = nextOf[pos]
            if (after >= 0) {
                val sa = merges.find(ids[pos], ids[after])
                if (sa >= 0) queue.push(merges.rank(sa), pos, merges.newId(sa))
            }
        }
        for (p in 0 until count) if (alive[p]) out.add(ids[p])
    }

    /** Coda con priorità (min-heap) su (rango, posizione), con l'id della fusione accanto. */
    private class MergeQueue(capacity: Int) {
        private var keys = LongArray(maxOf(4, capacity))
        private var vals = IntArray(maxOf(4, capacity))
        private var size = 0

        fun isNotEmpty() = size > 0
        fun topPos() = keys[0].toInt()
        fun topId() = vals[0]

        fun push(rank: Int, pos: Int, newId: Int) {
            if (size == keys.size) {
                keys = keys.copyOf(size * 2)
                vals = vals.copyOf(size * 2)
            }
            val key = (rank.toLong() shl 32) or pos.toLong()
            var i = size++
            while (i > 0) {
                val parent = (i - 1) / 2
                if (keys[parent] <= key) break
                keys[i] = keys[parent]
                vals[i] = vals[parent]
                i = parent
            }
            keys[i] = key
            vals[i] = newId
        }

        fun pop() {
            size--
            if (size == 0) return
            val key = keys[size]
            val v = vals[size]
            var i = 0
            while (true) {
                var child = 2 * i + 1
                if (child >= size) break
                if (child + 1 < size && keys[child + 1] < keys[child]) child++
                if (keys[child] >= key) break
                keys[i] = keys[child]
                vals[i] = vals[child]
                i = child
            }
            keys[i] = key
            vals[i] = v
        }
    }
}
