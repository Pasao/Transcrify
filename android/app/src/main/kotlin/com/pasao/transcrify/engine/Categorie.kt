package com.pasao.transcrify.engine

/**
 * Le categorie fisse, come quelle della galleria («cani», «spiagge»): un nome che si capisce subito
 * e una descrizione che il modello legge per sapere cosa ci va dentro. Ogni pezzo di nota finisce
 * in quella che gli somiglia di più, se le somiglia abbastanza; gli altri restano fuori.
 */
data class Categoria(val nome: String, val descrizione: String)

object Categorie {
    val tutte = listOf(
        Categoria("Lavoro", "lavoro, colleghi, clienti, riunioni, colloqui, carriera, ufficio"),
        Categoria("Studio", "studio, università, esami, corsi, lezioni, imparare"),
        Categoria("Idee e progetti", "idee, progetti, cose da costruire, piani, prossimi passi"),
        Categoria("Design", "design, interfaccia, grafica, colori, layout, Figma, portfolio"),
        Categoria("App e tecnologia", "app, telefono, computer, codice, programmare, bug, funzioni"),
        Categoria("Soldi", "soldi, spese, pagamenti, stipendio, risparmi, conti, prezzi"),
        Categoria("Salute", "salute, medico, dentista, medicine, sintomi, dormire, stare male"),
        Categoria("Sport e corpo", "sport, palestra, allenamento, corsa, camminare, peso"),
        Categoria("Cibo", "cibo, ricette, cucinare, mangiare, ristorante, spesa al supermercato"),
        Categoria("Casa", "casa, pulizie, affitto, mobili, traslochi, cose da aggiustare"),
        Categoria("Viaggi", "viaggi, treno, aereo, vacanze, prenotazioni, spostamenti"),
        Categoria("Famiglia", "famiglia, genitori, mamma, papà, fratelli, parenti"),
        Categoria("Amici", "amici, uscire, serate, feste, vedersi con qualcuno"),
        Categoria("Amore", "amore, relazione, partner, sentimenti per una persona, lasciarsi"),
        Categoria("Come mi sento", "emozioni, umore, pensieri personali, ansia, felicità, riflessioni su di me"),
        Categoria("Da fare", "cose da fare, promemoria, ricordarsi di, scadenze, appuntamenti"),
        Categoria("Musica, film e libri", "musica, canzoni, film, serie, libri, giochi"),
        Categoria("Pratiche", "burocrazia, documenti, moduli, uffici pubblici, banca, tasse"),
    )

    /** Quello che il modello legge: nome e descrizione insieme. */
    fun testo(c: Categoria) = "${c.nome}: ${c.descrizione}"

    /**
     * L'indice della categoria più vicina a [pezzo] (lungo 1), o -1 se nessuna arriva a [minimo]
     * o se la prima e la seconda sono quasi pari (meno di [scarto]): meglio fuori che nel posto sbagliato.
     */
    fun di(pezzo: FloatArray, categorie: List<FloatArray>, minimo: Float, scarto: Float): Int {
        var primo = -1
        var p = -2f
        var s = -2f
        categorie.forEachIndexed { i, c ->
            val x = Vec.dot(pezzo, c)
            if (x > p) { s = p; p = x; primo = i } else if (x > s) s = x
        }
        return if (primo >= 0 && p >= minimo && p - s >= scarto) primo else -1
    }
}
