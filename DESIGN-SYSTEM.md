# Il design system nel codice: a che punto siamo

Il riferimento è Figma: B2–B3 (token), B4 (atomi), B6 (molecole), B9 (Floater), B10 (schermate),
**C0 «Cosa fa e cosa cambia nel codice»** (una riga per pezzo). Questa lista segue C0 riga per riga:
ogni volta che un pezzo passa al design system si spunta qui, e il contatore scende.

## Come funziona

- **Una fonte sola per i colori: `Token.kt`.** Calcola i 28 token dal colore scelto nel telefono
  (`Seme.kt` lo legge dalle impostazioni) con lo stile Fidelity, lo stesso calcolo di Figma
  (`TokenTest` controlla i valori). La usano la pillola e il widget; l'app Flutter la riceve
  (`tokenChiaro` / `tokenScuro`) e la mette in `context.col` (`lib/ui/ds.dart`).
  `azioneFondo`/`suAzioneFondo` (2 nov sera, solo Kotlin per ora: il widget «Del telefono») = la tinta del telefono
  tenue e col tema; `azioneTenue` in Fidelity è il seme pari pari, cioè l'arancione di Transcri. In Figma B2 da aggiungere.
- **Il resto delle fondamenta** sta in `lib/ui/ds/` con i nomi di Figma: `Testo.*` (10 stili),
  `Spazio.s1…s10`, `Raggio.*`, `Misura.*`, `Durata.*`, `Curva.*`, `Ombra.*`.
- **Un file per responsabilità (SOLID).** Figma è il riferimento, ma il codice è organizzato da
  codice: ogni file fa una cosa, i pezzi grandi sono composti da quelli piccoli. `lib/ui/ds/` (colori, misure, testo), `lib/ui/atomi/` (un file per
  atomo), poi `lib/ui/molecole/` e così via. `ds.dart` e `atomi.dart` sono solo indici che li esportano.
  Ogni regola sta in un posto solo (es. lo stile dei bottoni: `Bottone.stile`, usato anche dal tema).
- **I nomi vecchi** (`Tokens`, `tk.muted`, …) non ci sono più (2 nov): in Flutter i colori passano
  solo da `context.col` (o `Colori.adesso` dove non c'è un context). I caratteri: `Testo.fontTitoli/fontTesto/fontMono`.
- **Eccezioni dichiarate:** una riga con `// ds:eccezione: motivo` non conta (il disegno di Transcri, la testata
  dell'introduzione, alcuni tempi di comportamento); `eccezioniFile` nel contatore esclude le durate del
  movimento di Transcri (`transcri.dart`, `PillUi.kt`). Ogni eccezione dice perché.
- **Le fonti nel Kotlin:** `Token.kt` (colori), `Caratteri.kt` (testi), `Forme.kt` (raggi), `Durate.kt` (tempi),
  copie dei valori di `lib/ui/ds/` (i due linguaggi non possono condividere il codice).
- **Quanto manca:** `dart run tool/ds_rimasti.dart` conta, file per file, i punti del codice dove
  un colore, un testo, un raggio, una durata o un'ombra è scritto a mano invece di usare un token
  (`--righe` per vedere dove). Non sono «colori diversi»: abbiamo 26 colori e restano quelli;
  sono i punti che ancora non dicono quale token usano (es. `Colors.white` scritto 22 volte).
  Il movimento di Transcri (volo, magnete, onda) è un'eccezione dichiarata: resta suo.

## Le regole

Sono in `CLAUDE.md` e le controlla `test/regole_test.dart` a ogni `flutter test`:
niente doppioni (ogni classe un nome solo), valori scritti a mano che possono solo scendere
(tetto in `test/regole_tetto.json`, i file nuovi a zero), niente blocchi di codice copiati nei
pezzi nuovi, solo nomi nuovi nei pezzi nuovi. I file si dividono per responsabilità (SOLID).

## Il contatore

| Data | colori | nomi vecchi | testi | raggi | durate | ombre |
|---|---|---|---|---|---|---|
| 2 nov, partenza (dopo le fondamenta) | 174 | 176 | 56 | 55 | 72 | 5 |
| 2 nov, dopo gli atomi (da qui `Colors.transparent` e `ds/` non contano) | 158 | 154 | 50 | 51 | 72 | 5 |
| 2 nov, dopo il Dock | 152 | 146 | 47 | 48 | 67 | 3 |
| 2 nov, dopo l'intestazione | 151 | 142 | 47 | 47 | 63 | 3 |
| 2 nov, dopo Trascrivi (giorni e schede) | 149 | 134 | 46 | 43 | 62 | 3 |
| 2 nov, dopo la barra della trascrizione | 149 | 131 | 46 | 42 | 62 | 3 |
| 2 nov, via il vecchio sistema dei colori (Tokens) | 119 | 0 | 41 | 38 | 62 | 3 |
| 2 nov, la pillola dai token (da qui `Palette.X` non conta: è una vista sui token) | 31 | 0 | 41 | 38 | 62 | 3 |
| 2 nov, stati del Floater + `Caratteri.kt` (i testi del Floater dai token) | 31 | 0 | 27 | 38 | 62 | 3 |
| 2 nov, stato vuoto unico, schede delle note, Argomenti a concetti | 31 | 0 | 27 | 25 | 62 | 3 |
| 2 nov, raggi, durate, testi, widget e tempi in token; eccezioni dichiarate | **0** | **0** | **0** | **0** | **0** | **0** |

## La lista (righe di C0)

Stato: ☐ da fare · ◐ in corso · ☑ fatto

### Fondamenta
- ☑ Colori: `Token.kt` fonte unica (app, pillola, widget)
- ☑ Caratteri, spazi, raggi, misure, ombre, movimento: definiti in `ds.dart` (da usare pezzo per pezzo)

### Atomi
- ☑ Bottone: `atomi/bottone.dart`; FilledButton/OutlinedButton/TextButton prendono lo stesso stile dal tema (Pieno / Tenue senza contorno / Testo)
- ☑ BottoneIcona: `atomi/bottone_icona.dart` (icona piccola sotto i 40: lo usano anche i ComandiVoce); RoundAction (ora nuda) e PowerBadge passano da lì, IconButton dal tema; nel Kotlin i tasti del Floater prendono i colori da Palette (token)
- ☑ Chip: `atomi/chip_stato.dart` («Dati finti»; StatusChip tolto)
- ☑ Interruttore e Campo: dal tema (suggerimento leggibile, contorno solo da attivo)
- ☑ Scheda: `atomi/scheda.dart`, la usano MiniCard, NoteCard, PezzoArgomento, Chiave trovata
- ☑ Cestino e Copia: colori dei token (armato = errore tenue, copiato = ✓ su successo tenue)
- ☑ Transcri e Nido: colori dai token (via le tre variabili globali e i campi doppi del nativo)
- ☑ Mirino: `atomi/mirino.dart`, GrainIcon ora lo disegna
- ☑ EtichettaGruppo: `atomi/etichetta_gruppo.dart`, usata dai gruppi delle impostazioni
- ☑ IconaModo, IconaFonte: colori dai token
- ☑ Anteprima: `atomi/anteprima.dart`, l'inizio del testo su una scheda (righe e «…»); a Flutter arriva solo l'inizio, non la dettatura intera. La usano la scheda di Trascrivi e SchedaNota

### Il Dock e i poteri
- ☑ Dock: `dock.dart` compone `molecole/` (isola, medaglione, pillola_pagine, rientra); `potere.dart` a parte.
  Tolti i doppioni `islandColor`, `islandShadow`, `dockIsland`, `dockRound` (erano i token isola, Ombra.appoggiato, Misura.isola/tondo).
- ☑ Cambio potere (sua scelta nel codice, 2 nov): TRASCINI SU il medaglione (64, come le isole) = ti segue,
  sopra compare il nome di chi arriva (`molecole/nome_potere.dart`), superata la soglia passa al prossimo;
  TOCCO = sale la colonna. Figma (B6, S09, C0) aggiornato uguale.
- ☑ ColonnaPoteri: `molecole/colonna_poteri.dart`, si apre col tocco, tocchi il potere
- ☑ Provato sul telefono coi dati finti (tema scuro): trascina, nome, colonna. Trovato e corretto: al buio
  l'isola era più scura della pagina (sembrava un buco) → in `Token.kt` di notte `surfaceContainerHighest`
  (#3C3331 sul salmone; `TokenTest` lo controlla); anche il calcolo di Figma e le variabili di B2.
- ☑ Medaglione e pagina scelta, due salmoni vicini: gli va bene («sembra colorarsi»)

### Le pagine
- ☑ Intestazione: `molecole/intestazione.dart` (titolo 28 → 22 scorrendo, azioni al bordo), `molecole/riga_in_attesa.dart` (riga con Riprova; ridotta «⏱ n»). Provata sul telefono; test di overflow grande/ridotta.
- ☑ Tolti StatusChip, StatusSheet e `status.dart`: chiave mancante → la chiede Transcri; minuti finiti → tocco su Transcri che dorme apre l'Utilizzo.
- ☑ Buttare una registrazione in attesa (sua richiesta): toccando la riga si apre `molecole/foglio_in_attesa.dart` (giorno, ora, durata, cestino; «Riprova tutte»). Riprovarne una sola: il nativo non lo sa fare (solo tutte).
- ☑ Trascrivi: `molecole/titolo_giorno.dart` (22) ☑; carosello con `Scheda.fondo/forma` ☑; data che scorre = `atomi/etichetta_sospesa.dart` (lo stesso del nome del potere: un atomo solo) ☑ (sul telefono non sono riuscito a prendere la barretta: da guardare); stato vuoto: StatoVuoto ☑
- ☑ Barra della trascrizione: `molecole/voce_in_barra.dart` (a riposo il microfono + «Aggiungi a voce», sua scelta; il dettato entra al cursore; dettando i `molecole/comandi_voce.dart` piccoli: butta, ✓, pausa/riprendi, col tempo / «in pausa» / «trascrivo…»). Il nativo ora manda `paused` e `seconds`, e sa `togglePause` dall'app. Il pannello del Floater non si apre più sopra (i comandi sono nella barra). Provata a riposo sul telefono; gli stati mentre detta nel test di overflow.
- ☑ Foglio della trascrizione: colori, testi e raggi dai token
- ☑ Selezione e Annulla: fondo «floater», testo «suFloater», Elimina in errore tenue; Annulla 2 s (sua scelta, `Durata.annulla`, anche in Figma)
- ☑ Pensieri: colori dai token; selettore ed etichetta della grana sul fondo «floater» (`EtichettaSospesa`); i 6 colori degli argomenti = token `argomenti` (via la lista a parte) ☑; SchedaNota con la Scheda ☑
- ☑ Nota aperta: Mirino, selettore della grana sul fondo «floater», etichetta della grana = EtichettaSospesa
- ☑ Argomenti a due livelli: il motore raggruppa gli album che si somigliano (`Topics.concetti`, test `conceptsGroupEveryShownAlbumOnce`) e manda `concetto` a ogni album; `molecole/scheda_argomento.dart` (concetto col suo colore, mosaico: il più parlato grande, gli altri piccoli; tessere che crescono col testo, test di overflow); `molecole/pezzo_argomento.dart` (riassunto dei pezzi lunghi con Groq, «Originale»; i corti interi; riassunti tenuti in memoria finché l'app è aperta). Da vedere sul telefono.
- ☑ Liste fluide (3 nov): Trascrivi e Pensieri costruiscono solo quello che si vede (Trascrivi una lista al contrario, un giorno per riga; Pensieri due colonne pigre, `Masonry` è uno sliver); rileggendo dal nativo si ridisegna solo se qualcosa è cambiato (`==` su Entry, Note, Album); il rosso del cestino tenuto premuto è sopra la scheda, non più un filtro di colore; le letture delle liste nel Kotlin sono fuori dal thread principale. Misure: `test/fluido_test.dart`
- ☑ Stati vuoti: `molecole/stato_vuoto.dart`, uno solo per Trascrivi, Pensieri, Argomenti
- ☑ Impostazioni: colori, testi, raggi dai token; le etichette dei gruppi usano EtichettaGruppo (erano due copie)
- ☑ Chiave trovata: scheda neutra (Scheda), verde solo la spunta, bottone Pieno. ◐ Introduzione: la testata coi colori di Transcri è un'eccezione dichiarata

### Fuori dall'app
- ☑ Floater, colori: `Palette` (PillUi.kt) è solo la mappa token → ruoli della pillola, nessun colore scritto; usa sempre i token del tema SCURO (il pannello è sempre scuro). Provato: esce, torna a casa.
- ☑ Floater · stati (B9): pausa (grigia, «in pausa» in alto: c'era già), Lavora col tasto coi suoi colori (non più la rotella), «Minuti finiti» scritto sotto l'orologio. Testi da `Caratteri.kt` (gli stili di testo per il Kotlin).
- ☑ Scheda del vocale: in alto titolo + «rimpicciolisci»; il testo scorre con la sfumatura; in fondo solo icone (nei Pensieri, cestino). Via la X.
- ☑ Vocale da parte: «rimpicciolisci» lo mette da parte (`PillService.daParte`), la pillola mostra la rientranza con l'iconcina; il pannello compatto si allarga e in cima ha la riga (onda, titolo, ⤢ riapre, X toglie); resta fuori finché c'è. **Da provare dal vivo** (serve un vocale condiviso).
- ☑ CasaInBasso: colori dai token (Palette)
- ☑ Widget: «Richiama»; colori da `WidgetColori.kt` (dai token, gli stessi per widget e anteprima): la pillola colorata col fondo (a tinta unita: il launcher non colora un gradiente da codice), Transcri disegnato coi suoi due toni. Via gli sfondi a gradiente fissi. **Da vedere sulla Home.**

## Il suo giro del 2 novembre (sera) e cosa è cambiato
- Selettore della grana: la riga scelta si colora per intero; la grana è quella della riga sotto il dito
  (posizione assoluta, `_slide(Offset)`), non quanto lo sposti: si sale e si scende liberamente.
- Dettato in una trascrizione aperta: entrava in fondo perché Flutter cancella il cursore quando la tastiera
  si chiude. Ora l'ultimo punto valido è ricordato (`_cursore`) e usato.
- Vocale: via l'iconcina sulla pillola (non serve sapere che c'è: si apre e si vede). Nella scheda del vocale,
  in fondo, i comandi del Floater (`ComandiPannello`, lo stesso pezzo del pannello) per rispondere subito leggendo.
  Da ripensare con lui: «espandi» che allarga il pannello del registratore fino alla scheda del vocale.
- Widget: torna il gradiente (gli piaceva di più), dai token: un'immagine del gradiente dietro al contenuto,
  ritagliata dalla pillola (`clipToOutline`). Stessi colori nell'anteprima.
- Argomenti: il nome del concetto lo sceglie il motore sul testo di tutti i suoi album (`concettoNome`), e i verbi
  comuni («stare», «andare»…) non sono più parole chiave.
- Vocale e Floater, un pannello solo (sua idea): il vocale condiviso sta in cima al pannello del Floater
  (`SezioneVocale`, una card a sé), sotto i comandi per registrare la risposta. Ogni X sta dentro quello che chiude:
  la X della card toglie il vocale (arriva il prossimo, se c'è), la X del registratore chiude il pannello.
  Espandi/riduci, nei Pensieri e cestino stanno nella card. ✓ «ferma e trascrivi» chiude il pannello (hai finito);
  la pausa non chiude niente.
  Via la scheda del vocale a parte (`MessageStage`, `Stage.Message`): era un doppione del pannello.
- Col vocale, il registratore è una riga sua (`RigaRegistratore`): la X tutta a sinistra chiude il pannello, poi
  l'onda, poi i tasti (`TastiVoce`, lo stesso pezzo del pannello normale). Il vocale ridotto è solo la sua barretta
  (il titolo, niente testo) e il pannello resta stretto; largo quanto lo schermo solo col vocale espanso.
- Icona nuova: Transcri grande al centro, coi suoi due toni d'arancione e gli occhi, su un fondo scuro e caldo
  (come il Floater). L'icona «a tema» è la sua sagoma. Colori fissi: il launcher non legge i token.
