package com.pasao.transcrify.engine.tokenize

import java.text.BreakIterator
import java.util.Locale

/** Un passo di pulizia del testo prima di tagliarlo in pezzi. */
internal fun interface Normalizer {
    fun apply(text: String): String
}

/** Più passi di fila. */
internal class NormalizerSequence(private val steps: List<Normalizer>) : Normalizer {
    override fun apply(text: String): String = steps.fold(text) { t, n -> n.apply(t) }
}

/** Sostituisce un testo fisso con un altro (Gemma: lo spazio diventa «▁»). */
internal class ReplaceString(private val from: String, private val to: String) : Normalizer {
    override fun apply(text: String): String = text.replace(from, to)
}

/** Sostituisce un'espressione regolare (e5: più spazi di fila diventano uno). */
internal class ReplaceRegex(pattern: String, private val to: String) : Normalizer {
    private val regex = Regex(pattern)
    override fun apply(text: String): String = regex.replace(text, Regex.escapeReplacement(to))
}

/**
 * La normalizzazione di SentencePiece (quasi NFKC) già compilata dentro il tokenizer.json:
 * un trie double-array (darts-clone) dai byte UTF-8 di un pezzo al suo testo normalizzato.
 *
 * Fa esattamente quello che fa Hugging Face (`Precompiled` in tokenizers): per ogni grafema
 * (lettera più accenti combinati, emoji composte…) se è più corto di 6 byte si prova a
 * sostituirlo intero; se no, o se non c'è, si prova carattere per carattere.
 */
internal class Precompiled(blob: ByteArray) : Normalizer {
    private val trie: IntArray
    private val normalized: ByteArray

    init {
        val trieBytes = le32(blob, 0)
        trie = IntArray(trieBytes / 4) { le32(blob, 4 + 4 * it) }
        normalized = blob.copyOfRange(4 + trieBytes, blob.size)
    }

    override fun apply(text: String): String {
        val out = StringBuilder(text.length + 8)
        val bytes = ByteArray(text.length * 3 + 4)
        val graphemes = BreakIterator.getCharacterInstance(Locale.ROOT)
        graphemes.setText(text)
        var start = graphemes.first()
        var end = graphemes.next()
        while (end != BreakIterator.DONE) {
            val n = utf8(text, start, end, bytes)
            val whole = if (n < 6) lookup(bytes, n) else -1
            if (whole >= 0) {
                appendNormalized(out, whole)
            } else {
                var i = start
                while (i < end) {
                    val next = i + Character.charCount(text.codePointAt(i))
                    val m = lookup(bytes, utf8(text, i, next, bytes))
                    if (m >= 0) appendNormalized(out, m) else out.append(text, i, next)
                    i = next
                }
            }
            start = end
            end = graphemes.next()
        }
        return out.toString()
    }

    /**
     * La prima voce del trie che è un prefisso di bytes[0 until n]: il suo posto nel testo
     * normalizzato, o -1. Come Hugging Face, vale la PRIMA (la più corta), e sostituisce tutto il pezzo.
     */
    private fun lookup(bytes: ByteArray, n: Int): Int {
        var pos = 0
        var unit = trie[pos]
        pos = pos xor offset(unit)
        for (k in 0 until n) {
            val c = bytes[k].toInt() and 0xFF
            if (c == 0) return -1
            pos = pos xor c
            unit = trie[pos]
            if (label(unit) != c) return -1
            pos = pos xor offset(unit)
            if (hasLeaf(unit)) return value(trie[pos])
        }
        return -1
    }

    private fun appendNormalized(out: StringBuilder, at: Int) {
        var end = at
        while (end < normalized.size && normalized[end] != 0.toByte()) end++
        out.append(String(normalized, at, end - at, Charsets.UTF_8))
    }

    private companion object {
        // Il formato di una cella del double-array di darts-clone.
        fun hasLeaf(u: Int) = (u ushr 8) and 1 == 1
        fun value(u: Int) = u and 0x7FFFFFFF
        fun label(u: Int) = u and (0x80000000.toInt() or 0xFF)
        fun offset(u: Int) = (u ushr 10) shl ((u and (1 shl 9)) ushr 6)

        fun le32(b: ByteArray, i: Int) =
            (b[i].toInt() and 0xFF) or ((b[i + 1].toInt() and 0xFF) shl 8) or
                ((b[i + 2].toInt() and 0xFF) shl 16) or ((b[i + 3].toInt() and 0xFF) shl 24)
    }
}

/** I byte UTF-8 di text[from until to] in [out]: quanti sono. Senza creare stringhe. */
internal fun utf8(text: CharSequence, from: Int, to: Int, out: ByteArray): Int {
    var n = 0
    var i = from
    while (i < to) {
        val c = text[i].code
        when {
            c < 0x80 -> out[n++] = c.toByte()
            c < 0x800 -> {
                out[n++] = (0xC0 or (c shr 6)).toByte()
                out[n++] = (0x80 or (c and 0x3F)).toByte()
            }
            Character.isHighSurrogate(text[i]) && i + 1 < to && Character.isLowSurrogate(text[i + 1]) -> {
                val cp = Character.toCodePoint(text[i], text[i + 1])
                out[n++] = (0xF0 or (cp shr 18)).toByte()
                out[n++] = (0x80 or ((cp shr 12) and 0x3F)).toByte()
                out[n++] = (0x80 or ((cp shr 6) and 0x3F)).toByte()
                out[n++] = (0x80 or (cp and 0x3F)).toByte()
                i++
            }
            else -> {
                out[n++] = (0xE0 or (c shr 12)).toByte()
                out[n++] = (0x80 or ((c shr 6) and 0x3F)).toByte()
                out[n++] = (0x80 or (c and 0x3F)).toByte()
            }
        }
        i++
    }
    return n
}
