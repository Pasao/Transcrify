package com.pasao.transcrify.engine

/** Chi dà il senso alle frasi: il modello scaricato (più preciso o più leggero). Lavora a gruppi. */
interface Embedder {
    val dim: Int
    fun embed(sentences: List<String>): List<FloatArray>
}

/** Gli argomenti di una nota, dopo un salvataggio. */
class NoteTopics(
    val sentences: List<Span>,
    val segmentation: Segmentation,
    /** I pezzi alla grana media, come intervalli di frasi, con il loro id. */
    val pieces: List<Pair<Long, IntRange>>,
    /** Quante frasi è servito mandare al modello: le altre erano già ricordate. */
    val embedded: Int,
    /** Il senso di ogni frase, nell'ordine del testo (lunghi 1). */
    val vectors: List<FloatArray>,
) {
    /**
     * Le frasi chiave: per ogni pezzo, la frase che gli somiglia di più (la più vicina alla direzione
     * media del pezzo). È il riassunto che si può fare senza scrivere niente: le tue frasi, scelte.
     * O(frasi · dim), senza modello.
     */
    fun keySentences(cuts: IntArray): IntArray {
        if (vectors.isEmpty()) return IntArray(0)
        return segmentation.pieces(cuts).map { r ->
            val center = FloatArray(vectors[0].size)
            for (i in r) Vec.addTo(center, vectors[i])
            r.maxBy { Vec.dot(vectors[it], center) }
        }.toIntArray()
    }
}

/**
 * Il motore, al salvataggio di una nota: il tuo «commit».
 *
 * 1. Il testo si divide in frasi e ogni frase prende la sua impronta.
 * 2. Al modello vanno solo le frasi mai viste (né qui né in altre note): è l'unica parte cara.
 * 3. I confini si ricalcolano interi: costano microsecondi.
 * 4. Ogni pezzo ha un id fatto dal suo contenuto: i pezzi che non sono cambiati restano dove sono,
 *    negli album si tolgono e aggiungono solo quelli nuovi.
 *
 * Quindi modificare una frase in una nota lunga costa una frase al modello e un paio di pezzi negli album.
 */
class Engine(
    private val embedder: Embedder,
    /** Le soglie del modello che dà il senso: ognuno ha la sua scala. */
    private val profile: EngineProfile,
    val topics: Topics = Topics(embedder.dim, profile.pair, profile.split),
    /** Il senso delle frasi già capite (da disco, vedi [SentenceStore]). */
    private val memory: MutableMap<Fingerprint, Int8Vec> = HashMap(),
    /** Chiamato con le frasi appena capite: per scriverle su disco. */
    private val learned: (Map<Fingerprint, Int8Vec>) -> Unit = {},
) {
    private val notePieces = HashMap<String, List<Long>>()

    /** Di ogni pezzo negli album: la nota e le sue frasi. */
    private val pieceAt = HashMap<Long, Pair<String, IntRange>>()

    fun piece(id: Long): Pair<String, IntRange>? = pieceAt[id]

    val remembered get() = memory.size

    fun commit(noteId: String, text: String): NoteTopics {
        val spans = Sentences.split(text)
        val prints = spans.map { Fingerprint.of(it.of(text)) }
        val missing = LinkedHashMap<Fingerprint, String>()
        for (i in spans.indices) if (prints[i] !in memory) missing.putIfAbsent(prints[i], spans[i].of(text))
        if (missing.isNotEmpty()) {
            val vs = embedder.embed(missing.values.toList())
            val fresh = LinkedHashMap<Fingerprint, Int8Vec>()
            missing.keys.forEachIndexed { i, fp -> fresh[fp] = Int8Vec.of(Vec.normalized(vs[i])) }
            memory.putAll(fresh)
            learned(fresh)
        }
        val vectors = prints.map { memory.getValue(it).toFloats() }
        val seg = Segmenter.segment(vectors, profile.depthScale)
        // I pezzi degli album sono quelli della grana media che vedi pizzicando.
        val ranges = seg.pieces(seg.levelCuts(2, profile))
        val pieces = ranges.map { pieceId(noteId, prints, it) to it }
        val before = notePieces[noteId].orEmpty().toHashSet()
        val now = pieces.map { it.first }.toHashSet()
        for (id in before) if (id !in now) {
            topics.remove(id)
            pieceAt.remove(id)
        }
        for ((id, r) in pieces) {
            pieceAt[id] = noteId to r
            if (id in before) continue
            val sum = FloatArray(embedder.dim)
            for (i in r) Vec.addTo(sum, vectors[i])
            topics.add(id, sum)
        }
        notePieces[noteId] = pieces.map { it.first }
        if (spans.isEmpty()) notePieces.remove(noteId)
        return NoteTopics(spans, seg, pieces, missing.size, vectors)
    }

    /** La nota è stata eliminata: i suoi pezzi escono dagli album. Il senso delle frasi resta ricordato. */
    fun forget(noteId: String) {
        for (id in notePieces.remove(noteId).orEmpty()) {
            topics.remove(id)
            pieceAt.remove(id)
        }
    }

    /** L'id di un pezzo: dalla nota e dalle impronte delle sue frasi, in ordine. */
    private fun pieceId(noteId: String, prints: List<Fingerprint>, r: IntRange): Long {
        var h = XxHash64.hash(noteId.toByteArray(Charsets.UTF_8), 1)
        for (i in r) h = h * 31 + prints[i].hi xor prints[i].lo
        return XxHash64.hash(longToBytes(h), 2)
    }

    private fun longToBytes(x: Long) = ByteArray(8) { (x ushr (8 * it)).toByte() }
}
