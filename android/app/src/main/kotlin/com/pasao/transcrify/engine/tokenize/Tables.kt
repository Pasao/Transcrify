package com.pasao.transcrify.engine.tokenize

/**
 * Da pezzo di testo a id, per vocabolari da 250 000 voci.
 *
 * Una HashMap<String, Int> costerebbe un oggetto String e un Integer per voce (~30 MB sul telefono);
 * qui tutti i caratteri stanno in fila in un solo CharArray e la tabella è un IntArray a indirizzi aperti.
 * Si cerca anche un pezzo DENTRO un testo più lungo ([from], [to]) senza creare stringhe, e l'hash
 * è quello di String.hashCode: chi allunga il pezzo un carattere alla volta lo aggiorna in O(1).
 */
internal class PieceTable(expected: Int) {
    private var chars = CharArray(expected * 6)
    private var used = 0
    /** La voce i occupa chars[offsets[i] until offsets[i + 1]]. */
    private var offsets = IntArray(expected + 1)
    private var hashes = IntArray(expected)
    private var ids = IntArray(expected)
    private var count = 0
    /** Indice della voce + 1 (0 = posto vuoto). Mai piena oltre metà: le ricerche finiscono presto. */
    private var slots = IntArray(tableSize(expected))

    val size get() = count

    /** La voce più lunga, in caratteri: oltre non ha senso cercare. */
    var maxLength = 0
        private set

    /** Aggiunge (o sostituisce) una voce. */
    fun put(piece: CharSequence, id: Int) {
        val h = hash(piece, 0, piece.length)
        val found = find(piece, 0, piece.length, h)
        if (found >= 0) {
            ids[found] = id
            return
        }
        if (count == ids.size) grow()
        if (used + piece.length > chars.size) chars = chars.copyOf(maxOf(chars.size * 2, used + piece.length))
        for (i in piece.indices) chars[used + i] = piece[i]
        used += piece.length
        offsets[count + 1] = used
        hashes[count] = h
        ids[count] = id
        insert(count)
        count++
        if (piece.length > maxLength) maxLength = piece.length
    }

    /** L'id di [text] da [from] a [to], o -1. [hash] è quello di String.hashCode sul pezzo. */
    fun get(text: CharSequence, from: Int = 0, to: Int = text.length, hash: Int = hash(text, from, to)): Int {
        val e = find(text, from, to, hash)
        return if (e < 0) -1 else ids[e]
    }

    private fun find(text: CharSequence, from: Int, to: Int, hash: Int): Int {
        val mask = slots.size - 1
        var s = mix(hash) and mask
        while (true) {
            val e = slots[s] - 1
            if (e < 0) return -1
            if (hashes[e] == hash && same(e, text, from, to)) return e
            s = (s + 1) and mask
        }
    }

    private fun same(e: Int, text: CharSequence, from: Int, to: Int): Boolean {
        val a = offsets[e]
        if (offsets[e + 1] - a != to - from) return false
        for (i in 0 until to - from) if (chars[a + i] != text[from + i]) return false
        return true
    }

    private fun insert(e: Int) {
        val mask = slots.size - 1
        var s = mix(hashes[e]) and mask
        while (slots[s] != 0) s = (s + 1) and mask
        slots[s] = e + 1
    }

    private fun grow() {
        val n = ids.size * 2
        offsets = offsets.copyOf(n + 1)
        hashes = hashes.copyOf(n)
        ids = ids.copyOf(n)
        slots = IntArray(tableSize(n))
        for (e in 0 until count) insert(e)
    }

    companion object {
        fun hash(text: CharSequence, from: Int, to: Int): Int {
            var h = 0
            for (i in from until to) h = 31 * h + text[i].code
            return h
        }

        /** L'hash di String è debole nei bit bassi: si rimescola prima di usarlo come posto. */
        private fun mix(h: Int): Int = (h * -0x61c88647).let { it xor (it ushr 16) }

        private fun tableSize(n: Int): Int = Integer.highestOneBit(maxOf(4, n) * 2 - 1) shl 1
    }
}

/**
 * Le fusioni del BPE: (id sinistro, id destro) → (rango, id nuovo). Mezzo milione di coppie in
 * tre array semplici, a indirizzi aperti: nessun oggetto per coppia.
 */
internal class PairMap(expected: Int) {
    private val keys: LongArray
    private val ranks: IntArray
    private val merged: IntArray
    private val mask: Int

    init {
        val size = Integer.highestOneBit(maxOf(4, expected) * 2 - 1) shl 1
        keys = LongArray(size) { EMPTY }
        ranks = IntArray(size)
        merged = IntArray(size)
        mask = size - 1
    }

    /** Se una coppia torna due volte vale l'ultima, come nella HashMap di Hugging Face. */
    fun put(left: Int, right: Int, rank: Int, newId: Int) {
        val k = key(left, right)
        var s = slot(k)
        while (keys[s] != EMPTY && keys[s] != k) s = (s + 1) and mask
        keys[s] = k
        ranks[s] = rank
        merged[s] = newId
    }

    /** Il posto della coppia, o -1 se non si fonde. Poi [rank] e [newId] dicono come. */
    fun find(left: Int, right: Int): Int {
        val k = key(left, right)
        var s = slot(k)
        while (true) {
            val at = keys[s]
            if (at == k) return s
            if (at == EMPTY) return -1
            s = (s + 1) and mask
        }
    }

    fun rank(slot: Int) = ranks[slot]
    fun newId(slot: Int) = merged[slot]

    private fun key(left: Int, right: Int) = (left.toLong() shl 32) or (right.toLong() and 0xFFFFFFFFL)

    private fun slot(k: Long): Int {
        val h = k * -0x61c8864680b583ebL
        return (h xor (h ushr 29)).toInt() and mask
    }

    private companion object {
        // Gli id non sono mai negativi: -1 come chiave non esiste.
        const val EMPTY = -1L
    }
}

/** Una lista di Int che cresce, senza scatolare i numeri. */
internal class IntList(capacity: Int = 64) {
    private var a = IntArray(capacity)
    var size = 0
        private set

    fun add(x: Int) {
        if (size == a.size) a = a.copyOf(a.size * 2)
        a[size++] = x
    }

    operator fun get(i: Int) = a[i]

    /** Rovescia sul posto gli elementi da [from] alla fine. */
    fun reverse(from: Int) {
        var i = from
        var j = size - 1
        while (i < j) {
            val t = a[i]
            a[i++] = a[j]
            a[j--] = t
        }
    }

    /** Tiene solo i primi [n]. */
    fun truncate(n: Int) {
        if (n < size) size = n
    }

    fun toArray(from: Int = 0, to: Int = size): IntArray = a.copyOfRange(from, to)
}
