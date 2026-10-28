package com.pasao.transcrify.engine

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Le operazioni sui vettori del senso. Tutto su array semplici: niente oggetti per numero, niente copie inutili. */
object Vec {
    fun dot(a: FloatArray, b: FloatArray): Float {
        var s = 0f
        for (i in a.indices) s += a[i] * b[i]
        return s
    }

    fun norm(a: FloatArray): Float = sqrt(dot(a, a))

    /** Lo stesso vettore, lungo 1. Un vettore nullo resta nullo. */
    fun normalized(a: FloatArray): FloatArray {
        val n = norm(a)
        return if (n == 0f) a.copyOf() else FloatArray(a.size) { a[it] / n }
    }

    fun cosine(a: FloatArray, b: FloatArray): Float {
        val d = norm(a) * norm(b)
        return if (d == 0f) 0f else dot(a, b) / d
    }

    /** [into] += [v] × [k], sul posto. */
    fun addTo(into: FloatArray, v: FloatArray, k: Float = 1f) {
        for (i in into.indices) into[i] += v[i] * k
    }
}

/**
 * Un vettore in 8 bit: un byte per numero e una scala. Quattro volte più piccolo dei float,
 * e il coseno che se ne ricava sbaglia di millesimi: basta per riordinare i candidati.
 */
class Int8Vec(val q: ByteArray, val scale: Float) {
    fun toFloats(): FloatArray = FloatArray(q.size) { q[it] * scale / 127f }

    fun dot(v: FloatArray): Float {
        var f = 0f
        for (i in q.indices) f += q[i] * v[i]
        return f * scale / 127f
    }

    fun dot(o: Int8Vec): Float {
        var s = 0
        for (i in q.indices) s += q[i] * o.q[i]
        return s * (scale / 127f) * (o.scale / 127f)
    }

    companion object {
        fun of(v: FloatArray): Int8Vec {
            var m = 0f
            for (x in v) if (kotlin.math.abs(x) > m) m = kotlin.math.abs(x)
            if (m == 0f) return Int8Vec(ByteArray(v.size), 0f)
            return Int8Vec(ByteArray(v.size) { (v[it] / m * 127f).roundToInt().coerceIn(-127, 127).toByte() }, m)
        }
    }
}

/**
 * I codici binari del senso (SimHash, Charikar 2002): [bits] iperpiani a caso, fissati una volta per
 * tutte da un seme; ogni bit dice da che parte dell'iperpiano sta il vettore. Due vettori con un angolo
 * θ hanno ogni bit diverso con probabilità θ/π: contare i bit diversi (popcount dello XOR) stima il coseno.
 *
 * 256 bit = 32 byte per frase o argomento. Un milione di codici sono 32 MB e si confrontano tutti
 * in qualche millisecondo: è il primo setaccio, poi i pochi candidati si riordinano col vettore vero.
 */
class SimHash(val dim: Int, val bits: Int = 256, seed: Long = 0x51_4D_48_41_53_48L) {
    init {
        require(bits % 64 == 0) { "bits deve essere un multiplo di 64" }
    }

    val words = bits / 64

    /** Gli iperpiani, uno per riga: [bits] × [dim] numeri gaussiani. */
    private val planes: FloatArray = run {
        val rnd = java.util.SplittableRandom(seed)
        FloatArray(bits * dim) { gaussian(rnd) }
    }

    fun code(v: FloatArray): LongArray = signs(project(v))

    /**
     * Le [bits] proiezioni di [v] sugli iperpiani. Sono lineari: la proiezione di una somma è la somma
     * delle proiezioni. Così il codice di un album si tiene aggiornato sommando quelle dei suoi pezzi,
     * in O(bits), senza mai riproiettare la sua direzione.
     */
    fun project(v: FloatArray): FloatArray {
        val out = FloatArray(bits)
        for (b in 0 until bits) {
            var s = 0f
            val o = b * dim
            for (i in 0 until dim) s += planes[o + i] * v[i]
            out[b] = s
        }
        return out
    }

    /** Il codice dai segni delle proiezioni. */
    fun signs(proj: FloatArray): LongArray {
        val out = LongArray(words)
        for (b in 0 until bits) if (proj[b] >= 0f) out[b ushr 6] = out[b ushr 6] or (1L shl (b and 63))
        return out
    }

    /** Quanti bit diversi: 0 = stessa direzione, [bits] = direzione opposta. */
    fun hamming(a: LongArray, b: LongArray): Int {
        var d = 0
        for (i in 0 until words) d += java.lang.Long.bitCount(a[i] xor b[i])
        return d
    }

    /** Il coseno stimato da una distanza di Hamming. */
    fun cosineOf(hamming: Int): Float = cos(PI * hamming / bits).toFloat()

    /** La distanza di Hamming che corrisponde (in media) a un coseno: per scegliere le soglie. */
    fun hammingOf(cosine: Float): Int = (kotlin.math.acos(cosine.coerceIn(-1f, 1f).toDouble()) / PI * bits).roundToInt()

    private fun gaussian(r: java.util.SplittableRandom): Float {
        // Box–Muller: due uniformi, una gaussiana.
        val u = 1.0 - r.nextDouble()
        val v = r.nextDouble()
        return (sqrt(-2.0 * ln(u)) * cos(2 * PI * v)).toFloat()
    }
}
