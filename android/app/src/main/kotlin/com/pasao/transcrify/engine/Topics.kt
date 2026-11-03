package com.pasao.transcrify.engine

/** Un risultato di una ricerca: chi, e quanto è simile (coseno). */
data class Hit(val id: Long, val score: Float)

/**
 * Un indice di codici binari con un posto per ogni cosa (un argomento, un album).
 *
 * I codici stanno tutti in fila in un solo LongArray: confrontarli è leggere memoria di seguito
 * e contare bit (popcount), la cosa più veloce che un processore sappia fare. I posti liberati
 * da una cancellazione si riusano. La ricerca tiene i migliori in un heap: O(N · parole + N log k).
 *
 * Fino a qualche milione di codici la scansione intera resta sotto i 100 ms anche su un telefono;
 * oltre si divide in liste (IVF) e se ne guardano poche: l'interfaccia resta questa.
 */
class HammingIndex(private val sim: SimHash) {
    private val w = sim.words
    private var codes = LongArray(w * 1024)
    private var ids = LongArray(1024)
    private var alive = BooleanArray(1024)
    private val slotOf = HashMap<Long, Int>()
    private val free = ArrayDeque<Int>()
    private var used = 0

    val size get() = slotOf.size

    fun put(id: Long, code: LongArray) {
        val slot = slotOf[id] ?: (free.removeLastOrNull() ?: grow()).also { slotOf[id] = it }
        System.arraycopy(code, 0, codes, slot * w, w)
        ids[slot] = id
        alive[slot] = true
    }

    fun remove(id: Long) {
        val slot = slotOf.remove(id) ?: return
        alive[slot] = false
        free.addLast(slot)
    }

    /** I [k] più vicini a [code], dal più vicino: (id, distanza di Hamming). */
    fun nearest(code: LongArray, k: Int, skip: Long = Long.MIN_VALUE): List<Pair<Long, Int>> {
        if (k <= 0) return emptyList()
        // Heap dei peggiori in cima: si scarta subito chi non entra tra i k.
        val heap = java.util.PriorityQueue<Pair<Long, Int>>(k + 1, compareByDescending { it.second })
        for (slot in 0 until used) {
            if (!alive[slot] || ids[slot] == skip) continue
            var d = 0
            val o = slot * w
            for (i in 0 until w) d += java.lang.Long.bitCount(codes[o + i] xor code[i])
            if (heap.size < k) heap.add(ids[slot] to d)
            else if (d < heap.peek().second) {
                heap.poll()
                heap.add(ids[slot] to d)
            }
        }
        return heap.sortedBy { it.second }
    }

    private fun grow(): Int {
        if (used == ids.size) {
            val n = ids.size * 2
            codes = codes.copyOf(n * w)
            ids = ids.copyOf(n)
            alive = alive.copyOf(n)
        }
        return used++
    }
}

/**
 * Gli argomenti di tutte le note, raggruppati in album, uno alla volta, senza mai ricalcolare tutto.
 *
 * Ogni album è riassunto da due cose, come in BIRCH (Zhang et al. 1996): quanti pezzi (N) e la somma
 * dei loro vettori (LS). Aggiungere o togliere un pezzo è una somma o una sottrazione: esatto, O(dim),
 * in qualunque ordine. E dalle somme si ricava, esatta, la somiglianza MEDIA (average linkage):
 *
 * - tra un pezzo v e tutti i pezzi di un album:      v · LS / N
 * - tra tutti i pezzi di due album, a coppie:        LSa · LSb / (Na · Nb)
 * - tra i pezzi di un album, a coppie (coesione):    (|LS|² − N) / (N (N − 1))
 *
 * Quindi c'è una regola sola, «in media si somigliano almeno [pair]», che vale uguale per un album
 * di un pezzo e per uno di mille, per entrare, per unire e per spezzare. Niente soglie che cambiano.
 *
 * - [add]: un pezzo va nell'album a cui somiglia di più in media, se supera [pair]; se no ne apre uno.
 *   I candidati si trovano coi codici binari delle direzioni degli album, poi si controlla esatto.
 * - [maintain], quando il telefono è in carica: rimette a posto i pezzi rimasti in bilico, unisce
 *   le coppie di album che in media si somigliano e spezza quelli che non si somigliano più.
 *   Così l'ordine in cui arrivano le note non conta.
 * - Un album si mostra da [minShown] pezzi in su: «ne hai parlato tre volte».
 *
 * Un pezzo costa: 32 byte di codice + il vettore in 8 bit (dim byte) + qualche numero.
 * Le soglie dipendono dal modello (ognuno ha la sua scala di somiglianze): si tarano una volta per modello.
 */
class Topics(
    val dim: Int,
    /** Quanto devono somigliarsi in media due pezzi per stare nello stesso album (dal profilo del modello). */
    private val pair: Float = EngineProfile.DEFAULT.pair,
    /** Sotto questa coesione un album grande si spezza. */
    private val split: Float = EngineProfile.DEFAULT.split,
    val minShown: Int = 3,
    bits: Int = 256,
) {
    private val sim = SimHash(dim, bits)

    private class Piece(val id: Long, val vec: Int8Vec, val code: LongArray, var album: Long, var margin: Float)

    private class Album(val id: Long, val sum: FloatArray, val proj: FloatArray, var n: Int, val members: LinkedHashSet<Long> = LinkedHashSet()) {
        val direction: FloatArray get() = Vec.normalized(sum)

        /** La somiglianza media di [v] con i suoi pezzi. */
        fun like(v: FloatArray): Float = Vec.dot(sum, v) / n

        /** La somiglianza media con i pezzi di un altro album. */
        fun like(o: Album): Float = Vec.dot(sum, o.sum) / (n.toFloat() * o.n)

        /** Quanto si somigliano in media i suoi pezzi tra loro (1 se ne ha uno solo). */
        val cohesion: Float get() = if (n < 2) 1f else (Vec.dot(sum, sum) - n) / (n.toFloat() * (n - 1))
    }

    private val pieces = HashMap<Long, Piece>()
    private val albums = HashMap<Long, Album>()
    private val pieceIndex = HammingIndex(sim)
    private val albumIndex = HammingIndex(sim)
    private var nextAlbum = 1L

    val pieceCount get() = pieces.size
    val albumCount get() = albums.size

    /** Un pezzo nuovo (o cambiato: il vecchio si toglie prima). Restituisce il suo album. */
    fun add(id: Long, vector: FloatArray): Long {
        remove(id)
        // Si lavora sempre sul vettore così come resta salvato (in 8 bit): le somme degli album
        // tolgono esattamente quello che avevano aggiunto, senza derive col tempo.
        val q = Int8Vec.of(Vec.normalized(vector))
        val v = q.toFloats()
        // Proiettato una volta sola: dà il codice del pezzo e aggiorna quello dell'album.
        val pv = sim.project(v)
        val code = sim.signs(pv)
        val (best, margin) = bestAlbum(v, code)
        val album = if (best != null && best.like(v) >= pair) best else newAlbum()
        val p = Piece(id, q, code, album.id, margin)
        pieces[id] = p
        pieceIndex.put(id, code)
        attach(album, p, v, pv)
        return album.id
    }

    fun remove(id: Long) {
        val p = pieces.remove(id) ?: return
        pieceIndex.remove(id)
        val a = albums[p.album] ?: return
        detach(a, p, p.vec.toFloats())
    }

    fun albumOf(id: Long): Long? = pieces[id]?.album

    /** Gli album da mostrare, dal più grande: (album, i suoi pezzi). */
    fun shown(): List<Pair<Long, List<Long>>> =
        albums.values.filter { it.n >= minShown }.sortedByDescending { it.n }.map { it.id to it.members.toList() }

    /**
     * I «grandi concetti»: gli album mostrati, raggruppati quando si somigliano abbastanza tra loro.
     * Due album stanno nello stesso concetto se i loro pezzi si somigliano in media almeno [quanto] della
     * soglia che tiene insieme un album ([pair]); basta somigliare a uno del gruppo (legame singolo).
     * Ogni album mostrato sta in un concetto solo. Dal concetto più grande; dentro, dall'album più grande.
     */
    fun concetti(quanto: Float = 0.8f): List<List<Long>> {
        val mostrati = albums.values.filter { it.n >= minShown }
        val padre = HashMap<Long, Long>().apply { mostrati.forEach { put(it.id, it.id) } }
        fun radice(x: Long): Long {
            var r = x
            while (padre[r] != r) r = padre[r]!!
            return r
        }
        for (i in mostrati.indices) for (j in i + 1 until mostrati.size) {
            if (mostrati[i].like(mostrati[j]) >= pair * quanto) padre[radice(mostrati[i].id)] = radice(mostrati[j].id)
        }
        return mostrati.groupBy { radice(it.id) }.values
            .map { g -> g.sortedByDescending { it.n } }
            .sortedByDescending { g -> g.sumOf { it.n } }
            .map { g -> g.map { it.id } }
    }

    /**
     * I pezzi più simili a [query]: prima un setaccio largo coi codici binari ([wide] candidati),
     * poi il coseno vero sui vettori in 8 bit. Il setaccio sbaglia poco, il riordino quasi niente.
     */
    fun search(query: FloatArray, k: Int, wide: Int = maxOf(64, k * 8)): List<Hit> {
        val q = Vec.normalized(query)
        return pieceIndex.nearest(sim.code(q), wide)
            .map { (id, _) -> Hit(id, pieces.getValue(id).vec.dot(q)) }
            .sortedByDescending { it.score }
            .take(k)
    }

    /**
     * La manutenzione, a telefono in carica. Tre passaggi, ognuno locale:
     * 1. i pezzi in bilico (margine piccolo tra il primo e il secondo album) si ricontrollano;
     * 2. le coppie di album che in media si somigliano si uniscono, dalla più simile;
     * 3. gli album grandi che non si somigliano più si spezzano in due (k-means sferico con k = 2).
     */
    fun maintain(unsure: Float = 0.05f) {
        // 1. In bilico.
        for (p in pieces.values.toList()) {
            if (p.margin >= unsure) continue
            val v = p.vec.toFloats()
            val (best, margin) = bestAlbum(v, p.code)
            p.margin = margin
            if (best != null && best.id != p.album && best.like(v) >= pair) move(p, best, v)
        }
        // 2. Unire: per ogni album i vicini; si uniscono le coppie che in media si somigliano, dalla più simile.
        val pairs = ArrayList<Triple<Long, Long, Float>>()
        for (a in albums.values) {
            for ((otherId, _) in albumIndex.nearest(sim.signs(a.proj), 4, skip = a.id)) {
                val o = albums[otherId] ?: continue
                val s = a.like(o)
                if (s >= pair && a.id < o.id) pairs.add(Triple(a.id, o.id, s))
            }
        }
        for ((x, y, _) in pairs.sortedByDescending { it.third }) {
            val a = albums[x] ?: continue
            val b = albums[y] ?: continue
            // Dopo le unioni di prima le somme sono cambiate: si ricontrolla.
            if (a.like(b) < pair) continue
            val (big, small) = if (a.n >= b.n) a to b else b to a
            for (id in small.members.toList()) {
                val p = pieces.getValue(id)
                move(p, big, p.vec.toFloats())
            }
        }
        // 3. Spezzare.
        for (a in albums.values.toList()) if (a.n >= 2 * minShown && a.cohesion < split) split(a)
    }

    // --- dentro ---

    /** L'album a cui [v] somiglia di più in media, e di quanto batte il secondo. */
    private fun bestAlbum(v: FloatArray, code: LongArray): Pair<Album?, Float> {
        var best: Album? = null
        var b1 = -2f
        var b2 = -2f
        for ((id, _) in albumIndex.nearest(code, 8)) {
            val a = albums[id] ?: continue
            val s = a.like(v)
            if (s > b1) {
                b2 = b1
                b1 = s
                best = a
            } else if (s > b2) b2 = s
        }
        return best to if (b2 < -1f) 1f else b1 - b2
    }

    private fun newAlbum(): Album = Album(nextAlbum++, FloatArray(dim), FloatArray(sim.bits), 0).also { albums[it.id] = it }

    private fun attach(a: Album, p: Piece, v: FloatArray, pv: FloatArray = sim.project(v)) {
        Vec.addTo(a.sum, v)
        Vec.addTo(a.proj, pv)
        a.n++
        a.members.add(p.id)
        p.album = a.id
        albumIndex.put(a.id, sim.signs(a.proj))
    }

    private fun detach(a: Album, p: Piece, v: FloatArray) {
        Vec.addTo(a.sum, v, -1f)
        Vec.addTo(a.proj, sim.project(v), -1f)
        a.n--
        a.members.remove(p.id)
        if (a.n == 0) {
            albums.remove(a.id)
            albumIndex.remove(a.id)
        } else albumIndex.put(a.id, sim.signs(a.proj))
    }

    private fun move(p: Piece, to: Album, v: FloatArray) {
        val from = albums[p.album]
        if (from != null) detach(from, p, v)
        attach(to, p, v)
    }

    /** Due metà con k-means sferico: si parte dai due pezzi più lontani tra loro (circa) e si raffina. */
    private fun split(a: Album) {
        val ids = a.members.toList()
        val vs = ids.map { pieces.getValue(it).vec.toFloats() }
        val center = a.direction
        // Il più lontano dal centro, poi il più lontano da lui: due semi ben separati.
        val s1 = vs.indices.minBy { Vec.dot(vs[it], center) }
        val s2 = vs.indices.minBy { Vec.dot(vs[it], vs[s1]) }
        var c1 = vs[s1].copyOf()
        var c2 = vs[s2].copyOf()
        var side = BooleanArray(vs.size)
        repeat(8) {
            val next = BooleanArray(vs.size) { Vec.dot(vs[it], c2) > Vec.dot(vs[it], c1) }
            val sum1 = FloatArray(dim)
            val sum2 = FloatArray(dim)
            for (i in vs.indices) Vec.addTo(if (next[i]) sum2 else sum1, vs[i])
            c1 = Vec.normalized(sum1)
            c2 = Vec.normalized(sum2)
            if (next.contentEquals(side)) return@repeat
            side = next
        }
        val n2 = side.count { it }
        if (n2 == 0 || n2 == vs.size) return
        val b = newAlbum()
        for (i in vs.indices) if (side[i]) move(pieces.getValue(ids[i]), b, vs[i])
    }
}
