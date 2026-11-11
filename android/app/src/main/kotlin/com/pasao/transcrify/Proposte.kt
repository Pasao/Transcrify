package com.pasao.transcrify

/** Un'etichetta proposta da Groq: il nome e la regola (di cosa parlano le sue trascrizioni). */
data class Proposta(val nome: String, val regola: String) {
    fun toMap(): Map<String, String> = mapOf("nome" to nome, "regola" to regola)
}

/**
 * «Proponi etichette» e la regola di un'etichetta nuova (10 nov, sua richiesta), senza Android: si provano con un Groq
 * finto. A Groq vanno solo i TITOLI delle trascrizioni, mai i testi; una risposta tagliata non si accetta
 * ([Risposta.primaIntera]).
 */
object Proposte {
    /** Quanti titoli al massimo (i più recenti): bastano per capire di cosa parli, e la richiesta resta corta. */
    const val TITOLI = 300

    /** Quante etichette può proporre: meno di [MINIMO] non serve, più di [MASSIMO] non sta nella rosa con calma. */
    const val MINIMO = 4
    const val MASSIMO = 8

    /** Quanto è lunga al massimo una regola: poche parole, come quelle che scriveresti tu. */
    const val REGOLA = 120

    const val PROMPT_ETICHETTE = "Questi sono i titoli delle mie trascrizioni, uno per riga. Proponi da $MINIMO a $MASSIMO " +
        "etichette per raggrupparle: per ognuna un nome corto (una o due parole) e, dopo i due punti, una regola di poche " +
        "parole che dice di cosa parlano, separate da virgole. Una per riga, così: «relazioni: amore, dolore, sentimenti, " +
        "emozioni». Nella lingua dei titoli. Rispondi solo con le righe, senza numeri, elenchi o altro."

    const val PROMPT_REGOLE = "Questi sono i titoli delle mie trascrizioni, uno per riga, e dopo «Etichette:» le etichette " +
        "che uso, ognuna con la sua regola di adesso dopo i due punti (di cosa parlano le trascrizioni che ci vanno). Per " +
        "OGNI etichetta scrivi una regola migliore, che si adatti ai titoli: da tre a sei parole o temi separati da " +
        "virgole. Una per riga, così: «nome: regola», con il nome identico. Nella lingua dei titoli. Rispondi solo con le righe."

    const val PROMPT_REGOLA = "Questo è il nome di un'etichetta per le mie trascrizioni. Scrivi in una riga di cosa parlano " +
        "le trascrizioni che ci vanno: da tre a sei parole o temi, separati da virgole (per «relazioni»: «amore, dolore, " +
        "sentimenti, emozioni»). Nella lingua del nome. Rispondi solo con la riga."

    /**
     * I titoli da mandare: non vuoti, una volta sola, i primi [TITOLI] (la storia arriva dalla più recente). Con
     * [esistenti] (10 nov, suo: «che non doppi quelle che ho») Groq sa anche i nomi che hai già.
     */
    fun perGroq(titoli: List<String>, esistenti: Collection<String> = emptyList()): String {
        val righe = titoli.map { it.trim() }.filter { it.isNotEmpty() }.distinctBy { it.lowercase() }.take(TITOLI).joinToString("\n")
        val gia = esistenti.map { it.trim() }.filter { it.isNotEmpty() }
        return if (gia.isEmpty()) righe else "$righe\n\nEtichette che ho già, da non riproporre: ${gia.joinToString(", ")}"
    }

    /** «Proponi regole» (10 nov): i titoli e, dopo «Etichette:», ogni etichetta [regole] (nome → regola di adesso). */
    fun perRegole(titoli: List<String>, regole: Map<String, String>): String =
        perGroq(titoli) + "\n\nEtichette:\n" + regole.entries.joinToString("\n") { (nome, regola) -> "${nome.trim()}: ${regola.trim()}" }

    /**
     * La risposta di «Proponi regole»: per ogni etichetta di [nomi] (senza guardare le maiuscole) la sua regola nuova,
     * col nome com'è tuo. Le righe di nomi che non hai si lasciano; la stessa una volta sola.
     */
    fun leggiRegole(risposta: String, nomi: Collection<String>): Map<String, String> {
        val tuoi = nomi.associateBy { it.trim().lowercase() }
        return leggi(risposta, massimo = nomi.size).mapNotNull { p -> tuoi[p.nome.lowercase()]?.let { it to p.regola } }.toMap()
    }

    /**
     * La risposta in etichette: righe «nome: regola» (via numeri, trattini, virgolette, grassetti). Un nome una volta
     * sola (senza guardare le maiuscole), al massimo [massimo]; [esistenti]: i nomi che hai già, che non si ripropongono.
     */
    fun leggi(risposta: String, esistenti: Collection<String> = emptyList(), massimo: Int = MASSIMO): List<Proposta> {
        val gia = esistenti.map { it.trim().lowercase() }.toMutableSet()
        return risposta.lineSequence().mapNotNull { riga ->
            val pulita = riga.trim().replace(Regex("""^(\d+[.)]|[-*•])\s*"""), "").replace("*", "").trim()
            val due = pulita.indexOf(':').takeIf { it > 0 } ?: return@mapNotNull null
            val nome = pulisci(pulita.take(due)).take(30).trim()
            val regola = pulisci(pulita.drop(due + 1)).take(REGOLA).trim()
            if (nome.isEmpty() || regola.isEmpty() || !gia.add(nome.lowercase())) null
            else Proposta(nome.replaceFirstChar { it.uppercase() }, regola)
        }.take(massimo).toList()
    }

    /** La regola dalla risposta: la prima riga, senza «Regola:», virgolette e punto in fondo, al massimo [REGOLA]. */
    fun regola(risposta: String): String {
        val riga = risposta.lineSequence().map { it.trim() }.firstOrNull { it.isNotEmpty() }.orEmpty()
        return pulisci(riga.replace(Regex("""^(?i)regola\s*:\s*"""), "")).take(REGOLA).trim()
    }

    private fun pulisci(s: String) = s.trim().trim('"', '\'', '«', '»', '“', '”', '.', ' ')

    /**
     * La regola che Groq ha proposto per un'etichetta nuova si scrive solo se nel frattempo non ne hai scritta una tu
     * e il nome è ancora quello: torna la regola da salvare, o null se non va toccata.
     */
    fun daSalvare(proposta: String, scritta: RegolaColore?, nomeChiesto: String, nomeAdesso: String?): RegolaColore? =
        if (proposta.isBlank() || !scritta?.regola.isNullOrBlank() || nomeAdesso?.trim() != nomeChiesto.trim()) null
        else (scritta ?: RegolaColore()).copy(regola = proposta.trim())
}
