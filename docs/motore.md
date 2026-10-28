# Il motore degli argomenti

Come Transcrify divide le note in argomenti e li raggruppa in album, senza pesare sul telefono.
Il codice sta in `android/app/src/main/kotlin/com/pasao/transcrify/engine/`, i test in `android/app/src/test/…/engine/EngineTest.kt`.

## L'idea in una riga

L'unica cosa cara è dare il senso a una frase (il modello). Si fa **una volta sola per frase**, la si ricorda per impronta, e tutto il resto è aritmetica lineare che si può rifare quando si vuole.

## Al salvataggio di una nota (il «commit»)

1. **Frasi** (`Sentences`): un passaggio sul testo, O(n). Regole per l'italiano (abbreviazioni, iniziali, elenchi); le frasi dettate senza punti si spezzano oltre 240 caratteri nella virgola o congiunzione più vicina.
2. **Impronte** (`Fingerprint`): 128 bit (due xxHash64). Frasi uguali, in qualunque nota, hanno la stessa impronta: il loro senso si calcola una volta.
3. **Senso** (`Embedder`): solo le frasi mai viste vanno al modello. Si salva in 8 bit (`Int8Vec`, 4× più piccolo, errore sul coseno ~0,01).
4. **Confini** (`Segmenter`, idea di TextTiling): coesione tra il blocco prima e il blocco dopo ogni spazio, con le somme prefisse (ogni spazio costa una sottrazione); profondità degli avvallamenti con le cime trovate in un passaggio per lato. O(n · dim): microsecondi, si rifà intero.
5. **Grane** (`Segmentation`): un byte per spazio tra frasi. I confini si accettano dal più profondo, saltando quelli che lascerebbero pezzi di una frase: l'ordine è uno solo, quindi la grana fine contiene sempre quella larga. Un albero in n−1 byte; il pizzico sceglie quanti confini prendere.
6. **Pezzi**: ogni pezzo (grana media) ha un id fatto dal suo contenuto. Se modifichi una frase, cambia solo il suo pezzo: negli album si toglie quello vecchio e si aggiunge quello nuovo, gli altri non si toccano.

Modificare una frase in una nota lunga = 1 frase al modello + 2 operazioni negli album.

## Gli album (`Topics`)

Ogni album è riassunto da N (quanti pezzi) e LS (la somma dei vettori), come in BIRCH. Dalle somme si ricava **esatta** la somiglianza media (average linkage):

| | formula |
|---|---|
| pezzo v ↔ album | v · LS / N |
| album ↔ album (tutte le coppie) | LSa · LSb / (Na · Nb) |
| coesione di un album | (\|LS\|² − N) / (N(N−1)) |

Una regola sola, «in media si somigliano almeno *pair*», per entrare, unire e spezzare: vale uguale per album di 1 pezzo e di 1000.

- **Aggiungere/togliere**: una somma o una sottrazione, O(dim), esatte in qualunque ordine.
- **Trovare l'album**: codici binari SimHash (256 bit = 32 byte) delle direzioni degli album; il codice di un album si aggiorna sommando le proiezioni dei pezzi (sono lineari), mai riproiettando.
- **Manutenzione** (a telefono in carica): ricontrolla i pezzi in bilico, unisce le coppie di album simili (dalla più simile), spezza quelli che non si somigliano più (k-means sferico, k = 2). L'ordine di arrivo delle note smette di contare.
- Un album si mostra da 3 pezzi: «ne hai parlato tre volte».

## Cercare

Primo setaccio sui codici binari (popcount dello XOR), poi il coseno vero sui pochi candidati in 8 bit. Più avanti: unito alla ricerca per parole (SQLite FTS) con Reciprocal Rank Fusion, e alle etichette nascoste.

## Quanto regge (misurato sul PC, nei test)

- 1 milione di codici da 256 bit, i 50 più vicini: **~4 ms**.
- 100 000 pezzi in 2000 argomenti: **0,03 ms per pezzo** aggiunto, manutenzione 120 ms, 2000 album ritrovati su 2000.
- Memoria per pezzo: 32 byte di codice + dim byte di vettore (256 con EmbeddingGemma ridotto) + qualche numero. Un milione di pezzi ≈ 300 MB su disco, 32 MB di codici in memoria per la ricerca.
- Oltre qualche milione: la scansione si divide in liste (IVF, √N liste) e se ne guardano poche; l'interfaccia di `HammingIndex` non cambia.

## Il modello sul telefono

`OnnxEmbedder` (ONNX Runtime 1.31.1 sulla CPU) con i file scaricati da `TopicModels`. Il testo diventa numeri col nostro tokenizer in Kotlin (`engine/tokenize/`), che legge il `tokenizer.json` di Hugging Face: Unigram per e5, BPE con ripiego sui byte per Gemma. Dà gli stessi id della libreria ufficiale su 8000 testi a caso e 72 scelti a mano (accenti, apostrofi, emoji, a-capo, «<mask>»…).

| | Più preciso (EmbeddingGemma 300M, 4 bit) | Più leggero (multilingual-e5-small, 8 bit) |
|---|---|---|
| prefisso | `task: sentence similarity \| query: ` | `query: ` |
| vettore | `sentence_embedding`, primi 256 numeri su 768 (Matryoshka) | media di `last_hidden_state` sui pezzi veri, 384 |
| a gruppi | sì, 16 frasi (stesso vettore che da sola) | no: quantizza al volo con una scala per tutto il gruppo |
| una frase, PC (Ryzen 5 9600X, 4 thread) | 12–17 ms (9–13 a gruppi) | 2–3 ms |
| una frase, Galaxy S25+ | ~27 ms (16 a gruppi) | ~8 ms |
| caricamento sul telefono | ~1,1 s | ~0,5 s |

Il prefisso di Gemma è quello che separa meglio gli argomenti nelle nostre note di prova: «clustering» schiaccia tutte le somiglianze tra 0,8 e 0,9 e separa meno.

ONNX Runtime porterebbe dati d'uso verso Microsoft e un avvio automatico a ogni apertura dell'app: sono tolti (manifest e `setTelemetry(false)`). R8 deve lasciare intatte le sue classi (`proguard-rules.pro`). Pesa: +34 MB nell'APK per arm64 (le librerie native stanno non compresse), +99 MB con le tre architetture che l'APK porta oggi.

## Le soglie per modello (`EngineProfile`)

Ogni modello ha la sua scala, quindi ogni `TopicModel` ha il suo profilo. Tarato da `CalibrationTest` su `calibrazione-note.txt` (10 note dettate, 82 frasi, 11 argomenti che tornano in note diverse):

| | Più preciso | Più leggero |
|---|---|---|
| pezzi dello stesso argomento / di argomenti diversi (mediana) | 0,81 / 0,72 | 0,94 / 0,92 |
| `depthScale` | 4 | 10 |
| grane `coarse` / `medium` / `fine` | 59 / 19 / 1 | 59 / 5 / 1 |
| confini alla grana media: precisione, richiamo | 0,65, 0,63 | 0,76, 0,67 |
| `pair` / `split` | 0,80 / 0,72 | 0,94 / 0,90 |
| album sui pezzi veri (ARI) | 0,55 | 0,58 |

Sono pochi dati: le curve dei confini sono piatte (la soglia conta poco, decidono `minLen` e la finestra) e il `pair` di e5 è stretto (0,93 e 0,95 vanno molto peggio). Da ritarare sulle note vere.

## Ancora da fare

- Salvare tutto su disco (SQLite: frasi per impronta, spazi per nota, pezzi, album) e la manutenzione con WorkManager quando è in carica.
- Ritarare i profili sulle note vere, con più note.
- Il peso di ONNX Runtime: un APK per architettura (o solo arm64), oppure una build ridotta ai soli operatori dei due modelli.
