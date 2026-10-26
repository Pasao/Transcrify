# Transcrify

Detti da qualunque app, e il testo è già negli appunti.

Transcri vive sul bordo del telefono come un assistente laterale. Lo tocchi, parli, tocchi di nuovo: la trascrizione è copiata e la incolli dove vuoi, in una chat, in una mail, nelle note. Niente vocali da ascoltare, a chi li riceve arriva il testo.

## Cosa fa

- **Transcri sul bordo**: esce dall'app (o dal widget sulla home) e si attacca al bordo dello schermo. Si trascina, si chiude trascinandolo sulla X in basso.
- **Tenerlo premuto** fa partire la registrazione senza aprirlo; tenerlo premuto di nuovo la ferma e la trascrive.
- **Tre modi di pulizia**: *Fedele* (parola per parola, con punteggiatura), *Pulita* (senza esitazioni e ripetizioni, con il tuo modo di parlare), *Riassunto* (solo i punti). Si scelgono anche mentre registri.
- **Vocabolario**: nomi e termini scritti come li vuoi tu.
- **Le registrazioni non si perdono**: se manca la rete restano salvate, e le trascrivi quando vuoi.
- **Trascrizioni divise per giorno**: tocchi per leggerle, tieni premuto per copiarle.

## Installazione

1. Scarica l'APK dall'ultima [release](../../releases).
2. Aprilo sul telefono e consenti l'installazione da questa fonte.
3. Segui l'introduzione: serve una chiave **Groq** gratuita (l'app ti porta a crearla e la trova da sola negli appunti).

Serve **Android 12** o successivo.

## Privacy

L'audio viene trascritto da [Groq](https://groq.com) (Whisper) e, se attivi la pulizia, il testo passa da un modello di Groq. La chiave resta cifrata sul telefono e parla solo con Groq. Trascrizioni e registrazioni restano sul telefono.

Il piano gratuito di Groq trascrive fino a 2 ore di audio all'ora e 8 al giorno: l'app mostra quanto ne hai usato.

## Com'è fatto

- **App** in Flutter (`lib/`): introduzione, trascrizioni, impostazioni.
- **Transcri** nativo in Kotlin con Jetpack Compose (`android/app/src/main/kotlin/`): un servizio in primo piano con finestre sopra le altre app, la registrazione, la coda delle registrazioni e il client Groq.
- **Widget** per la schermata home: Transcri esce dal widget e ci rientra.

Per compilarlo: `flutter build apk --release --split-per-abi`. La firma si legge da `android/key.properties`, che non è nel repo.

## Storia

La prima versione (2025) era un prototipo in Kotlin, nel ramo `v1`. Questa è la riscrittura del 2026.

## Licenza

GPL-3.0, come la prima versione (vedi `LICENSE`).
