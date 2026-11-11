package com.pasao.transcrify

/** Una risposta del modello: il testo e perché si è fermato («stop»; «length» = il tetto l'ha tagliata). */
data class Risposta(val testo: String, val fine: String) {
    /** Finita da sé e non vuota: l'unica che si accetta. */
    val intera get() = fine != "length" && testo.isNotBlank()

    companion object {
        /**
         * La prima risposta intera, chiedendo coi [tetti] in fila (il primo, poi i più larghi): una tagliata non si
         * accetta mai; se nessuna è intera, «Risposta tagliata». Per le risposte corte (titoli, etichette, regole).
         */
        fun primaIntera(tetti: List<Int>, chiedi: (tetto: Int) -> Risposta): Risposta =
            tetti.asSequence().map(chiedi).firstOrNull { it.intera } ?: throw GroqError("Risposta tagliata")
    }
}

/**
 * Pulire senza tagliare mai (10 nov, sua richiesta: «un modello che ragiona e non finisce le cose, o non trascrive
 * tutto, è spazzatura»). Il testo va a pezzi tra una frase e l'altra ([pezzi]); ogni pezzo ha un tetto di token
 * proporzionale a quanto è lungo ([tetto]). Una risposta tagliata (o vuota) non si accetta mai:
 * 1. si richiede una volta col tetto doppio, al modello [riserva] se c'è (uno che non ragiona: il ragionamento non
 *    mangia il tetto), se no allo stesso;
 * 2. ancora tagliata: il pezzo si divide in due e si rifà ogni metà, fino a [DIVISIONI] volte;
 * 3. ultima strada: di quel pezzo restano le parole che hai detto, intere. Mai un testo a metà.
 * Senza Android né rete: [chiedi] (testo, modello, tetto) è la chiamata, e nelle prove è finta.
 */
class Pulitura(
    private val modello: String,
    private val riserva: String? = null,
    private val chiedi: (testo: String, modello: String, tetto: Int) -> Risposta,
) {
    /** [maxWer]: se il modello ha cambiato troppe parole di un pezzo, di quel pezzo si tiene l'originale. */
    fun pulisci(grezzo: String, maxWer: Double? = null): String =
        pezzi(grezzo, PEZZO).joinToString("\n\n") { pezzo(it, maxWer, 0) }

    private fun pezzo(prima: String, maxWer: Double?, divisioni: Int): String {
        val dopo = intera(prima) ?: return if (divisioni < DIVISIONI && prima.length > PEZZO_MINIMO) {
            pezzi(prima, prima.length / 2 + 1).joinToString("\n\n") { pezzo(it, maxWer, divisioni + 1) }
        } else {
            prima
        }
        return if (maxWer != null && WordGuard.wer(prima, dopo) > maxWer) prima else dopo
    }

    /** La risposta intera per [testo], o null se anche il secondo tentativo arriva tagliata. */
    private fun intera(testo: String): String? {
        chiedi(testo, modello, tetto(testo, modello)).takeIf { it.intera }?.let { return it.testo }
        val secondo = riserva ?: modello
        return chiedi(testo, secondo, (tetto(testo, secondo) * 2).coerceAtMost(TETTO_MASSIMO)).takeIf { it.intera }?.testo
    }

    companion object {
        /** Quanti caratteri si puliscono in una chiamata. */
        const val PEZZO = 8000

        /** Sotto questo un pezzo non si divide più: se il modello taglia anche lui, restano le parole dette. */
        const val PEZZO_MINIMO = 600

        /** Quante volte un pezzo tagliato si divide in due (8000 → 4000 → 2000 caratteri). */
        const val DIVISIONI = 2

        /** Caratteri per token, contati larghi (l'italiano ne ha meno dell'inglese). */
        private const val CARATTERI_PER_TOKEN = 3.5

        /** La risposta può essere più lunga del testo (punteggiatura, a capo): il 60% in più. */
        private const val MARGINE = 1.6

        /** Il ragionamento dei modelli che ragionano, già corto ([Groq.ragionamentoCorto]), conta nel tetto. */
        private const val RAGIONAMENTO = 2000
        private const val SENZA_RAGIONAMENTO = 300
        private const val TETTO_MINIMO = 512
        private const val TETTO_MASSIMO = 32_000

        /** Il tetto di token per pulire [testo] con [modello]: quanto è lungo × [MARGINE], più il ragionamento. */
        fun tetto(testo: String, modello: String): Int =
            ((testo.length / CARATTERI_PER_TOKEN) * MARGINE).toInt()
                .plus(if (ragiona(modello)) RAGIONAMENTO else SENZA_RAGIONAMENTO)
                .coerceIn(TETTO_MINIMO, TETTO_MASSIMO)

        /** I modelli che ragionano prima di rispondere (il ragionamento conta nel tetto). */
        fun ragiona(modello: String) = RAGIONANO.any { modello.contains(it) }
        private val RAGIONANO = listOf("gpt-oss", "qwen3", "deepseek-r1", "reasoning", "magistral")

        /**
         * Il modello di riserva per pulire, se quello scelto ragiona: il primo di [NON_RAGIONANO] che Groq offre
         * ([offerti], la lista dei modelli). Non ragiona, quindi tutto il tetto va al testo. Null se non serve o non c'è.
         */
        fun riserva(scelto: String, offerti: List<String>): String? =
            if (!ragiona(scelto)) null else NON_RAGIONANO.firstOrNull { it in offerti && it != scelto }

        /** Fedeli al testo, veloci, con risposte lunghe (Kimi K2 fino a 16k token, Llama 3.3 fino a 32k). */
        val NON_RAGIONANO = listOf("moonshotai/kimi-k2-instruct-0905", "moonshotai/kimi-k2-instruct", "llama-3.3-70b-versatile")

        /**
         * [testo] a pezzi di al massimo [tetto] caratteri, tagliati tra una frase e l'altra; una frase più lunga del
         * tetto, tra una parola e l'altra. Nessuna parola si perde e nessuna si spezza.
         */
        fun pezzi(testo: String, tetto: Int): List<String> {
            val fuori = mutableListOf(StringBuilder())
            fun metti(parte: String) {
                if (fuori.last().isNotEmpty() && fuori.last().length + parte.length > tetto) fuori += StringBuilder()
                fuori.last().append(parte).append(' ')
            }
            for (frase in testo.trim().split(Regex("""(?<=[.!?…])\s+"""))) {
                if (frase.length <= tetto) metti(frase) else frase.split(Regex("""\s+""")).forEach(::metti)
            }
            return fuori.map { it.toString().trim() }.filter { it.isNotEmpty() }
        }
    }
}
