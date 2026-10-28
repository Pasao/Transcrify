package com.pasao.transcrify.engine

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.io.File
import java.io.FileOutputStream

/**
 * Il senso delle frasi già capite, su disco: così dopo un riavvio non si chiede di nuovo al modello.
 *
 * Un file solo per modello, a righe fisse: impronta (16 byte), scala (4), vettore in 8 bit (dim byte).
 * Si scrive solo in coda; si legge tutto all'avvio del motore. 10 000 frasi con Gemma ≈ 2,7 MB.
 */
class SentenceStore(private val file: File, private val dim: Int) {
    fun load(): HashMap<Fingerprint, Int8Vec> {
        val out = HashMap<Fingerprint, Int8Vec>()
        if (!file.exists()) return out
        DataInputStream(file.inputStream().buffered()).use { input ->
            val fp = ByteArray(16)
            while (true) {
                try {
                    input.readFully(fp)
                    val scale = input.readFloat()
                    val q = ByteArray(dim)
                    input.readFully(q)
                    out[Fingerprint.fromBytes(fp)] = Int8Vec(q, scale)
                } catch (_: EOFException) {
                    // Una riga a metà (l'app chiusa mentre scriveva) si ignora: quella frase si ricalcola.
                    break
                }
            }
        }
        return out
    }

    fun append(learned: Map<Fingerprint, Int8Vec>) {
        if (learned.isEmpty()) return
        file.parentFile?.mkdirs()
        DataOutputStream(FileOutputStream(file, true).buffered()).use { out ->
            for ((fp, v) in learned) {
                out.write(fp.toBytes())
                out.writeFloat(v.scale)
                out.write(v.q)
            }
        }
    }
}
