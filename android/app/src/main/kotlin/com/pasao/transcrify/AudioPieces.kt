package com.pasao.transcrify

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteOrder
import kotlin.math.abs

/**
 * Prepara un audio per Groq, che accetta file fino a 25 MB e solo alcuni formati.
 * Se va bene così com'è non si tocca. Altrimenti si converte in AAC mono, leggero (32 kbps), e ogni
 * pezzo si chiude nel primo silenzio dopo [SEEK_FROM_US], mai nel mezzo di una parola se si può.
 * I pezzi si trascrivono uno alla volta e il testo si riunisce.
 */
object AudioPieces {
    private const val MAX_BYTES = 24L * 1_048_576
    private val ACCEPTED = setOf("m4a", "mp4", "mp3", "mpeg", "mpga", "ogg", "opus", "oga", "wav", "flac", "webm")

    /** A 32 kbps 90 minuti fanno circa 21 MB: stanno larghi sotto il limite. Il taglio avviene da 80 a 90. */
    private const val SEEK_FROM_US = 80L * 60 * 1_000_000
    private const val FORCE_AT_US = 90L * 60 * 1_000_000
    private const val BITRATE = 32_000

    /** Sotto questo volume (picco, 0–32767) e per [QUIET_US] di fila, è silenzio. */
    private const val QUIET_PEAK = 900
    private const val QUIET_US = 250_000L
    private const val TIMEOUT_US = 10_000L

    fun of(audio: File, work: File): List<File> {
        if (audio.length() <= MAX_BYTES && audio.extension.lowercase() in ACCEPTED) return listOf(audio)
        work.mkdirs()
        return convert(audio, work)
    }

    private fun convert(src: File, work: File): List<File> {
        val extractor = MediaExtractor().apply { setDataSource(src.absolutePath) }
        val track = (0 until extractor.trackCount).first { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!!.startsWith("audio/") }
        extractor.selectTrack(track)
        val format = extractor.getTrackFormat(track)
        val decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!).apply { configure(format, null, null, 0); start() }
        var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

        val pieces = mutableListOf<File>()
        var piece: Piece? = null
        var written = 0L
        var quietFor = 0L
        val info = MediaCodec.BufferInfo()
        var inputDone = false
        try {
            while (true) {
                if (!inputDone) {
                    val i = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (i >= 0) {
                        val n = extractor.readSampleData(decoder.getInputBuffer(i)!!, 0)
                        if (n < 0) {
                            decoder.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(i, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val o = decoder.dequeueOutputBuffer(info, TIMEOUT_US)
                if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    rate = decoder.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = decoder.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
                if (o < 0) continue
                val eos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                if (info.size > 0) {
                    val out = decoder.getOutputBuffer(o)!!.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                    // Mono: si tiene la media dei canali. Il picco del blocco dice se qui è silenzio.
                    val mono = ShortArray(out.remaining() / channels)
                    var peak = 0
                    for (s in mono.indices) {
                        var sum = 0
                        for (c in 0 until channels) sum += out.get()
                        mono[s] = (sum / channels).toShort()
                        peak = maxOf(peak, abs(mono[s].toInt()))
                    }
                    val blockUs = mono.size * 1_000_000L / rate
                    quietFor = if (peak < QUIET_PEAK) quietFor + blockUs else 0
                    val at = piece?.let { written * 1_000_000L / rate } ?: 0
                    if (piece != null && (at >= FORCE_AT_US || (at >= SEEK_FROM_US && quietFor >= QUIET_US))) {
                        piece.finish()
                        piece = null
                        quietFor = 0
                    }
                    if (piece == null) {
                        written = 0
                        piece = Piece(File(work, "pezzo-${pieces.size}.m4a").also { pieces += it }, rate)
                    }
                    piece.write(mono, written * 1_000_000L / rate)
                    written += mono.size
                }
                decoder.releaseOutputBuffer(o, false)
                if (eos) break
            }
            piece?.finish()
            piece = null
        } finally {
            piece?.abandon()
            runCatching { decoder.stop() }
            decoder.release()
            extractor.release()
        }
        if (pieces.isEmpty()) throw IllegalStateException("Nessun audio")
        return pieces
    }

    /** Un pezzo in costruzione: dentro campioni mono, fuori un file .m4a. */
    private class Piece(file: File, private val rate: Int) {
        private val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        private val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
            configure(
                MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, rate, 1).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
                },
                null, null, MediaCodec.CONFIGURE_FLAG_ENCODE,
            )
            start()
        }
        private var track = -1
        private val info = MediaCodec.BufferInfo()

        /** Il codificatore ha già dato tutto: non c'è altro da aspettare. */
        private var ended = false

        fun write(samples: ShortArray, startUs: Long) {
            var from = 0
            while (from < samples.size) {
                val i = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (i >= 0) {
                    val buffer = encoder.getInputBuffer(i)!!.order(ByteOrder.LITTLE_ENDIAN)
                    val n = minOf(samples.size - from, buffer.remaining() / 2)
                    buffer.asShortBuffer().put(samples, from, n)
                    encoder.queueInputBuffer(i, 0, n * 2, startUs + from * 1_000_000L / rate, 0)
                    from += n
                }
                drain(false)
            }
        }

        fun finish() {
            var sent = false
            while (!sent) {
                val i = encoder.dequeueInputBuffer(TIMEOUT_US)
                if (i >= 0) {
                    encoder.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    sent = true
                }
                drain(false)
            }
            drain(true)
            encoder.stop()
            encoder.release()
            muxer.stop()
            muxer.release()
        }

        fun abandon() {
            runCatching { encoder.stop() }
            encoder.release()
            runCatching { muxer.release() }
        }

        private fun drain(toEnd: Boolean) {
            while (!ended) {
                // Mentre si scrive non si aspetta: quello che è pronto si prende, il resto al prossimo giro.
                val o = encoder.dequeueOutputBuffer(info, if (toEnd) TIMEOUT_US else 0)
                when {
                    o == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!toEnd) return
                    o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                    }
                    o >= 0 -> {
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0 && info.size > 0) {
                            muxer.writeSampleData(track, encoder.getOutputBuffer(o)!!, info)
                        }
                        ended = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        encoder.releaseOutputBuffer(o, false)
                    }
                }
            }
        }
    }
}
