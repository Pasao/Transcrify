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
  `Spazio.s1…s10`, `Raggio.*`, `Misura.*`, `Durata.*`, `Curva.*`, `Ombra.*`, `Scala.*` e `Velo.*` (5 nov: di quanto
  si ingrandisce una cosa per dire in che stato è, quanto si spegne quello che sta dietro; in Figma B3 da aggiungere).
- **Un file per responsabilità (SOLID).** Figma è il riferimento, ma il codice è organizzato da
  codice: ogni file fa una cosa, i pezzi grandi sono composti da quelli piccoli. `lib/ui/ds/` (colori, misure, testo), `lib/ui/atomi/` (un file per
  atomo), poi `lib/ui/molecole/` e così via. `ds.dart` e `atomi.dart` sono solo indici che li esportano.
  Ogni regola sta in un posto solo (es. lo stile dei bottoni: `Bottone.stile`, usato anche dal tema).
- **I nomi vecchi** (`Tokens`, `tk.muted`, …) non ci sono più (2 nov): in Flutter i colori passano
  solo da `context.col` (o `Colori.adesso` dove non c'è un context). I caratteri: `Testo.fontTitoli/fontTesto` (orari e conteggi: `Testo.orario`, Inter con le cifre tabellari);
  per leggere `Testo.lettura` / `Testo.letturaScheda` (Onest; Literata tolto al giro 7).
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
| 5 nov, colori delle trascrizioni, privata, unisci, cartelle (la tavolozza in `ds/tinte.dart`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 5 nov, il menu che si stacca, la fila che scorre, la tavolozza a fumetto, scegliere, il volo dell'unione (`Scala`, `Velo`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 5 nov sera, via il volo della pillola (e i suoi tempi), cartelle rifatte | **0** | **0** | **0** | **0** | **0** | **0** |
| 5 nov, giro 3: un gesto solo per scegliere, via il menu e «Scegli cosa unire», scelta del colore unica, ombre calde | **0** | **0** | **0** | **0** | **0** | **0** |
| 5 nov sera, la pillola si seppellisce (`Durate.SEPPELLISCE`/`RISPUNTA`), cartelle = Trascrivi per colore (`Misura.cartella`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 4: testo formattato (`Velo.segni`), lo scatto del Floater (`Durate.SCATTO_*`, `Scatto.kt`), «Richiama» nella notifica | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 4: in cima come in fondo (l'intestazione che diventa pillole, `Isola(fondo:)`), la ricerca (`CampoNudo`, `ChipFiltro`), Dock più piccolo (`Misura.isola` 56, `tondo` = `tocco`), `Curva.scambio` | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 4: la barra al posto del Dock (`Scelta`), `Durata.scelta`, `Velo.spento(quanto)`, `Colori.sospesi`, i nove colori (`Tinte.preferiti`), cartelle che si aprono (via `Misura.cartella`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 6: leggere in Onest/Literata (`Testo.lettura*`, `Testo.spazioParagrafo`, `Testo.rigaVuota`, `SceltaLettura`), l'incavo del nido (`Ombra.incavo`), tre grane (`atomi/grana.dart`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 5: una pillola sola per «Annulla» (`molecole/pillola_annulla.dart`), le pillole in cima come il Dock (`Isola.bordo`, `Testo.titoloPillola`), `Tinte.dorso`, la rosa dei colori (`Misura.rosa*`, `Durata.rosa`, `Curva.rosa*`), via DM Mono (`Testo.orario` tabellare, `Caratteri.tempo`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 6: titoli (`core/titoli.dart`), la fascia a due righe, la privata a macchie (`Durata.giroPrivata`, `Tinte.macchie`), il cerchio del colore (`Misura.cerchioColore`/`anello`/`anelloStacco`), i filtri in Trascrivi, le cartelle che si aprono lì (via `cartella_aperta.dart`, `si_apre_da.dart`), `Intestazione.sottoPillole` | **0** | **0** | **0** | **0** | **0** | **0** |
| 6 nov, giro 7: i filtri in tre file (`FiltriPossibili`, `molecole/filtri_voci.dart`, `molecole/tasto_filtri.dart`, `filtri_trascrivi.dart`), via le Cartelle dal Dock e i titoli (prove), la privata tagliata e ferma, schede più staccate (`Token.kt` scheda), l'incavo che si vede (`Ombra.incavo(luce)`), via Literata | **0** | **0** | **0** | **0** | **0** | **0** |
| 7 nov: solo la rosa per il colore (via la fila dei nove), la ✕ al centro, il dito che scorre (`Misura.rosaSotto`/`rosaFerma`), prova/Annulla/Fatto (`core/cambio_colore.dart`), la ruota al posto di `Icons.palette` (`SelectionBar.colore`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 7 nov, rifiniture: la rosa che esce svelta dopo un colore (`Durata.rosaVia`), il puntino dei colori in uso (`Misura.rosaUso`/`rosaUsoFuori`, `Segni.usi`), la fila che scorre di lato con il bordo sfumato (`atomi/fila_scorre.dart`: filtri accesi e pannello), le ricerche recenti (`core/ricerche_recenti.dart`, `molecole/ricerche_fatte.dart`), il lucchetto nella trascrizione aperta, gli argomenti accesi dal tasto della nota (`Core.accendiArgomenti`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 7 nov, giro 2: il fondo dell'introduzione sempre uguale (`molecole/piede_intro.dart`: «Salta» a sinistra, il principale a destra), la prova di Transcri (`prova_transcri.dart`, `microfonoPronto`, `VoceInBarra.tempo`, `Shell.atterra`), «Fine» nella barra delle scelte, la copertura della privata che arriva sulla scheda (`AnimatedSwitcher`, `Durata.lenta`), il ponte del Floater in un Path solo (`PonteFuso.kt`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 7 nov, giro 3 (rifinitura): «Offusca» al posto di «Privata» (`Offusca`, `BottoneOffusca`, `CoperturaPrivata.neutra`, anche sulle note), il cestino sotto il titolo, la rosa che spegne i colori liberi (`Misura.rosaLibera`/`rosaLiberaVelo`), la regola dell'etichetta (`core/regole_colori.dart`), `SegnoAuto`, una conferma sola (`molecole/conferma.dart`), l'introduzione in `avvio.dart`, il nido vuoto con la sagoma di Transcri (`TranscriCorpo.forma`, `TrattiNido`) | **0** | **0** | **0** | **0** | **0** | **0** |
| 10 nov, ultimo giro: `Dialogo`, `PillolaBordo`, togli/proponi etichette (`Tinte.lontane`), l'anello della prova (`Misura.anelloVoce*`, `pillola*`), la fascia della scheda | **0** | **0** | **0** | **0** | **0** | **0** |
| 10 nov, giro finale: le proposte di colore in Trascrivi (`core/proposte_colore.dart`, `molecole/proposte_colore.dart`), «Proponi regole», `Core.chiedi` | **0** | **0** | **0** | **0** | **0** | **0** |
| 10 nov, dopo il giro finale: la pagina «Da sistemare» (in attesa e proposte di colore), `atomi/contatore.dart`, il titolo in cima di una misura sola, la prova con la pillola vera (`inPixel`, `chiediSopraLeApp`) | **0** | **0** | **0** | **0** | **0** | **0** |

## La lista (righe di C0)

Stato: ☐ da fare · ◐ in corso · ☑ fatto

### Fondamenta
- ☑ Colori: `Token.kt` fonte unica (app, pillola, widget)
- ☑ Caratteri, spazi, raggi, misure, ombre, movimento: definiti in `ds.dart` (da usare pezzo per pezzo)

### Atomi
- ☑ Bottone: `atomi/bottone.dart`; FilledButton/OutlinedButton/TextButton prendono lo stesso stile dal tema (Pieno / Tenue senza contorno / Testo)
- ☑ BottoneIcona: `atomi/bottone_icona.dart` (icona piccola sotto i 40: lo usano anche i ComandiVoce); RoundAction (ora nuda) e PowerBadge passano da lì, IconButton dal tema; nel Kotlin i tasti del Floater prendono i colori da Palette (token)
- ☑ BarraInFondo: `atomi/barra_in_fondo.dart`, le barre in fondo (Dock, barra delle cose scelte, barra sotto la nota e sotto la trascrizione): i suggerimenti dei tasti escono sopra il dito, non sotto
- ☑ Chip: `atomi/chip_stato.dart` («Dati finti»; StatusChip tolto)
- ☑ FilaScorre (7 nov): `atomi/fila_scorre.dart`, una fila che se non ci sta scorre di lato, col bordo sfumato dalla parte dove continua; la usano i filtri accesi sotto il titolo e le file del pannello dei filtri
- ☑ Interruttore e Campo: dal tema (suggerimento leggibile, contorno solo da attivo)
- ☑ Scheda: `atomi/scheda.dart`, la usano MiniCard, NoteCard, PezzoArgomento, Chiave trovata
- ☑ Cestino e Copia: colori dei token (armato = errore tenue, copiato = ✓ su successo tenue)
- ☑ Transcri e Nido: colori dai token (via le tre variabili globali e i campi doppi del nativo)
- ☑ Grana (6 nov, al posto del Mirino e di GrainIcon, tolti): `atomi/grana.dart`, `Grana` (i livelli e i nomi: Spento,
  Argomenti, Frasi, Parole chiave; `Grana.dopo` = il tocco) e `BarreGrana` (tre barre dalla più lunga in alto, si accendono
  una dopo l'altra in `Durata.veloce`; spenta = tutte leggere, `Velo.nonScelta`)
- ☑ EtichettaGruppo: `atomi/etichetta_gruppo.dart`, usata dai gruppi delle impostazioni
- ☑ IconaModo, IconaFonte: colori dai token
- ☑ Anteprima: `atomi/anteprima.dart`, l'inizio del testo su una scheda (righe e «…»); a Flutter arriva solo l'inizio, non la dettatura intera. La usano la scheda di Trascrivi e SchedaNota
- ☑ Testo formattato (6 nov): **grassetto**, *corsivo*, link / e-mail / telefoni che si toccano. La regola è una sola,
  `core/formato.dart` (`Formato.leggi`: i pezzi, con e senza segni), e uno solo è come si vede: `atomi/formattato.dart`
  (`Formattato.span`, `Formattato.apri` con url_launcher). L'Anteprima delle schede la usa (segni nascosti, link toccabili;
  spenti mentre scegli); nei campi dove scrivi (trascrizione aperta e nota, `atomi/campo_formattato.dart`, `CampoFormattato`,
  da cui eredita `TopicTextController`, ora in `atomi/campo_argomenti.dart`) i segni (7 nov) non si vedono
  (`Testo.segnoNascosto`) tranne sul pezzo dove sta il cursore, spenti (`Velo.segni` 0,35). Il testo salvato non cambia mai.
  Gli elenchi «- » e «• » restano com'erano. Anche `[parole](https://…)` (il tasto «Link»): si vede solo «parole».
  Nel campo, il cursore su un link fa spuntare «Apri» sotto di lui (`molecole/apri_collegamento.dart`, `ApriCollegamento`;
  dove cade lo dice `atomi/punto_nel_campo.dart`, lo stesso di CursoreVoce). `test/formato_test.dart`, `test/barra_nota_test.dart`
- ☑ BarraNota (7 nov): `ui/barra_nota.dart`, la barra della nota. A sinistra si scrive (Annulla, Ripeti, Grassetto, Corsivo,
  Elenco, Link: scorre di lato se stretta), `VerticalDivider` in `linea`, a destra la grana degli argomenti e il Riassunto;
  BottoneIcona da 40. I ritocchi sul testo sono una regola sola, `core/scrittura.dart` (`Scrittura`). La pagina Argomenti
  delle Note è nascosta: torna con Prove → «Mostra gli argomenti» (`Core.mostraArgomenti`)

### Il Dock e i poteri
- ☑ Dock: `dock.dart` compone `molecole/` (isola, medaglione, pillola_pagine, rientra); `potere.dart` a parte.
  Tolti i doppioni `islandColor`, `islandShadow`, `dockIsland`, `dockRound` (erano i token isola, Ombra.appoggiato, Misura.isola/tondo).
- ☑ Cambio potere (sua scelta nel codice, 2 nov): TRASCINI SU il medaglione (56 dal 6 nov, come le isole) = ti segue,
  sopra compare il nome di chi arriva (`molecole/nome_potere.dart`), superata la soglia passa al prossimo;
  TOCCO = sale la colonna. Figma (B6, S09, C0) aggiornato uguale.
- ☑ ColonnaPoteri: `molecole/colonna_poteri.dart`, si apre col tocco, tocchi il potere
- ☑ Provato sul telefono coi dati finti (tema scuro): trascina, nome, colonna. Trovato e corretto: al buio
  l'isola era più scura della pagina (sembrava un buco) → in `Token.kt` di notte `surfaceContainerHighest`
  (#3C3331 sul salmone; `TokenTest` lo controlla); anche il calcolo di Figma e le variabili di B2.
- ☑ Medaglione e pagina scelta, due salmoni vicini: gli va bene («sembra colorarsi»)
- ☑ **Più piccolo** (6 nov, giro 4: «troppo grande, più piccolo lascia più spazio»): `Misura.isola` 64 → 56, `Misura.tondo`
  52 → 48 (= `Misura.tocco`: i tasti restano grandi quanto un dito). Il medaglione, le isole, la casa di Transcri, la colonna
  dei poteri e le pillole dell'intestazione seguono da soli.
- ☑ **Si muove, non salta** (6 nov, giro 4: «rendi i movimenti più fluidi»), tutto coi token (`Durata.normale`, `Curva.*`):
  cambiando potere il medaglione batte (`Scala.battito`, `Durata.battito`) e dentro il segno di prima esce in alto mentre il
  nuovo sale dal basso (il verso del gesto); la colonna dei poteri spunta dal medaglione (`atomi/spunta.dart`, come i fumetti);
  la pagina nuova sale appena mentre compare. Nella pillola delle pagine il fondo acceso è **uno solo e scivola**
  (`Curva.scambio`, nuova: le cose che passano da un posto all'altro) e l'icona cambia colore insieme a lui (`BottoneIcona`
  ora sfuma il colore dell'icona; `conFondo: false` = il fondo lo disegna qualcun altro). `Rientra` usa `Curva.scambio`.
- ☑ **Si fa da parte mentre si sceglie** (6 nov, giro 4): `Dock(nascosto:)` ascolta `Scelta.attiva` (in `shell.dart`) ed esce
  con lo stesso movimento della barra delle scelte (`Scelta.transizione`): si danno il cambio. Nascosto non si tocca.

### Le pagine
- ☑ Intestazione: `molecole/intestazione.dart`, `molecole/riga_in_attesa.dart` (riga con Riprova; ridotta «⏱ n»).
  **In cima come in fondo** (6 nov, giro 4: «la barra in basso sono pillole che fanno scorrere il testo sotto; sopra deve essere
  uguale, come WhatsApp e Samsung»): ferma in cima è una barra (titolo grande, «Dati finti» accanto, la riga in attesa sotto);
  appena la pagina scorre la barra si ritira e restano **due pillole** che galleggiano sopra la pagina, le stesse isole del Dock
  (`molecole/isola.dart`, alte `Misura.isola`): a sinistra il titolo (spunta con `Spunta`), a destra le azioni, che restano
  ferme e prendono il fondo e l'ombra dell'isola (`Isola(fondo:)` li fa arrivare piano). La pagina scorre sotto. Tornata in
  cima (o cambiata pagina, `pagina:`) torna la barra. Lo stato lo tiene l'intestazione stessa (ascolta la lista della pagina,
  con un margine perché il bordo non sfarfalli): una sola molecola per Trascrivi, Note, Argomenti, Cartelle e la cartella aperta,
  senza codice di scorrimento nelle pagine. Su un telefono stretto col testo grande i segni accanto al titolo si rimpiccioliscono.
  `Intestazione.altaPillole` dice fin dove arrivano le pillole (sotto ci sta la data che scorre).
  `indietro:` mette ‹ a sinistra del titolo, nella barra e nella pillola (la cartella aperta: via la X tra le azioni).
- ☑ **La lente e il ⋮** (6 nov, sua scelta): in alto a destra solo la lente (apre la ricerca) e il ⋮ (`molecole/tasto_menu.dart`:
  le voci in un fumetto che spunta dal tasto, come la scelta del colore) con «Seleziona» (dove si sceglie) e «Impostazioni».
  Via l'ingranaggio. Le stesse azioni ovunque: `azioni_pagina.dart` (`azioniPagina`).
- ☑ **La ricerca** (6 nov, come One UI 8.5): `cerca.dart` (`apriRicerca`, `CercaPage`), la stessa da Trascrivi e dalle Note (via il
  campo in cima alle Note, `SearchField`, e «Ricerca come frasi» nelle Prove: ora è sempre così). In fondo, sopra la tastiera che
  si apre da sola, il campo in un'isola con «Annulla» (`molecole/campo_ricerca.dart`); «indietro» chiude anche lui. In cima i
  filtri (**superato al giro 6**: ora sono sotto il titolo di Trascrivi, vedi in fondo) (`molecole/filtri_ricerca.dart`, `atomi/chip_filtro.dart`): la fonte (Tutte · WhatsApp · Altre app, dal `source`
  salvato; WhatsApp Business conta come WhatsApp), il modo (Fedele · Pulita · Riassunto, dal `mode`), e i colori che hanno le
  trascrizioni (`PuntoColore`). Il modo e il colore ce li hanno solo le trascrizioni: sceglierne uno lascia fuori le note. La
  regola dei filtri sta in `core/filtro_ricerca.dart` (`FiltroRicerca`, `Fonte`, `modi`: i nomi dei modi, li usa anche
  `EtichettaModo`). I risultati: il motore di sempre (`Ricerca.cerca`: prima le parole, poi il senso), una `RigaTrovata` per
  frase, note e trascrizioni insieme; le private mai. Un campo senza fondo né contorno è uno solo: `atomi/campo_nudo.dart`
  (`CampoNudo.decorazione`, anche nella trascrizione aperta e nella nota).
- ☑ Tolti StatusChip, StatusSheet e `status.dart`: chiave mancante → la chiede Transcri; minuti finiti → tocco su Transcri che dorme apre l'Utilizzo.
- ☑ Buttare una registrazione in attesa (sua richiesta): toccando la riga si apre (dal 10 nov) la pagina «Da sistemare», `ui/da_sistemare.dart` con `molecole/sezione_in_attesa.dart` (giorno, ora, durata, cestino; «Riprova tutte»). Riprovarne una sola: il nativo non lo sa fare (solo tutte).
- ☑ Trascrivi: `molecole/titolo_giorno.dart` (22) ☑; carosello con `Scheda.fondo/forma` ☑; data che scorre = `atomi/etichetta_sospesa.dart` (lo stesso del nome del potere: un atomo solo) ☑; **la data in cima**
  (6 nov, giro 4: «come Samsung Gallery»): `molecole/scorri_giorni.dart` (`ScorriGiorni`, era `_FastScroll` in Trascrivi) mette,
  mentre scorri, il giorno che stai guardando in cima, al centro sotto le pillole, e la toglie poco dopo che ti fermi; trascinando
  lo slider la data va accanto al dito e quella in cima si fa da parte. Tutte e due sono `EtichettaSospesa` (sul telefono non sono riuscito a prendere la barretta: da guardare); stato vuoto: StatoVuoto ☑
- ☑ Barra della trascrizione: `molecole/voce_in_barra.dart` (a riposo il microfono + «Aggiungi a voce», sua scelta; il dettato entra al cursore; dettando i `molecole/comandi_voce.dart` piccoli: butta, ✓, pausa/riprendi, col tempo / «in pausa» / «trascrivo…»). Il nativo ora manda `paused` e `seconds`, e sa `togglePause` dall'app. Il pannello del Floater non si apre più sopra (i comandi sono nella barra). Provata a riposo sul telefono; gli stati mentre detta nel test di overflow.
- ☑ «Detta qui» (5 nov, Figma D2 righe 2 e 2b): a riposo il bottone tenue col microfono «Detta qui» (niente Transcri). Il tocco
  fa partire subito la registrazione. Il volo della pillola fino alla barra è stato tolto (sua scelta, 5 nov sera: «entra
  velocissimo, e poi torna comunque di lato»): mentre si detta nell'app la pillola sul bordo **si seppellisce nel bordo**
  (5 nov sera, sua richiesta: «sparire seppellendosi completamente nel bordo, con una piccola animazione»; «sono due cose
  diverse»): ci scivola tutta dentro (`Durate.SEPPELLISCE` 260, curva che rallenta), sepolta non si tocca
  (`FLAG_NOT_TOUCHABLE`), e a fine dettatura (mandata e trascritta, buttata, errore) ne rispunta con un piccolo rimbalzo
  (`Durate.RISPUNTA` 420, `RIMBALZO_RISPUNTA`) dove stava a riposo, mezza fuori. La regola è nel nativo, `Dettatura.kt`
  (`seppellisce`, `scostamento`; `DettaturaTest`): sepolta solo se la dettatura è partita da «Detta qui», l'app si vede
  (`PillService.appDavanti`, da onStart/onStop) e sta ancora ascoltando o trascrivendo. Se l'app va via rispunta subito
  (servono i suoi comandi); se il foglio si chiude a metà, `VoceInBarra` lo dice al nativo (`Core.lasciaDettatura`). La disegna
  `PillBar` (spostata di tutta la sua finestra verso il bordo), le scene non c'entrano.
  Mentre detta, `molecole/cursore_voce.dart` disegna nel testo il cursore arancione (azione,
  `Misura.cursoreVoce` 3 px) dove entrerà la voce, e il testo non si tocca. **Da vedere sul telefono.**
- ☑ Successo «l'ultimo respiro» (5 nov, Figma D2 riga 1 · B, sua scelta): `Respiro.kt` (`ultimoRespiro`), lo usano la pillola
  (smette di ondulare e si stringe a 0,86, respira a 1,08 diventando verde, si calma) e il cerchio del Floater aperto (il blob
  si ferma e respira diventando il tasto verde). Tempi in `Durate.kt` (`RESPIRO_*`). Il salto di prima resta: Impostazioni →
  Prove → «Successo: l'ultimo respiro» (acceso di base; `Simulated.respiro`, ricordato nelle preferenze). **Da vedere sul telefono.**
- ☑ Foglio della trascrizione: colori, testi e raggi dai token
- ☑ Selezione e Annulla: fondo «floater», testo «suFloater», Elimina nel rosso del pericolo (6 nov: `errore` del tema scuro, vedi sotto); Annulla 2 s (sua scelta, `Durata.annulla`, anche in Figma)
- ☑ Pensieri: colori dai token; selettore ed etichetta della grana sul fondo «floater» (`EtichettaSospesa`); i 6 colori degli argomenti = token `argomenti` (via la lista a parte) ☑; SchedaNota con la Scheda ☑
- ☑ Nota aperta: `BarreGrana`, selettore della grana sul fondo «floater» (tenendo il tasto: i nomi), etichetta della grana = EtichettaSospesa
- ☑ Argomenti a due livelli: il motore raggruppa gli album che si somigliano (`Topics.concetti`, test `conceptsGroupEveryShownAlbumOnce`) e manda `concetto` a ogni album; `molecole/scheda_argomento.dart` (concetto col suo colore, mosaico: il più parlato grande, gli altri piccoli; tessere che crescono col testo, test di overflow); `molecole/pezzo_argomento.dart` (riassunto dei pezzi lunghi con Groq, «Originale»; i corti interi; riassunti tenuti in memoria finché l'app è aperta). Da vedere sul telefono.
- ☑ Liste fluide (3 nov): Trascrivi e Pensieri costruiscono solo quello che si vede (Trascrivi una lista al contrario, un giorno per riga; Pensieri due colonne pigre, `Masonry` è uno sliver); rileggendo dal nativo si ridisegna solo se qualcosa è cambiato (`==` su Entry, Note, Album); il rosso del cestino tenuto premuto è sopra la scheda, non più un filtro di colore; le letture delle liste nel Kotlin sono fuori dal thread principale. Misure: `test/fluido_test.dart`
- ☑ Stati vuoti: `molecole/stato_vuoto.dart`, uno solo per Trascrivi, Pensieri, Argomenti
- ☑ Impostazioni: colori, testi, raggi dai token; le etichette dei gruppi usano EtichettaGruppo (erano due copie)
- ☑ Chiave trovata: scheda neutra (Scheda), verde solo la spunta; «Usa questa chiave» è il principale del fondo. ☑ Il fondo
  dell'introduzione (`PiedeIntro`, 7 nov): su ogni pagina (1 cos'è, 2 la chiave, 3 la prova) «Salta» in basso a sinistra, il
  conteggio in mezzo, il principale in basso a destra. ☑ La prova (`ProvaTranscri`): Prova → Stop → Trascrivo…, poi si entra
  e Transcri atterra nel nido; senza chiave, microfono o rete lo dice in una riga e si salta. ◐ Introduzione: la testata coi colori di Transcri è un'eccezione dichiarata

### Colori, privata, unisci, cartelle (5 nov, Figma D1–D2)
- ☑ Tavolozza: `ds/tinte.dart` (`Tinte`), 16 tinte × 7 luci in HSL (6 nov, giro 5: erano 7 × 7; le 9 nuove in fondo, vedi sotto) (saturazione 62%), un posto solo. Un colore = (tinta, luce),
  `Colore` in `core/segni.dart`; nel nativo solo «tinta:luce» (il Kotlin non lo disegna: niente copia in `Token.kt`).
  Fondo della scheda: luce 2 (86%) nel chiaro; nello scuro la stessa tinta al 22%. Copertura della privata e linguetta
  della cartella: una luce più scura (77% / 16%). `test/segni_test.dart` controlla il contrasto (testo e secondario ≥ 4,5:1).
- ☑ Atomi: `atomi/punto_colore.dart` (puntino col suo anello e, scelto, la spunta dentro, chiara o scura secondo il colore;
  tocco largo 40; `PuntoColore.di` = il puntino di un colore, neutro se non ne ha), `atomi/copertura_privata.dart` (lucchetto,
  da bordo a bordo, solo sulla parte del testo), `atomi/etichetta_modo.dart` (l'icona del modo: era `_ModeTag` in Trascrivi).
- ☑ `molecole/scheda_trascrizione.dart`: la scheda di Trascrivi (era `_MiniCard`), col colore e la privata. **Tutte la stessa
  forma** (5 nov, giro 3: «sulle private la riga è centrata, sulle normali no»): in alto il testo, in fondo una fascia alta
  `SchedaTrascrizione.fascia` (= `Misura.tocco` 48) con la riga dell'ora/modo/cestino al centro; la privata copre solo il testo.
- ☑ **Un gesto solo** (5 nov, giro 3: «troppe interazioni diverse per la stessa cosa»): tenere premuta una scheda la
  **sceglie** e si comincia a scegliere (vibra), come nella Galleria; poi un tocco sceglie o toglie. Via il menu che si
  staccava (`menu_scheda.dart`, `Velo.menu`, `Scala.sollevata`, `Durata.solleva`, `Curva.dopo`: tolti).
  «Seleziona» (6 nov): non più un tasto nell'intestazione (via `tasto_scegli.dart`) ma una voce del ⋮ (dell'intestazione), che
  accende lo stesso interruttore, `TrascriviPage.scegliendo` (lo accende anche tenere premuta una scheda; lo spegne «Fine»).
  Una cartella aperta ha un interruttore suo: scegliere lì non tocca Trascrivi sotto.
- ☑ La scheda scelta (giro 3: «si deve staccare anche se sono tutte marroni»): resta a colori, contorno spesso nel colore
  del testo (`Misura.bordoScelta`), l'ombra «appoggiato», `atomi/spunta_scelta.dart` piena nell'angolo, si stringe a
  `Scala.scelta` 0,95. Le altre: tondo vuoto, si spengono (`Velo.nonScelta` 0,45) e perdono il colore (`Velo.spento(quanto)`,
  grigio; il filtro c'è solo mentre il grigio non è zero). **Movimento unico della scelta** (6 nov, giro 4: «si devono muovere
  uguali»): `Durata.scelta` (= normale, 250) con `Curva.standard` per velo, grigio (ora arriva piano, prima scattava), misura,
  fondo + contorno + ombra della scheda (un `AnimatedContainer` solo: prima il fondo e il contorno saltavano), spunta (la ✓
  cresce), spazio in fondo alla lista e barra; il contenuto della scheda non si ricostruisce quando arriva il filtro (GlobalKey). La regola sta in un atomo solo, `atomi/aspetto_scelta.dart`, lo stesso delle cartelle. **Ombre calde**: `Ombra.*` prendono la tinta da un posto solo (`Ombra._tinta`,
  marrone scuro), non più il nero.
- ☑ La barra delle scelte (`molecole/barra_scelte.dart`, era in `common.dart` che la riesporta; la usano Trascrivi, Pensieri, le
  cartelle e la cartella aperta): in alto «Nessuna scelta» / «1 scelta» / «N scelte» (`SelectionBar.etichetta`) e **«Fine»**
  (6 nov: la parola, non più la X; 7 nov: «Fine», non «Annulla»: le azioni valgono subito, qui si esce soltanto); sotto le azioni coi nomi. API: `SelectionBar(quante:, onClose:, actions:)`, ogni azione
  `(icona, nome, (Rect dove) {})`: `dove` è il tasto alto fino in cima alla barra, così quello che apre spunta sopra la barra.
  Trascrivi: Colore, Copia, Condividi, Unisci (da due), Privata / Visibile, Elimina.
  **Al posto del Dock** (6 nov: «è inutile navigare mentre scegli»): `ConSelezione` mette la barra nel posto del Dock (stesso
  bordo basso, `bottom − Misura.isola`; le liste lasciano in più solo `SelectionBar.altezza − Misura.isola`) e la fa entrare con
  `Scelta.transizione` (sale un poco e appare; esce scendendo, `Curva.uscita`) in `Scelta.durata` (= `Durata.scelta`).
  **API per il Dock:** `Scelta.attiva` (`ValueNotifier<bool>`, vero finché una pagina mostra la barra; lo accende `ConSelezione`,
  mai durante la costruzione): la shell lo ascolta e il Dock si fa da parte (`Dock.nascosto`). «Annulla» sale sopra la barra
  leggendo lo stesso `Scelta.attiva`. **«Indietro»** mentre c'è la barra chiude la scelta (`PopScope` in `ConSelezione`, per
  tutte le pagine che la usano): non esce mai dall'app né dalla cartella aperta.
  **Il rosso del pericolo** (6 nov: «il rosso nella barra si legge male»): era `erroreTenue`, nel tema scuro un rosso scuro
  sul fondo scuro. Il rosso è uno solo, `errore` di `Token.kt` (tono 40 nel chiaro, 80 nello scuro); quello che sta sul floater
  (sempre scuro) prende i token del tema scuro, `Colori.sospesi` (la stessa regola di `Palette` nella pillola), anche «Annulla»
  del messaggio. Contrasto ≥ 4,5:1 su pagina, schede, isole, `erroreTenue` e floater, nel chiaro e nello scuro, con 8 colori del
  telefono: `TokenTest` (Kotlin) e `segni_test`.
- ☑ La scelta del colore, una sola (7 nov: **solo la rosa**, «la rosa la amo»; via la fila dei nove e il «+», «la filetta
  che sposti a destra e sinistra è strana: non ti ricordi che colore hai scelto»; via `Tinte.preferiti`, `FilaColori.nove`):
  `molecole/scelta_colore.dart` (`apriSceltaColore`), da «Colore» nella barra (`SelectionBar.colore`, con la **ruota dei
  colori** `atomi/ruota_colori.dart` al posto di `Icons.palette`: `regole_test` controlla che non torni) e dal cerchio del
  colore nella trascrizione aperta. La stessa per una e per tante. Un fumetto (`molecole/fumetto.dart`) con la rosa
  (`molecole/tavolozza.dart`, vedi sotto). **Prova, Annulla, Fatto** (sua: «se premo Annulla quello che ho cambiato resta
  cambiato: non lo voglio»): ogni colore scelto si salva e si vede subito sulle schede, ma `core/cambio_colore.dart`
  (`CambioColore`) ricorda il colore di prima di **ognuna** e i nomi; «Annulla» rimette tutto (colore e nome), «Fatto» tiene.
  «Indietro» e un tocco fuori **tengono** (scelta nostra: è quello che si aspetta chi tocca fuori, e niente va perso) e, se è
  cambiato qualcosa, arriva la pillola «Colore cambiato · Annulla» (`undoable`), che rimette a ognuna il suo colore di prima.
  Una cartella sola che cambia colore si porta dietro il nome (`nomeSegue`).
- ☑ «Unisci» subito (giro 3: «ho toccato Unisci perché volevo unire»): si uniscono nell'ordine dei tocchi, senza conferma.
  Via `barra_unisci.dart` («Scegli cosa unire», «Unisci N») e i numeri sulle schede. Se hanno colori diversi (anche senza),
  prima spunta sopra «Unisci» la fila coi soli colori in gioco (`apriColoreUnione`, niente «+»): un tocco sceglie il colore
  della scheda unita e unisce. Il nativo unisce in una scrittura (`Ritocchi.kt`, `RitocchiTest`), poi il colore.
  `molecole/volo_unione.dart`: `voloUnione` (le schede volano una dopo l'altra sulla prima, `Durata.voloUnione` 520, poi la
  scheda unita va al suo posto e batte, `Scala.battito`, `Durata.battito` 360); «Trascrizioni fuse» con «Annulla»
  (`Durata.annullaUnione` 4 s). **«Annulla» al contrario** (`voloSeparazione`): la scheda unita torna sulla prima, batte, e da
  lei le altre volano ai loro posti; alla fine tutto è com'era (test).
- ☑ Tema scuro: i fondi delle schede (e delle cartelle) meno saturi, `Tinte.saturazioneScuro` 0,26 (5 nov: «bordeaux»);
  i puntini della tavolozza restano pieni. `test/segni_test.dart` controlla saturazione e contrasto.
- ☑ **Cartelle che si aprono** (6 nov, giro 4, sua scelta: «solo cartelle che si aprono»). Prima (5 nov sera) le cartelle erano
  Trascrivi raggruppato per colore (indice in cima, una sezione per cartella; e, nelle Prove, «Cartelle nel Dock» per metterle in
  fondo a Trascrivi): via `SezioniCartelle`, `indice_cartelle.dart`, `TrascriviPage(perCartelle:)`, `Cartelle.nelDock` e il suo
  interruttore nelle Prove (con le cartelle che si aprono, metterle in fondo a Trascrivi non aveva più senso).
  Ora: `CartellePage` (`cartelle.dart`) mostra **solo le cartelle disegnate, due per riga** (`molecole/griglia_cartelle.dart`,
  `DatiCartella`), più alte che larghe (~154 × 180 a 360 dp, `atomi/sagoma_cartella.dart`). Toccata, una cartella **si apre**:
  `molecole/si_apre_da.dart` (`SiApreDa`, la pagina si allarga dal riquadro della cartella col suo colore, poi appare dentro;
  `Durata.lenta` ad aprirsi, `Durata.normale` a richiudersi nella cartella) porta a `cartella_aperta.dart` (`CartellaAperta`; **superato al giro 6**: ora si aprono lì, vedi in fondo): è
  **Trascrivi** (`TrascriviPage(cartella: colore)`) per giorni, coi soli colori suoi: stessa `Intestazione` col nome della cartella
  (la X tra le azioni la richiude; anche «indietro»), stesse schede, gesti, barra, stesso spazio in fondo (le schede stanno
  all'altezza di Trascrivi). Vuota: «In questa cartella non c'è più niente.»
  `molecole/fogli_cartella.dart` (le tre più nuove come fogli che sporgono; le private bianche); `molecole/cartella.dart` (premuta si
  piega appena; tenuta premuta si sceglie: spunta sulla tasca e `atomi/aspetto_scelta.dart`, lo stesso aspetto delle schede scelte).
  **Azioni** (`scelta_cartelle.dart`, `SceltaCartelle`): la barra delle scelte (al posto del Dock) con **Rinomina** (una sola:
  `molecole/rinomina.dart`, un dialogo come in Samsung: «Rinomina», il campo già pronto, vuoto, col nome di adesso come
  suggerimento, «Annulla» a sinistra e «Rinomina» a destra, acceso solo con un nome nuovo; rinominata, la scelta finisce. Via il
  fumetto `nome_cartella.dart`), Colore (tutte le sue trascrizioni cambiano colore e il nome va con loro) e «Togli cartella» (le
  trascrizioni restano, senza colore; «Annulla» le rimette com'erano). Stato vuoto: StatoVuoto con le sagome di due cartelle vuote
  (`molecole/cartella_vuota.dart`). Test: `test/cartelle_test.dart`. **Da vedere sul telefono** (coi dati finti).

### Laboratorio: il riassunto estrattivo (6 nov, giro 4)
- ☑ Impostazioni → Prove → «Prova il riassunto estrattivo» (`prova_estratto.dart`): scegli una trascrizione o una nota, il
  motore sul telefono sceglie le frasi che contano. **Solo lettura**: niente si scrive (né note, né storia, né il senso delle
  frasi su disco: `Engine.sensoSenzaRicordare`), niente rete; nient'altro nell'app cambia (Categorie e Argomenti restano).
  `molecole/risultato_estratto.dart` (tempo in ms, le frasi pulite; toccandone una il testo scorre fin lì) e
  `molecole/testo_evidenziato.dart` (il testo originale con le frasi illuminate, quella toccata più forte). Senza modello lo
  dice e porta alla scelta del modello. Il motore nel Kotlin: `engine/Estratto.kt` (tagli → pulizia → peso = ½ centralità +
  ½ indizi → MMR λ 0,7, da 1 a 4 frasi), `Tagli.kt`, `Parlato.kt` (riempitivi, solo per leggere, con gli intervalli
  nell'originale), `Indizi.kt`, `Mmr.kt`. Test: `EstrattoTest`, `EstrattoBancoTest` (col modello vero sul banco finto
  `estratto-banco.json`), `test/prova_estratto_test.dart`. **Da provare sul telefono.**

### Giro 5 (6 nov sera, le sue prove sul telefono)
- ☑ **Il riassunto estrattivo non partiva** («ExceptionInInitializerError»): `Parlato.kt` e `Indizi.kt` usavano il segno
  `(?U)` nelle espressioni (le classi `\w`/`\b` in Unicode). Sul computer (Java) va, su Android (ICU) no: l'espressione non
  compila, e siccome stava nell'avvio dell'oggetto cadeva tutto l'oggetto. Ora i confini delle parole sono in un posto solo,
  `engine/Confini.kt` (`\p{L}`/`\p{N}` scritti a mano, che valgono uguali su tutti e due), e le maiuscole con
  `RegexOption.IGNORE_CASE`. `AndroidRegexTest` fa partire ogni oggetto del riassunto e cerca nei sorgenti i segni che ICU non
  conosce (`(?U)`, `UNICODE_CHARACTER_CLASS`, `\p{javaXxx}`, i quantificatori possessivi). Gli errori arrivano a Flutter
  causa per causa (`Errore.kt`, `Throwable.perLeggere`) e la prova li mostra per intero, da copiare (`SelectableText`).
- ☑ **Ricerca coi filtri senza parole** («se scelgo il verde non mostra niente»): senza parole, scelto un filtro, si sfoglia
  tutto quello che lo passa, dal più recente (`FiltroRicerca.sfoglia`, `FiltroRicerca.scelto`); con le parole i filtri
  stringono quello che ha trovato il motore. Una riga sola per tutti e due (`_riga` in `cerca.dart`). Test: `cerca_test.dart`.
- ☑ **«Annulla» più piccolo**, uno solo per tutta l'app: `molecole/pillola_annulla.dart` (`undoable`, `PillolaAnnulla`, era in
  `common.dart` che la riesporta): alta `Misura.bottoneBasso`, `Testo.etichetta`, `Ombra.sospeso`, il cerchio che si consuma
  `Misura.iconaPiccola`. Test: `pillola_annulla_test.dart`.
- ☑ **Le pillole in cima come quelle del Dock** («o uguali o sembra strano»): stesse isole (`Isola`, alte `Misura.isola`, a
  pillola) e stessi bordi, ora in un posto solo, `Isola.bordo(tondoPrima:, tondoDopo:)` (`Isola.lato` ai fianchi con le parole,
  `Isola.margine` dove c'è un tondo): li usano il titolo nella pillola e il campo della ricerca. Il titolo nella pillola è
  `Testo.titoloPillola` (18, prima 22); fermo in cima `Testo.titoloPagina` è 24 (prima 28). `Rientra` è alta quanto quello che
  mostra (`heightFactor: 1`). Test in `intestazione_test.dart`.
- ☑ **Cartelle nel tema scuro** («la rossa è uguale allo sfondo»): il dorso e la linguetta hanno un token loro,
  `Tinte.dorso` (nel chiaro come prima, una luce sotto il davanti; nello scuro più **chiaro** del davanti, `luceDorsoScuro`
  30%). Regola misurata in `segni_test.dart`: dorso/pagina ≥ 1,5:1 e dorso/davanti ≥ 1,25:1, per tutte le 16 tinte.
- ☑ **Rinomina dalla cartella aperta**: nell'intestazione il ⋮ (`TastoMenu`) con «Rinomina» (lo stesso `apriRinomina`; il
  titolo cambia subito, ascolta `Segni.nomi`) e «Togli cartella»: la cartella si richiude e torna `true` a `CartellePage`, che la
  toglie con `togliCartelle` (la stessa della barra delle scelte, in `scelta_cartelle.dart`) e mostra lì «Annulla».
- ☑ **Widget 2 × 1**: il tondo a destra (`widget_open_round` in `widget_wide.xml`, lo stesso fondo del tasto che detta, la
  freccia di «Apri») apre l'app; il resto fa uscire Transcri. 1 × 1 e 4 × 1 come prima.
- ☑ **La fila dei colori** (`molecole/fila_colori.dart`) resta solo per l'unione: i colori in gioco.
- ☑ **La rosa dei colori** (al posto della griglia 7 × 7, sempre in `molecole/tavolozza.dart`): al centro la ✕ (senza colore,
  7 nov; `PuntoColore.icona`), dentro
  8 colori più chiari (`Tinte.rosaDentro`, luce `Tinte.luceDentro`), fuori i 16 vivi (`Tinte.rosaFuori`, luce `Tinte.luceViva`:
  il giallo, l'azzurro e il lime una luce più chiari). **Il modello dei colori si è allargato**: con 7 tinte non si fanno 16 tinte
  a passo uguale, così `Tinte.tonalita` ne ha 9 in più (Lime, Pistacchio, Prato, Menta, Cielo, Indaco, Orchidea, Magenta,
  Rosa), **aggiunte in fondo**: «tinta:luce» già salvato resta lo stesso colore; `Colore.tinte` 16, `Colore.luci` 7. Le sette di
  prima restano dove sono, quindi il passo non è identico (da 15° a 28°, test). `Tinte.giro` le mette nell'ordine del giro dei
  colori (la ruota del «+», le cartelle). Distanze `Misura.rosaDentro` 56 / `rosaFuori` 104 (ogni puntino col suo tocco da 40).
  **Il movimento** (sua idea): aprendo, l'anello di dentro esce per primo e va piano (`Curva.standard` su tutto `Durata.rosa`),
  quello di fuori esce da sotto dopo `Curva.rosaRitardo` (30%) e va più svelto (`Curva.rosaFuoriApre`): arrivano insieme;
  chiudendo («Annulla», «Fatto», un tocco fuori) quello di fuori aspetta e rientra più svelto (`Curva.rosaFuoriChiude`), al
  centro insieme, poi il fumetto si chiude. **Il dito che scorre** (7 nov, sua: «scorrendo col dito ti dice il nome»): la rosa
  prende il dito appena tocca; il colore sotto si accende (`Misura.rosaSotto`) e in alto c'è il suo nome (il tuo · quello della
  tavolozza); lasciando lo sceglie, anche un tocco. Sotto, il campo piccolo del nome. Test: `rosa_test.dart`, `segni_test.dart`.
- ☑ **Via DM Mono** («non mi piacciono i suoi zeri»): gli orari, i conteggi e il tempo che scorre sono `Testo.orario` = Inter con
  le cifre tabellari (`FontFeature.tabularFigures()`: non ballano); `orarioStyle` (era `monoStyle`) lo usa nelle altre
  grandezze. Nel Floater il tempo della registrazione è `Caratteri.tempo` («tnum»). Tolti il carattere e la sua licenza da
  `assets/fonts` e da `pubspec.yaml`.

### Fuori dall'app
- ☑ Floater, colori: `Palette` (PillUi.kt) è solo la mappa token → ruoli della pillola, nessun colore scritto; usa sempre i token del tema SCURO (il pannello è sempre scuro). Provato: esce, torna a casa.
- ☑ Floater · stati (B9): pausa (grigia, «in pausa» in alto: c'era già), Lavora col tasto coi suoi colori (non più la rotella), «Minuti finiti» scritto sotto l'orologio. Testi da `Caratteri.kt` (gli stili di testo per il Kotlin).
- ☑ Scheda del vocale: in alto titolo + «rimpicciolisci»; il testo scorre con la sfumatura; in fondo solo icone (nei Pensieri, cestino). Via la X.
- ☑ Vocale da parte: «rimpicciolisci» lo mette da parte (`PillService.daParte`), la pillola mostra la rientranza con l'iconcina; il pannello compatto si allarga e in cima ha la riga (onda, titolo, ⤢ riapre, X toglie); resta fuori finché c'è. **Da provare dal vivo** (serve un vocale condiviso).
- ☑ CasaInBasso: colori dai token (Palette)
- ☑ Lo scatto del Floater (6 nov, sua richiesta: la carta dell'ultima trascrizione «si apre lentissima, falla come la pillola»):
  `Scatto.kt` (`Scatto.molla`, numeri in `Durate.kt` `SCATTO_*`: smorzamento 0,68, rigidità 400; `Scatto.svelto` = `Durate.VELOCE`
  per chiudere). Lo usano la pillola che diventa pannello e il pannello che cresce (largo e alto); la carta non cresce più da sola
  (erano due molle in fila): entra a tutta altezza e la scopre il pannello. `FloaterTest`.
- ☑ Il cassetto che si fonde con la carta (6 nov, sua richiesta): `CaretFuso.kt` (una forma sola che va dalla pillola del
  cassetto alla carta con `Scatto.molla`, e torna con `Scatto.svelto`; il contenuto dal 60%), la fila fino a tre cassetti
  (ultima · vocale · pausa) con le regole in `Cassettiera.kt`; la pausa lunga (`Durate.PAUSA_SI_APRE`) apre da sola la bozza
  (`Bozza.kt`, una richiesta per pezzo; i pezzi in `Spezzoni.kt`). Mentre si fonde il pannello la segue senza la sua molla
  (`svc.morfa`). `CassettieraTest`.
- ☑ La notifica mentre è fuori (6 nov): «Chiudi» → «Richiama», in `AvvisoFuori.kt` (testo e tasti, «Richiama» sempre l'ultimo,
  cioè il più a destra; con un tasto solo Android lo mette comunque a sinistra). Lo stesso `rientra()` di prima. `FloaterTest`.
- ☑ Widget: «Richiama»; colori da `WidgetColori.kt` (dai token, gli stessi per widget e anteprima): la pillola colorata col fondo (a tinta unita: il launcher non colora un gradiente da codice), Transcri disegnato coi suoi due toni. Via gli sfondi a gradiente fissi. **Da vedere sulla Home.**
- ☑ Widget 4 × 1, tasto «Detta subito» (3 nov): accanto ad «Apri», tondo, stesso fondo e stessa tinta (`tasto` in
  `TranscriWidget.kt`, lo usano tutti e due), il microfono della notifica. C'è solo con Transcri a casa: lui esce dal
  tasto già in ascolto (`PillService.start(…, record = true)` → lo stesso `listen` dell'app). Senza permessi o chiave
  si apre l'app, come col tocco normale. **Da vedere sulla Home** (a 280 dp la scritta resta stretta).
- ☑ Richiamarlo mentre registra non butta niente (3 nov): widget, casa in basso, X, «Richiama» nella notifica →
  si ferma e trascrive come col ✓ (`PillService.rientra()` quando non si sa dove rientrare); nel nido dell'app
  continua ad ascoltare nel Dock. Prima, senza la posizione del widget e con «Chiudi», l'audio restava solo «in attesa».

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

## Giro 6 (6 nov): leggere, l'incavo, le tre grane

- ☑ **Il carattere per leggere**: le trascrizioni e le note (le schede, la trascrizione aperta, la nota mentre la scrivi,
  il riassunto, la prova del riassunto estrattivo) sono in **Onest** (giro 7: Literata tolto, con la sua prova
  e `SceltaLettura`). 15/24 (`Testo.lettura`), sulle schede 14/21 (`Testo.letturaScheda`). Un posto solo:
  `lib/ui/ds/testo.dart`. L'interfaccia resta in Inter, i numeri che scorrono restano `Testo.orario` (tabellari).
  `CampoFormattato` mette sempre le lettere per leggere (del campo prende solo il colore), `Anteprima` anche.
  Caratteri in `assets/fonts` (variabili, da github.com/google/fonts, con le licenze OFL accanto).
- ☑ **Spazio tra i paragrafi** (8): Flutter non ce l'ha. Una riga vuota (un «a capo» subito dopo un altro) si disegna alta
  `Testo.spazioParagrafo` invece di 24 (`Testo.rigaVuota`, in `Formattato.span`): gli stessi caratteri, le posizioni non
  cambiano. Si vede dove il testo si legge e basta (schede, riassunto); nei campi dove scrivi l'altezza delle righe è
  fissa (il «montante» del campo, `forceStrutHeight`), quindi lì la riga vuota resta intera e il cursore non salta.
  ☑ La trascrizione aperta (`trascrizione_aperta.dart`) ora passa `Testo.lettura(context)` al campo; la scheda
  `Testo.letturaScheda(context)` all'anteprima.
- ☑ **L'incavo del nido** (Transcri fuori): via il contorno tratteggiato; il nido resta un pozzetto appena accennato,
  `Ombra.incavo` (**rifatto al giro 7**, vedi sotto). Solo in Flutter: nel Kotlin non c'è
  un nido tratteggiato (il widget mostra lui sbiadito con gli occhi chiusi, la casa in basso è una pillola di fumo).
- ☑ **Tre grane** (Argomenti, Frasi, Parole chiave; via «Argomenti specifici»): i pezzi sono quelli medi del motore
  (`Segmentation.mediumCuts`, i cambi di argomento veri, gli stessi degli album); le frasi chiave sono una per pezzo, le
  parole chiave quelle di sempre. Tolta la grana larga dal risultato (`wide`). **Lo stesso colore = cose simili**: il motore
  dà a ogni pezzo un gruppo di senso (`NoteTopics.groups`, la regola degli album dentro la nota: soglia `profile.pair`),
  e i pezzi dello stesso gruppo, anche lontani, hanno lo stesso colore a tutte e tre le grane.

## Giro 6 (6 nov): titoli, schede, privata, filtri, cartelle (Figma D5)

- ☑ **Il titolo delle trascrizioni**: `titolo` salvato col nativo (`Transcription.titolo` in `Store.kt`, `Entry.titolo`;
  quelle di prima non ce l'hanno: compatibile), scritto con `segnaHistory` (`Segni.intitola`, vuoto lo toglie). Unite, tengono
  quello della prima (`RitocchiTest`). Senza titolo l'app ne propone uno (`core/titoli.dart`, `Titoli.proponi`): quando la
  scheda si vede, una alla volta in fondo, il riassunto estrattivo (`Estratto`) sceglie le frasi e il titolo è la più corta,
  tagliata a 5 parole; si salva, e alla fine della fila si rilegge una volta. Senza modello si smette fino al prossimo avvio
  e resta l'inizio del testo (`Titoli.di`). Le private non si propongono e senza titolo dicono «Privata». Test: `titoli_test.dart`.
- ☑ **La scheda** (sua idea): in fondo una fascia di due righe, il titolo col cestino a destra, sotto l'ora e le iconcine
  senza parole (da dove arriva; il modo solo se l'AI l'ha ripassata: pulita, riassunto). Tutte alte uguali; l'anteprima
  mostra le righe intere che ci stanno (col testo grande ne restano meno). Via `SchedaTrascrizione.fascia`.
- ☑ **La privata**: macchie molto sfocate dei colori della scheda (`Tinte.macchie`; senza colore, neutre) che girano in
  `Durata.giroPrivata` (7 s), gradienti e non filtri di sfocatura; ferme con «riduci le animazioni»
  (`MediaQuery.disableAnimations`). Il lucchetto al centro, la fascia col titolo resta.
- ☑ **Il colore nella trascrizione aperta**: il titolo a sinistra (toccato si cambia lì: `molecole/titolo_modificabile.dart`,
  campo già pronto + «Annulla»/«Fatto», lo stesso per il nome della cartella), a destra sempre lì `atomi/cerchio_colore.dart`:
  senza colore l'invito tratteggiato col «+», col colore il tondo con un anello sottile staccato. Il foglio della
  trascrizione è ora un file suo, `trascrizione_aperta.dart` (`openEntry`), fuori da `trascrivi.dart`.
- ☑ **I filtri in Trascrivi** (via dalla ricerca, che tiene solo le parole: via `filtri_ricerca.dart`, `FiltroRicerca.sfoglia`):
  `core/filtro_voci.dart` (`FiltroVoci`, `quanti`), `molecole/filtri_voci.dart` (una fila che scorre: Tutte, WhatsApp, Altre app,
  i modi, i colori col puntino: `ChipFiltro(punto:)`). Lo stato è `TrascriviPage.filtro` (e i colori `TrascriviPage.colori`);
  la shell li passa all'`Intestazione(filtri:, quantiFiltri:)`: ferma, la fila sta sotto il titolo; scorrendo si raccoglie in
  una pillola al centro (l'icona del filtro, o il numero di quelli accesi); toccata, la fila riscende in un'isola sotto le
  pillole (si richiude toccandola, trascinando la pagina o tornando in cima). Cambiati i filtri la lista torna in fondo, sulle
  più nuove (cresce dal basso). Nessuna che passi: «Niente con questi filtri».
- ☑ **Le pillole non coprono la data in cima** (sua segnalazione): arrivati in cima scorrendo (il giorno più vecchio) la lista
  di Trascrivi lascia lo spazio delle pillole (`Intestazione.sottoPillole`, lo stesso della data che resta in cima). Le altre
  pagine in cima tornano barra, quindi lì le pillole non ci sono. Test in `intestazione_test.dart`.
- ☑ **Le cartelle si aprono lì** (sua scelta: «un mix tra si allarga in orizzontale e fascia del colore»):
  `molecole/fascia_cartella.dart` (`FasciaCartella`): al posto della riga della cartella una fascia larga quanto la pagina nel
  colore del dorso (`Tinte.dorso`), che parte dal riquadro della cartella e si allarga (`Durata.lenta`); nome (si rinomina lì),
  quante sono, la X, le schede normali in fila (`FilaSchede`; cestino con «Annulla», tocco apre). Una sola aperta; tenendo
  premuta una cartella si sceglie e la fascia si chiude. `GrigliaCartelle(aperta:, fascia:)`. Tolte `cartella_aperta.dart`,
  `si_apre_da.dart`, `TrascriviPage(cartella:)` e «Togli cartella» dal ⋮ (resta nella barra delle scelte). Test: `cartelle_test.dart`.
- ☑ **Widget 2 × 1** (sua richiesta: «se è piccolo il testo è inutile»): in `WidgetSettings` «Nel 2 × 1»: «Testo» o «Apri l'app».
  Con «Apri l'app» il 2 × 1 ha Transcri e il tondo che apre l'app (anche con la scritta spenta: `WidgetLook.dueXUno`); con
  «Testo» le parole e niente tondo. L'anteprima segue. `WidgetLookTest`. **Da vedere sulla Home.**

## Giro 7 (6 nov): togliere invece di aggiungere

- ☑ **Filtri in tre file** («sono filtri diversi, combinabili»): in Trascrivi il tasto «Filtri» (`molecole/tasto_filtri.dart`)
  è la prima delle azioni in cima, allo stesso posto nella barra e nelle pillole (via la pillola al centro e la fila che
  scendeva); col numero dei filtri accesi nel puntino. Apre un fumetto (`PannelloFiltri`) con tre file col loro nome:
  **Da dove** (WhatsApp · Dettate · Altre app), **Come** (Fedele · Pulita · Riassunto), **Colore**. Dentro una fila basta uno
  (O), tra le file valgono tutte (E): `FiltroVoci` con tre insiemi (`core/filtro_voci.dart`). Si vede solo quello che
  serve (`FiltriPossibili`: lascia passare qualcuna ma non tutte; gli accesi restano sempre); niente da filtrare: niente
  tasto. Sotto il titolo solo i filtri accesi (`FiltriAccesi`), da sinistra, con la ×, vanno a capo invece di scorrere.
  Il collegamento con la lista (per la shell e i test) sta in `filtri_trascrivi.dart`. `modi` → `nomiModi`.
- ☑ **Cartelle via dal Dock**: la pagina c'è ancora (`CartellePage`), si vede solo con Prove → «Mostra le cartelle»
  (`CartellePage.mostra`, spento). I colori come filtri ne fanno le veci.
- ☑ **Titoli nascosti** (finché non decide: con l'AI o niente): Prove → «Titoli automatici» (`Titoli.automatici`, spento).
  Spenti, la fascia della scheda è una riga (ora, iconcine, cestino, centrati), la trascrizione aperta non ha il titolo (in
  cima il giorno col cerchio del colore) e non se ne propongono. Il titolo salvato e il codice restano.
- ☑ **La privata**: le macchie sono tagliate dentro la copertura (`ClipRect`): la fascia non le vede più muoversi dietro.
  Si fermano mentre la tieni premuta (`CoperturaPrivata.ferma`), con un'altra pagina sopra (la trascrizione aperta) e con
  l'app in sottofondo (`AppLifecycleListener`).
- ☑ **Schede più staccate dalla pagina** («sembrano molto simili»): nel `Token.kt` la scheda è il neutro al tono 89 di
  giorno e 18 di notte (prima `surfaceContainer`, 94 / 12): almeno 1,25:1 con ogni colore del telefono (`TokenTest`), il
  testo resta leggibile (anche il secondario e il rosso). Il salmone di Flutter copiato (`#ECDCD9` / `#332A28`,
  `test/contrasto_test.dart`). **Da riportare in Figma B2** (qui il calcolo ora si stacca da quello di Figma).
- ☑ **L'incavo si vede** (anche al buio): `Ombra.incavo(luce)` è un pozzetto più scuro dell'isola, più fondo in alto; di
  giorno nero 16% → 8% → 4%, di notte nero 50% → 35% con un filo di luce bianca (12%) sul bordo di sotto. Misurato in
  `lettura_grana_test`: almeno 1,3:1 dall'isola in alto, 1,15:1 a metà.
- ☑ **Via Literata**: i file, la licenza, il `pubspec`, la prova «Leggere in Literata», `SceltaLettura`. Resta Onest 15/24.
- «Seleziona» resta nel ⋮ e tenendo premuta una scheda (anche con le Cartelle nascoste).

## Giro 8 (7 nov): rifinitura

- **Offusca** (non chiude a chiave, copre): `Offusca` in `atomi/copertura_privata.dart` dà nome e icona (occhio chiuso /
  «Mostra») a menu, barre e scelta; `BottoneOffusca` nelle barre in fondo (trascrizione aperta, nota). Il segno nel
  codice resta `privata`. La scheda offuscata mostra il suo **titolo** (`Titoli.di`; senza titolo «Offuscata»). Le
  **note** si offuscano anche loro (`Note.privata`, salvato nel JSON delle note, le vecchie: false): copertura neutra
  (`CoperturaPrivata.neutra`) sotto il titolo, «Offusca» nella scelta e in alto nella nota; la ricerca le salta.
- **Scheda**: fascia riga 1 solo il titolo; riga 2 l'ora, le iconcine (fonte, AI, `SegnoAuto` se il colore l'ha messo
  l'app) e il cestino a destra.
- **Rosa**: i colori tuoi (nome, regola o trascrizioni) pieni; i liberi più piccoli (`Misura.rosaLibera`) e velati
  (`Misura.rosaLiberaVelo`). Sotto il nome la **regola** («Metti qui le trascrizioni che parlano di…») e «Offusca
  sempre questa etichetta» (`RegoleColori`, canale `regoleColori` / `salvaRegola`).
- **Conferme**: una sola (`Conferma`): a destra il principale pieno alto, a sinistra il secondario solo testo. Rosa
  («Fatto»), titolo («Fatto»), «Rinomina», «Rimuovi» la chiave, «Apri» il permesso, «Salva» il testo del modo; «Fatto»
  della nota e il fondo dell'introduzione usano lo stesso `Bottone` pieno alto.
- **Introduzione** (`avvio.dart`, provata in `test/onboarding_test.dart`): non resta mai sul bianco se il nativo non
  risponde; la chiave rifiutata non ritorna dagli appunti e se ne può incollare un'altra; il principale è spento col
  campo vuoto; Groq che non si apre lo dice; la prova butta la voce se torni indietro mentre ascolta, scorre su un
  telefono basso, il fondo non va a capo (`FittedBox`) e non si prende più tutta l'altezza (`heightFactor`).
- **Nido vuoto**: buio e tratteggio con la sagoma di Transcri (`TranscriCorpo.forma`), grandi quanto lui nel nido.
- **A pezzi** (movimenti): la barra in cima che si ritira (altezza e velo da un movimento solo), il giorno che si apre
  e la sua freccia (stessa curva).
- **Nel Kotlin (stesso giro, agente K)**: il Floater si muove con una coreografia sola (`Coreografia.kt`: un solo
  avanzamento per tutti i pezzi, niente tempi propri); le regole dei colori (`RegoleColori.kt`, `engine/ColoreRegole.kt`,
  canale `regoleColori` / `salvaRegola`): «Colora da sola» colora solo i colori con una regola e solo quando è sicuro,
  «offusca sempre» la offusca; i titoli (`Titolatore.kt`) anche sulle offuscate, con `titoloUtente` (il titolo l'hai
  scritto o tolto tu: «Rifai i titoli» non lo tocca).

## Giro 9 (10 nov): Kotlin, agente K

- **Mai tagliato** (`Pulitura.kt`, `PulituraTest`): la pulizia va a pezzi (8000 caratteri, tra le frasi), il tetto di
  token è proporzionale al pezzo (× 1,6 più il ragionamento) con `reasoning_effort` corto; una risposta `length` o vuota
  non si accetta mai: si riprova col tetto doppio (al modello che non ragiona, se Groq l'offre: `Store.riservaPulizia`),
  poi il pezzo si divide in due (due volte), e in fondo restano le parole dette di quel pezzo. Titoli: un nuovo
  tentativo col tetto largo, se no nessun titolo (mai a metà). Whisper: nessun pezzo saltato (`Groq.tuttiIPezzi`).
- **Il Floater si richiude** con lo stesso scatto dell'apertura, all'indietro, in `Durate.NORMALE` (`Scatto.richiude`):
  in `VELOCE` tornava al punto senza che si vedesse.
- **Regole dei colori**: senza una regola scritta vale il nome (`RegoleColori.effettive`, `daNome` nel canale);
  «offusca sempre» acceso offusca anche quelle che hanno già il colore (`salvaRegola` → `{offuscate}`); «colora le sue
  di prima» (`coloraRetro` → `{ids}`, `annullaColoraRetro`, l'avviso `coloratiRetro`). Le offuscate hanno il titolo per prime.

### Giro 10 nov (lucidatura v3)

- **Etichette** (Impostazioni, sotto «Colora da sola»): `ui/etichette.dart` + `molecole/riga_etichetta.dart`. La rosa
  tiene solo colore e nome; qui per ogni colore con nome o in uso: puntino, nome, quante, la regola (parte col nome,
  uguale al nome vale vuota) e «Offusca sempre» (accesa copre anche quelle di prima: «Offuscate N · Annulla» rimette
  in vista solo quelle che lo erano). Il primo nome nella rosa chiama `coloraRetro` → «Ho colorato N come «nome» ·
  Annulla» (`annullaColorati`, lo stesso per l'evento nativo `coloratiRetro`).
- **Offuscate senza titolo**: mai «Offuscata», l'ora tenue (`Titoli.inAttesa`: «Trascrizione delle 21:40», «Nota delle…»).
  `hm` sta in `core/orario.dart` (una sola, anche per le impostazioni).
- **Prova dell'introduzione**: dopo `Durata.provaDiLato` Transcri va sul bordo col fumetto «Io sto qui…»; tenuto premuto
  (o «Stop») si spegne; pronta, la scheda «Ecco la tua prima trascrizione» al centro, «Entra» la fa volare nella lista
  (`molecole/volo_prima.dart`, `Durata.voloPrima`, `attesaVoloPrima`) e Transcri atterra nel nido.

### Ultimo giro 10 nov (sua lista: «è quasi tutto pronto»)

- **Etichette**: in cima «Le etichette sono i colori della rosa…»; la regola vuota non riscrive il nome (si legge come
  suggerimento «di cosa parlano (vuota: «nome»)»: era il nome «doppio»), due colori con lo stesso nome lo dicono
  («Due colori con questo nome: questo è Blu 3»). Il cestino della riga apre `molecole/togli_etichetta.dart` (via nome,
  regola e «Offusca sempre»; «Togli il colore dalle trascrizioni» a scelta). «Proponi etichette»: a Groq solo i titoli
  (`Proposte.kt`, `Groq.etichette`), anteprima con le spunte (`molecole/proposte_etichette.dart`), colori liberi e
  distinti (`Tinte.lontane`, `Tinte.giroIntero`), prima la regola poi il nome. Un nome nuovo nella rosa: Groq propone
  la regola in fondo (`Groq.regolaPer`, scritta solo se non ne hai una: `Proposte.daSalvare`). Risposte corte mai
  tagliate: `Risposta.primaIntera` (anche il titolo).
- **Una cornice per i dialoghi**: `molecole/dialogo.dart` (`Dialogo`: titolo, contenuto, `Conferma`), usata da
  «Rinomina», «Togli» e «Proponi».
- **Prova dell'introduzione**: si parte anche toccando lui; l'anello della voce staccato dal corpo
  (`Misura.anelloVoce`/`anelloVoceStacco`, il vuoto è `col.pagina`); di lato diventa la pillola del bordo
  (`atomi/pillola_bordo.dart`, `Misura.pillolaLarga`/`pillolaAlta`/`pillolaVoce`); il titolo sta sopra la scheda,
  che è la `SchedaTrascrizione` vera; con «Entra» la pillola se ne va. Il fumetto non prende i tocchi.
- **Scheda, la fascia**: l'ora e le iconcine nel loro spazio, il cestino sempre a destra e centrato con l'ora (prima
  `Flexible` + `Spacer` si dividevano lo spazio e il cestino si spostava); `test/scheda_fascia_test.dart`.
- **Floater**: aprire e chiudere di nuovo come in 95c2384 (una forma sola `Blob` tra la pillola e il pannello,
  larghezza e altezza dallo stesso scatto; chiudendo il contenuto non si rimisura). Titoli: permesso
  `ACCESS_NETWORK_STATE` e `TitoliRegole.inRete` che non si ferma mai su un errore.

### Giro finale 10 nov (Floater fluido, Condividi, etichette)

- **Floater**: da un cassetto all'altro la carta non si chiude più, cambia forma (`Coreografia.passo` → `Passo.CAMBIA`,
  uno scatto `cambio` con `Scatto.molla`: altezza da A a B, il ponte che scivola, i colori dei cassetti, il contenuto
  che passa, `Coreografia.tra`/`esce`/`entra`). L'altezza del pannello segue passo passo anche aprendo e cambiando
  (non rincorre la larghezza). Il bordo di «Stai rispondendo» è lo stesso Path di carta + ponte + cassetto
  (`formaFusa(…, conCassetto = true)`, `Stroke`). Vocali: «Vocali di WhatsApp (2)» (`Provenienza.testata`) e la X
  della testata che li toglie tutti (`togliVocali`); ognuno ha ancora la sua.
- **Condividi**: una voce sola, «Trascrivi» (via le scorciatoie, `ShareShortcuts.ritira`); quello che non è pronto
  (il file dell'altra app, la chiave nel Keystore) si aspetta con `Pronto.attendi` / `Store.chiavePronta`.
- **Etichette**: «Proponi etichette» manda a Groq anche i nomi che hai (non li doppia); «Proponi regole» propone una
  regola migliore per ognuna (`Proposte.perRegole`/`leggiRegole`, la stessa anteprima con «Applica»).
- **Colora da sola propone**: niente più colori messi in silenzio (via «colorata», «coloratiRetro»). Il nativo tiene
  le proposte (`ProposteColore.kt`, `Store.proposteColore`/`rifiutateColore`); in cima a Trascrivi «Proposte di colore
  (N)» con ✓ / ✕ e «Accetta tutte» (`SezioneProposteColore`). Rifiutata non torna.

### Dopo il giro finale 10 nov (sue prove)

- **Proposte di colore fuori dalla lista**: stanno con le registrazioni in attesa sotto il titolo di Trascrivi
  (`RigaInAttesa`): l'orologio giallo «2 registrazioni in attesa di rete» e, accanto, la scintilla di «Colora da sola»
  (`Icons.auto_awesome_rounded`) «3 proposte di colore», ognuno solo se ha qualcosa; «Riprova» solo con quelle in
  attesa. Scorrendo, nella pillola del titolo, `InAttesaCorto` (⏱ 2, scintilla 3). Ogni segno apre la pagina «Da
  sistemare» (`ui/da_sistemare.dart`, `MaterialPageRoute`, la cornice delle sottopagine) sulla sua parte
  (`DaSistemare.attesa`/`proposte`, `Scrollable.ensureVisible`): prima «In attesa di rete» (`SezioneInAttesa`), poi
  «Proposte di colore» (`SezioneProposteColore`, «Accetta tutte»); toccato un titolo si apre la trascrizione sopra la
  pagina (`openEntry`), poi ✓ / ✕. Vuota, lo dice e resta aperta. Il foglio di prima (`foglio_in_attesa.dart`) non c'è
  più. `TrascriviPage.tutte` tiene tutte le trascrizioni, `ProposteColore.con` le conta. Il numero del tasto «Filtri»
  è ora un atomo, `atomi/contatore.dart`.
- **Il titolo in cima** ha una misura sola, `Testo.titoloPillola`, ferma e scorrendo.
- **«Offusca sempre» retroattivo**: acceso copre tutte quelle dell'etichetta (anche se era già acceso: si rimettono in
  pari), spento le rimette tutte in vista (`RegoleColori.daCambiare`, `salvaRegola`). A mano una si può ancora offuscare
  o mostrare; vale fino al prossimo cambio dell'etichetta.
- **Condividi**: torna la scorciatoia in cima (condivisione diretta), solo «Trascrivi» (`share_shortcuts.xml` con un
  `share-target`, `ShareShortcuts.publish`); si ritira la vecchia «pensiero». `Pronto.attendi` resta.
- **Prova dell'introduzione con la pillola vera**: col permesso di stare sopra le altre app parte la pillola nativa già
  in ascolto dal posto di Transcri (`Core.startPill(ascolta:)`, `record` nel canale); la trascini, la tieni premuta per
  spegnerla, o «Stop». Fermata da lei vale come «Stop». Senza permesso lo chiede (`chiediSopraLeApp`); con «Non ora»
  ascolta nella pagina come prima. «Entra» (o «Salta», indietro) la ritira (`Core.stopPill`).

### Giro 11 nov (le sue prove sul telefono)

- **Le proposte di colore non arrivavano**: una regola (frase corta) contro una trascrizione non arriva mai alla soglia di
  due pezzi dello stesso album (`pair`, 0,80 o 0,94 coi modelli veri). Ora ha la sua, quella della ricerca e delle
  categorie (`ColoreRegole.decidi(sogliaRegola:)` = `EngineProfile.cercaMinimo`), e regole ed esempi si confrontano per
  quanto superano ognuno la sua soglia. Su tutte (anche quelle di prima) si rifanno dopo `Durate.ATTESA_PROPOSTE` da
  un cambio delle etichette, e all'avvio solo se etichette o modello sono cambiati (`Store.proposteImpronta`). Senza il
  modello degli argomenti «Colora da sola» lo dice nella sua riga.
- **Prova dell'introduzione a passi**: la pillola vera sta sul bordo destro all'altezza di Transcri (`place`), il fumetto
  accanto: «Sono qui. Leggi la frase al centro.», dopo `Durata.provaPasso` «Ora tienimi premuto per fermarmi.»; al
  centro «Leggi ad alta voce» e una frase di otto secondi; a `Durata.provaFerma` si ferma da sola. «Salta» sempre in basso.
- **La pausa del Floater**: il cassetto si apre solo quando la trascrizione della pausa è arrivata; dentro «…» e gli ultimi
  5 secondi circa (`Bozza.CODA` 80, da una parola intera).
- **«Da sistemare»**: una riga in cima dice cos'è; in Impostazioni → Prove (solo coi dati finti) «Da sistemare, di
  prova» la riempie (`Core.setFakeWaiting`, `ProposteColore.mostraFinte`: finte, mai al nativo).
- **Note offuscate**: tre parti, titolo, anteprima, informazioni; la copertura sta esattamente sull'anteprima (alta
  quanto lei, larga quanto la scheda), con lo stesso arrivo delle trascrizioni (`CoperturaPrivata.arriva`).
- **Floater, «Butta»**: il pannello si richiude con lo scatto di sempre (`collapse`), invece di cambiare forma di colpo.
- **Widget**: via il bordino chiaro di 1 px (il fondo della forma che ritaglia è trasparente).

### Giro 11 nov, seconda prova

- **Floater, «Butta»**: dopo un vocale condiviso la pillola restava «fuori solo per lui» (`outForShared` non si spegneva
  mai) e, chiuso il pannello, tornava a casa da sola: ora toccarla (o aprirla) lo spegne.
- **Note offuscate**: la copertura arriva più calma (vedi sotto, `Durata.copre`).
- **Proposte di colore**: «Scarta tutte» accanto ad «Accetta tutte» (lo stesso bottone, sotto il titolo; `rifiutaTutte`,
  `ProposteColore.rifiutaTutte` nel Kotlin). Nessun «Annulla», come «Accetta tutte».
- **Prova dell'introduzione**: non si ferma più da sola. Il fumetto: «Sono qui e ti ascolto. Leggi la frase qui sotto.»
  con la frase sotto, grande (`Testo.titoloSezione`); finita la frase (la voce tace da `Durata.provaSilenzio`, o dopo
  `Durata.provaFatta`) «Ora tienimi premuto, oppure aprimi e tocca Stop.»; fermata «Ricevuto: trascrivo…». La prima
  pagina dice quello che succede: «Toccalo: vola sul bordo…», «Tienilo premuto e parla… per fermarlo tienilo premuto di
  nuovo, o aprilo e tocca Stop».
- **Widget, «Apri»**: la freccia nel riquadro (sembrava un link) è diventata la freccina «›» (`ic_widget_open`, Material
  arrotondato), nel 4 × 1 accanto ad «Apri» e nel 2 × 1 nel tondo.

### Giro 11 nov, terza prova

- **Floater, «Butta»**: il pannello resta aperto e torna a riposo, col microfono. Butta, pausa, lo stato e la pulizia se ne
  vanno con la voce (`Coreografia.conVoce`: finita la registrazione seguono lei, non spariscono), che scende con
  `Scatto.richiude`; il pannello si stringe e si abbassa passo passo con loro.
- **Prova dell'introduzione**: la pillola sul bordo destro, in alto nel palco (`_Palco.alto`); sotto di lei il fumetto con
  la freccia in su, sotto ancora la frase. Le fasi le fa avanzare lui («Avanti» nel fumetto): «Sono qui. Leggi la frase
  qui sotto.» (con «Puoi fermarmi quando vuoi: tienimi premuto.»), «Fatto? Ora tienimi premuto per fermarmi, oppure
  aprimi e tocca Stop.», «Ricevuto: trascrivo…». Via la voce che tace e il tempo.
- **Offuscare, più ricco** (`Offuscabile` in `atomi/copertura_privata.dart`, uno solo per trascrizioni e note): il testo si
  sfoca piano (`Velo.sfocatura`, `ImageFiltered` solo durante il movimento) e sbiadisce, la copertura arriva e le macchie
  si condensano dal grande e chiaro al loro posto, una dopo l'altra (`Velo.macchieDa`/`macchieChiare`/`macchieDopo`);
  al contrario rimettendo in vista. `Durata.copre` (700 ms), `Curva.scambio`.
- **Schede, una forma sola** (`molecole/corpo_scheda.dart`, `CorpoScheda`): in alto il contenuto che si offusca, in fondo
  titolo e informazioni sempre in vista. Le note come le trascrizioni: il titolo è sceso in fondo, con l'ora.

### Giro 11 nov, quarta prova: la prova guidata

- **La pillola a sinistra**: il lato si ricavava dal centro di Transcri (`place`), che sta due punti a sinistra del centro
  dello schermo (il suo `Padding` a destra). Ora la prova passa `guida` (l'altezza, in frazione dello schermo): il nativo
  (`PillService.guidata`) la mette sul bordo destro, a quell'altezza, senza salvarla (`Store.pillRight/pillY` restano i
  suoi), non la lascia trascinare, e nel pannello c'è solo il tasto grande (niente butta, pausa, cassetti, modi).
- **L'onda a scatti**: la pagina della prova si ridisegnava tutta a ogni volume della voce; ora ascolta `_vista`, che cambia
  solo con fase, secondi, pausa ed errore (l'onda e l'anello leggono il volume da soli).
- **Guidata**: mentre ascolta e trascrive il resto della pagina si spegne (`Velo.guida`); restano chiari la pillola, il
  fumetto (sempre allo stesso posto, cambia con una dissolvenza in `Durata.lenta`) e la frase. Fasi: «Leggi la frase qui
  sotto.» («Avanti»), «Ora tienimi premuto per fermarmi, oppure aprimi e tocca Stop.», fermata «Ricevuto: trascrivo…»,
  poi la scheda senza cestino (`SchedaTrascrizione.onDelete` facoltativo): solo «Entra».

### Giro 11 nov, senza scatti

- **I segni accanto al titolo** (`RigaInAttesa`, `InAttesaCorto`): l'orologio e la scintilla arrivano e se ne vanno
  sfumando e allargandosi, il numero cambia con una dissolvenza (`AnimatedSize` + `AnimatedSwitcher`, `Durata.normale`);
  nella pillola di Trascrivi `accanto` c'è sempre (anche vuoto) e porta da sé il suo stacco.
- **Floater nella prova guidata**: cassetti, butta, pausa e pulizia se ne vanno con `libero` (`Modifier.comparsa`,
  `Scatto.richiude`), come quando si butta.
- **Il volume a Flutter** al più ogni `Durate.VOCE_MS` (`InoltroVoce`); un cambio di stato parte subito.
- **Ancora**: il titolo della fascia delle schede (`CorpoScheda`) cambia piano con l'offuscare; nella prova il tempo,
  l'onda e l'avviso arrivano con un `AnimatedSize`.

