package com.pasao.transcrify.engine

/**
 * L'impronta di una frase: 128 bit, due xxHash64 con semi diversi sul testo in UTF-8.
 *
 * Serve a ricordare il lavoro già fatto. Il senso di una frase (il suo embedding) si calcola una
 * volta sola e si ritrova dall'impronta: se una frase non cambia, o compare in due note, non si
 * ricalcola. Con 128 bit due frasi diverse con la stessa impronta restano impossibili in pratica
 * anche con miliardi di frasi (con 64 bit, già a qualche miliardo, no).
 */
data class Fingerprint(val hi: Long, val lo: Long) {
    fun toBytes(): ByteArray = ByteArray(16).also { b ->
        for (i in 0 until 8) {
            b[i] = (hi ushr (56 - 8 * i)).toByte()
            b[8 + i] = (lo ushr (56 - 8 * i)).toByte()
        }
    }

    companion object {
        /** La frase così com'è, con gli spazi ripuliti: due spazi o un a-capo in più non la rendono un'altra frase. */
        fun of(sentence: String): Fingerprint {
            val bytes = sentence.trim().replace(WHITESPACE, " ").toByteArray(Charsets.UTF_8)
            return Fingerprint(XxHash64.hash(bytes, SEED_HI), XxHash64.hash(bytes, SEED_LO))
        }

        fun fromBytes(b: ByteArray): Fingerprint {
            require(b.size == 16)
            var hi = 0L
            var lo = 0L
            for (i in 0 until 8) {
                hi = (hi shl 8) or (b[i].toLong() and 0xFF)
                lo = (lo shl 8) or (b[8 + i].toLong() and 0xFF)
            }
            return Fingerprint(hi, lo)
        }

        private val WHITESPACE = Regex("\\s+")
        private const val SEED_HI = 0x5472616E73637269L // "Transcri"
        private const val SEED_LO = 0x4E6F7465506F7465L // "NotePote"
    }
}

/** xxHash64 (Yann Collet): veloce e con una distribuzione ottima. Implementazione dello standard. */
object XxHash64 {
    private val P1 = 0x9E3779B185EBCA87uL.toLong()
    private val P2 = 0xC2B2AE3D27D4EB4FuL.toLong()
    private val P3 = 0x165667B19E3779F9uL.toLong()
    private val P4 = 0x85EBCA77C2B2AE63uL.toLong()
    private val P5 = 0x27D4EB2F165667C5uL.toLong()

    fun hash(b: ByteArray, seed: Long = 0): Long {
        val n = b.size
        var i = 0
        var h: Long
        if (n >= 32) {
            var v1 = seed + P1 + P2
            var v2 = seed + P2
            var v3 = seed
            var v4 = seed - P1
            while (i <= n - 32) {
                v1 = round(v1, long(b, i))
                v2 = round(v2, long(b, i + 8))
                v3 = round(v3, long(b, i + 16))
                v4 = round(v4, long(b, i + 24))
                i += 32
            }
            h = rotl(v1, 1) + rotl(v2, 7) + rotl(v3, 12) + rotl(v4, 18)
            h = merge(h, v1)
            h = merge(h, v2)
            h = merge(h, v3)
            h = merge(h, v4)
        } else {
            h = seed + P5
        }
        h += n.toLong()
        while (i <= n - 8) {
            h = h xor round(0, long(b, i))
            h = rotl(h, 27) * P1 + P4
            i += 8
        }
        if (i <= n - 4) {
            h = h xor ((int(b, i).toLong() and 0xFFFFFFFFL) * P1)
            h = rotl(h, 23) * P2 + P3
            i += 4
        }
        while (i < n) {
            h = h xor ((b[i].toLong() and 0xFF) * P5)
            h = rotl(h, 11) * P1
            i++
        }
        h = h xor (h ushr 33)
        h *= P2
        h = h xor (h ushr 29)
        h *= P3
        h = h xor (h ushr 32)
        return h
    }

    private fun round(acc: Long, input: Long): Long = rotl(acc + input * P2, 31) * P1
    private fun merge(acc: Long, v: Long): Long = (acc xor round(0, v)) * P1 + P4
    private fun rotl(x: Long, r: Int): Long = java.lang.Long.rotateLeft(x, r)

    private fun long(b: ByteArray, i: Int): Long {
        var v = 0L
        for (k in 7 downTo 0) v = (v shl 8) or (b[i + k].toLong() and 0xFF)
        return v
    }

    private fun int(b: ByteArray, i: Int): Int =
        (b[i].toInt() and 0xFF) or ((b[i + 1].toInt() and 0xFF) shl 8) or
            ((b[i + 2].toInt() and 0xFF) shl 16) or ((b[i + 3].toInt() and 0xFF) shl 24)
}
