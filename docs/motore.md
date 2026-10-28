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

## Ancora da fare

- Il modello sul telefono (ONNX Runtime), scaricato solo se attivi «Argomenti nelle note»: *Più preciso* (EmbeddingGemma) o *Più leggero* (multilingual-e5-small), col nome del modello scritto piccolo sotto.
- Salvare tutto su disco (SQLite: frasi per impronta, spazi per nota, pezzi, album) e la manutenzione con WorkManager quando è in carica.
- Tarare le soglie (`pair`, `split`, le grane) per ogni modello sulle note vere.
