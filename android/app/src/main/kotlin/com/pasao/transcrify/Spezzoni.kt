package com.pasao.transcrify

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * I pezzi di una registrazione interrotta da una pausa lunga (il registratore si chiude per poter leggere
 * quello che c'è: un .m4a si legge solo chiuso). Alla fine si riuniscono in un file solo, senza ricodificare:
 * stesso registratore, stesso formato, i campioni uno dopo l'altro.
 */
object Spezzoni {
    private const val BUFFER = 256 * 1024

    /** Riunisce [pezzi] in [dove]; dice se c'è riuscito. */
    fun unisci(pezzi: List<File>, dove: File): Boolean = runCatching {
        val muxer = MediaMuxer(dove.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            var traccia = -1
            var spostamento = 0L
            val buf = ByteBuffer.allocate(BUFFER)
            val info = MediaCodec.BufferInfo()
            for (p in pezzi) {
                val ex = MediaExtractor().apply { setDataSource(p.absolutePath) }
                try {
                    val t = (0 until ex.trackCount).first { ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)!!.startsWith("audio/") }
                    ex.selectTrack(t)
                    val formato = ex.getTrackFormat(t)
                    if (traccia < 0) {
                        traccia = muxer.addTrack(formato)
                        muxer.start()
                    }
                    // Un fotogramma AAC: 1024 campioni. Il pezzo dopo comincia dove finisce l'ultimo.
                    val fotogramma = 1024L * 1_000_000 / formato.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    var ultimo = -fotogramma
                    while (true) {
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0) break
                        info.set(0, n, spostamento + ex.sampleTime, MediaCodec.BUFFER_FLAG_KEY_FRAME)
                        muxer.writeSampleData(traccia, buf, info)
                        ultimo = ex.sampleTime
                        ex.advance()
                    }
                    spostamento += ultimo + fotogramma
                } finally {
                    ex.release()
                }
            }
            muxer.stop()
        } finally {
            runCatching { muxer.release() }
        }
        true
    }.getOrDefault(false)
}
