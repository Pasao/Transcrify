# 🎙️ Transcrify

Transcrify è un'applicazione Android innovativa progettata per convertire rapidamente messaggi vocali in testo chiaro e leggibile, sfruttando la potenza delle API di Groq con modelli AI gratuiti. L'app si integra perfettamente nella quotidianità come un **overlay fluttuante sempre disponibile**, permettendoti di registrare audio, trascriverlo automaticamente e copiarlo negli appunti in modo semplice e immediato.


## ✨ Funzionalità principali

*   **Trascrizione AI Rapida e precisa:** Utilizza le API di Groq per trascrivere messaggi vocali in testo, garantendo velocità, precisione e punteggiatura.
*   **Overlay Fluttuante:** Avvia e gestisci le registrazioni e le trascrizioni direttamente da un'interfaccia compatta e sempre accessibile.
*   **Copia Veloce:** Trascrizione automatica copiata negli appunti di sistema per un utilizzo istantaneo in qualsiasi app.
*   **Ricopia Ultima Trascrizione:** Un pulsante dedicato per ricopiare facilmente l'ultima trascrizione nel caso non fosse più disponibile.
*   **Rifinimento Trascrizione:** Funzionalità in sviluppo per migliorare punteggiatura e leggibilità del testo trascritto.



## 🎯 Perché Transcrify?

Molti smartphone, specialmente quelli più datati o con sistemi operativi non aggiornati, non dispongono ancora di funzionalità integrate di trascrizione vocale potenziate dall’intelligenza artificiale, in particolare per la lingua italiana.

**L’obiettivo di Transcrify** è colmare questa lacuna, portando l'AI per la trascrizione vocale a un pubblico più ampio. L'idea è offrire uno strumento semplice ed efficace per convertire rapidamente i propri pensieri e le comunicazioni vocali in testo chiaro, leggibile e facilmente utilizzabile in qualsiasi contesto digitale.

Parlare è generalmente più veloce che scrivere a mano o con la tastiera. Transcrify mira a far **risparmiare tempo e a rendere la comunicazione più fluida** attraverso la trascrizione vocale veloce. Inoltre, l'app è progettata per migliorare la qualità del testo trascritto, aggiustando punteggiatura e struttura, aspetti spesso trascurati da altre soluzioni.

Questa applicazione vuole quindi facilitare la scrittura, migliorare la comunicazione scritta e portare tecnologia AI accessibile e gratuita a dispositivi che non ne sono ancora dotati.


## 📱 Sistema supportato

Transcrify è sviluppata come applicazione Android nativa.

*   **Compatibilità:** Funziona su dispositivi con **Android 13 (API level 34) o superiori**.
*   **Test:** È stata testata con successo su un Samsung A53 5G con Android 13.

Le specifiche tecniche rilevanti sono definite nel `build.gradle.kts` del modulo `app`:

```gradle
android {
    namespace = "com.test.transcrify"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.test.transcrify"
        minSdk = 34
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }
}
```

## 🚀 Come installare e usare

1.  **Clona questa repository:**
    ```bash
    git clone https://github.com/Pasao/Transcrify.git
    ```
2.  **Apri il progetto con Android Studio.**
3.  **Costruisci e avvia l'app** sul tuo dispositivo o emulatore con Android 13 o superiore.
4.  **Ottieni la tua chiave API di Groq:** Registrati su [Groq Console](https://console.groq.com/keys) per ottenere la tua chiave API gratuita.
5.  **Inserisci la chiave API nell'app** per abilitare la trascrizione.
6.  **Usa l’overlay** per registrare audio e trascrivere in testo, che verrà copiato automaticamente negli appunti.

---


## 🧩 Dipendenze e Personalizzazioni

Questo progetto utilizza diverse librerie di terze parti per le sue funzionalità. In particolare, per la gestione dell'overlay fluttuante, è stata adottata e adattata una versione di una libreria esistente.

Ho basato l'implementazione sulla libreria originale [luiisca/floating-views](https://github.com/luiisca/floating-views).

La versione personalizzata e modificata, **[Pasao/floating-views-tify](https://github.com/Pasao/floating-views-tify)**, è stata sviluppata per soddisfare specifiche esigenze del progetto Transcrify. Questo fork include ottimizzazioni e adattamenti mirati per garantire la piena compatibilità e le funzionalità richieste dall'applicazione.

## 🛠️ Tecnologie utilizzate

*   **Kotlin**
*   **Jetpack Compose** (per la UI)
*   **API di Groq** (per modelli LLM di trascrizione)


## ⚠️ Gestione dei limiti API di Groq

Le API di Groq offrono un piano gratuito con limiti giornalieri di utilizzo piuttosto ampi, e Transcrify è progettata per sfruttare questi limiti in modo da garantire un'esperienza utente principalmente gratuita.

Tuttavia, anche se l’app tenta di bloccare l’utente dal superare i limiti, in certi casi ciò potrebbe ancora accadere, poiché non tutte le condizioni limite del servizio sono state testate a fondo.

Per questo motivo, è importante utilizzare l’app con consapevolezza e attenzione al consumo delle API. È in programma l’implementazione di una dashboard grafica che mostri chiaramente l’utilizzo delle API e i limiti residui, per evitare sorprese.



## 🤝 Come contribuire

Se desideri contribuire a Transcrify, migliorarlo o risolvere eventuali bug, sei il benvenuto!

*   Puoi fare un **fork della repository**.
*   Proponi **pull request** con le tue modifiche.
*   Segnala problemi o suggerisci nuove funzionalità tramite la sezione **Issues**.

Il progetto è **open source** e aperto a collaborazioni.



## 📋 To-do list (Prossimi sviluppi)
*   [ ] Permettere di creare automaticamente la chiave Groq senza doverlo fare manualmente all'utente.
*   [ ] Implementare la possibilità di rifinire la trascrizione usando prompt personalizzati in-app.
*   [ ] Creare una versione stabile con APK firmato e caricarla nelle [GitHub Releases](https://github.com/Pasao/transcrify_clean_final/releases).
*   [ ] Aggiungere una dashboard grafica per il monitoraggio dei limiti API all'interno dell'app.
*   [ ] Migliorare l’UI/UX dell’overlay e la gestione degli errori API.
*   [ ] Implementare una sezione dedicata all’archivio delle note trascritte, per conservare e consultare tutte le trascrizioni effettuate (al momento è disponibile solo il pulsante per copiare l’ultima trascrizione).



---

Grazie per aver esplorato Transcrify! Se hai domande o suggerimenti, non esitare a contattarmi.
