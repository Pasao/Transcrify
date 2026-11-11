package com.pasao.transcrify

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * Le regole dei titoli (7 nov, sua idea: «titoli dall'LLM, generati una volta, rinominabili»), senza Android: si provano.
 *
 * Un titolo si chiede una volta sola: a una trascrizione che non ne ha e che non l'hai toccato tu
 * ([Transcription.titoloChiesto]). Anche alle private (7 nov sera: «i titoli delle cose private restano, aiutano a
 * orientarsi»). Dalla più recente.
 *
 * 7 nov sera, «Groq si è fermato a 40»: il modello (gpt-oss) ragiona prima di rispondere, e col tetto di 600 token
 * molte risposte arrivavano tagliate; ogni risposta tagliata (o vuota) segnava la trascrizione come «chiesta», per
 * sempre e senza titolo: in pochi minuti tutte le altre erano «finite». Ora un errore così la salta solo per questo giro
 * (si riprova riaprendo l'app), il ragionamento è corto e il tetto più largo.
 */
object TitoliRegole {
    /** Tra una richiesta e l'altra: le trascrizioni di prima si recuperano piano, senza mangiarsi i limiti di Groq. */
    const val RITMO = 4_000L

    /** Groq ha detto «basta» (429), non risponde, o manca la rete: si riprova dopo questo. */
    const val PAUSA_LIMITE = 10 * 60_000L

    /** Quanto del testo va a Groq: l'inizio e un poco della fine (dove spesso si dice di cosa si trattava). */
    const val INIZIO = 1500
    const val FINE = 300

    fun daFare(t: Transcription) = t.titolo == null && !t.titoloChiesto && t.text.isNotBlank()

    /**
     * La prossima da fare: prima le private (10 nov: la loro scheda mostra solo il titolo, e senza resta un segnaposto),
     * poi dalla più recente; [saltate]: quelle andate male in questo giro.
     */
    fun prossima(storia: List<Transcription>, saltate: Set<Long> = emptySet()): Transcription? =
        storia.filter { daFare(it) && it.at !in saltate }.maxWithOrNull(compareBy<Transcription> { it.privata }.thenBy { it.at })

    /** Il testo da mandare: tutto se è corto; se no l'inizio, «…», e la fine. */
    fun perTitolo(testo: String): String {
        val t = testo.trim()
        return if (t.length <= INIZIO + FINE) t else t.take(INIZIO).trimEnd() + "\n…\n" + t.takeLast(FINE).trimStart()
    }

    /** Com'è andata una richiesta. */
    sealed interface Esito {
        data class Fatto(val titolo: String) : Esito
        data class Errore(val e: GroqError) : Esito
    }

    /**
     * Cosa fare dopo: [segna] la trascrizione come chiesta (non si richiede più); [salta] lasciarla per questo giro;
     * [tra] quando la prossima (null = ci si ferma: si riparte alla prossima trascrizione o riaprendo l'app).
     */
    data class Passo(val segna: Boolean, val tra: Long?, val salta: Boolean = false)

    fun dopo(esito: Esito): Passo = when (esito) {
        is Esito.Fatto -> Passo(segna = true, tra = RITMO)
        is Esito.Errore -> when {
            // Senza chiave buona: ci si ferma.
            esito.e.codice == 401 -> Passo(segna = false, tra = null)
            // Senza rete, il limite (429), un errore suo (5xx): si riprova più avanti, senza segnarla.
            esito.e.offline || esito.e.codice == 429 || esito.e.codice >= 500 -> Passo(segna = false, tra = PAUSA_LIMITE)
            // Risposta vuota o tagliata: per questo giro si passa alla prossima, senza segnarla.
            else -> Passo(segna = false, tra = RITMO, salta = true)
        }
    }

    /**
     * C'è la rete? [leggi] chiede ad Android: false = sicuramente no. Se Android non sa dirlo (null) o si rifiuta
     * (10 nov, «connectivity service neither user…»: un SecurityException senza il permesso) non si sa: si prova lo
     * stesso, e se manca davvero lo dirà Groq. Non si ferma mai qui.
     */
    fun inRete(leggi: () -> Boolean?): Boolean = try {
        leggi() ?: true
    } catch (e: Exception) {
        true
    }

    /** Quante hanno il titolo, su quante possono averlo (non vuote): per la riga nelle Prove. */
    fun conta(storia: List<Transcription>): Pair<Int, Int> {
        val possibili = storia.filter { it.text.isNotBlank() }
        return possibili.count { it.titolo != null } to possibili.size
    }

    /** Perché si è fermato dopo un errore (null = non si ferma, va avanti), detto in breve per le Prove. */
    fun motivo(e: GroqError): String? = when {
        e.offline -> "senza rete, riprova tra 10 minuti"
        e.codice == 401 -> "chiave non valida"
        e.codice == 429 -> "limite di Groq, riprova tra 10 minuti"
        e.codice >= 500 -> "Groq non risponde, riprova tra 10 minuti"
        else -> null
    }

    /**
     * Il titolo nella trascrizione, se nel frattempo nessuno l'ha cambiata: un titolo tuo non si tocca, e se il testo
     * non è più [testo] (l'hai modificata, unita…) il titolo era di un altro testo e non si scrive.
     */
    fun scrivi(t: Transcription, titolo: String?, testo: String): Transcription =
        if (!daFare(t) || t.text != testo) t else t.copy(titolo = titolo?.ifBlank { null }, titoloChiesto = true)

    /** «Rifai i titoli»: via quello di Groq (chiesto, non tuo), da richiedere. I tuoi restano. */
    fun rifai(t: Transcription): Transcription =
        if (t.titoloChiesto && !t.titoloUtente) t.copy(titolo = null, titoloChiesto = false) else t
}

/**
 * Chiede a Groq i titoli delle trascrizioni, in fondo, una alla volta: subito dopo una nuova (il testo è già stato copiato:
 * questo non lo fa aspettare), e piano piano quelle di prima, dalla più recente ([TitoliRegole]). Con la rete e la chiave.
 */
class Titolatore private constructor(context: Context) {
    private val app = context.applicationContext
    private val store = Store(app)
    private val exec = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "titoli").apply { priority = Thread.MIN_PRIORITY } }
    private var prossimo: ScheduledFuture<*>? = null

    /** Andate male in questo giro (risposta vuota o tagliata): si riprovano riaprendo l'app. */
    private val saltate = mutableSetOf<Long>()

    /** Cosa sta facendo, per le Prove: «in corso», «finiti» o «in pausa (motivo)». */
    @Volatile var stato = "fermo"
        private set

    /** «Titoli: N fatti su M · stato», la riga nelle Prove (si vede se lavora). */
    fun riepilogo(): String {
        val (fatti, tutte) = TitoliRegole.conta(store.history())
        return "Titoli: $fatti fatti su $tutte · $stato"
    }

    /** Chi vuole sapere quando un titolo è arrivato (l'app, per rileggere). */
    @Volatile var listener: (() -> Unit)? = null

    /**
     * Si (ri)comincia: una trascrizione nuova, l'avvio o il ritorno nell'app. Se c'è già un giro in attesa (anche la
     * pausa del 429) si aspetta quello; se no le saltate si riprovano.
     */
    fun avvia() = exec.execute {
        if (prossimo?.isDone == false) return@execute
        saltate.clear()
        prossimo = exec.schedule(::giro, 0, TimeUnit.MILLISECONDS)
    }

    /** «Rifai i titoli»: quelli di Groq tornano da fare (i tuoi restano) e si riparte subito, anche da una pausa. Quanti. */
    fun rifai(): Int {
        var quanti = 0
        store.cambia(store.history().map { it.at }.toSet()) { t -> TitoliRegole.rifai(t).also { if (it !== t) quanti++ } }
        exec.execute {
            prossimo?.cancel(false)
            saltate.clear()
            prossimo = exec.schedule(::giro, 0, TimeUnit.MILLISECONDS)
        }
        listener?.invoke()
        return quanti
    }

    /** Un passo, e il prossimo in fila: anche se qui qualcosa va storto (il file, la rete) il giro non muore zitto. */
    private fun giro() {
        val tra = try {
            passo()
        } catch (e: Exception) {
            stato = "in pausa (errore: ${e.message?.take(40) ?: e.javaClass.simpleName}, riprova tra 10 minuti)"
            TitoliRegole.PAUSA_LIMITE
        }
        tra?.let { prossimo = exec.schedule(::giro, it, TimeUnit.MILLISECONDS) }
    }

    /** Una trascrizione: chiede e scrive. Dice tra quanto la prossima (null = ci si ferma). */
    private fun passo(): Long? {
        val key = store.apiKey ?: return null.also { stato = "in pausa (senza chiave)" }
        if (!inRete()) return TitoliRegole.PAUSA_LIMITE.also { stato = "in pausa (senza rete, riprova tra 10 minuti)" }
        val t = TitoliRegole.prossima(store.history(), saltate)
            ?: return null.also { stato = if (saltate.isEmpty()) "finiti" else "finiti (${saltate.size} da riprovare riaprendo l'app)" }
        stato = "in corso"
        val esito = try {
            TitoliRegole.Esito.Fatto(Groq(key).title(TitoliRegole.perTitolo(t.text), store.cleanupModel).also { store.countUse(store.cleanupModel) })
        } catch (e: GroqError) {
            TitoliRegole.Esito.Errore(e)
        } catch (e: Exception) {
            TitoliRegole.Esito.Errore(GroqError(e.message ?: "Errore"))
        }
        val passo = TitoliRegole.dopo(esito)
        if (esito is TitoliRegole.Esito.Errore) TitoliRegole.motivo(esito.e)?.let { stato = "in pausa ($it)" }
        if (passo.salta) saltate += t.at
        if (passo.segna) {
            // Sulla sua trascrizione (il suo «at»), e solo se il testo è ancora quello mandato.
            store.cambia(setOf(t.at)) { TitoliRegole.scrivi(it, (esito as? TitoliRegole.Esito.Fatto)?.titolo, t.text) }
            if (esito is TitoliRegole.Esito.Fatto) listener?.invoke()
        }
        return passo.tra
    }

    private fun inRete(): Boolean = TitoliRegole.inRete {
        val cm = app.getSystemService(ConnectivityManager::class.java) ?: return@inRete null
        cm.getNetworkCapabilities(cm.activeNetwork)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
    }

    companion object {
        @Volatile private var instance: Titolatore? = null

        fun get(context: Context): Titolatore =
            instance ?: synchronized(this) { instance ?: Titolatore(context).also { instance = it } }
    }
}
