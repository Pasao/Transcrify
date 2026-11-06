import 'dart:async';

import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/titoli.dart';
import 'common.dart';
import 'molecole/apri_collegamento.dart';
import 'molecole/cursore_voce.dart';
import 'molecole/fumetto.dart';
import 'molecole/scelta_colore.dart';
import 'molecole/titolo_modificabile.dart';
import 'molecole/voce_in_barra.dart';
import 'theme.dart';
import 'transcri.dart';

/// Il testo intero, aperto dal basso: si può cambiare e si salva da solo.
/// In cima (con «Titoli automatici», prove) il titolo, toccato si cambia lì; a destra, sempre nello stesso posto, il cerchio del colore;
/// sotto il giorno, il modo e da dove arriva. In fondo la voce, il cestino e copia: con i testi lunghi sono sempre lì.
/// Apre una trascrizione nella sua scheda (da Trascrivi, da una cartella o da una ricerca). [onDelete] arriva a scheda
/// chiusa; senza, la trascrizione si elimina subito.
void openEntry(BuildContext context, Entry e, {Future<void> Function()? onDelete}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _EntrySheet(
      entry: e,
      onDelete: () async {
        Navigator.pop(sheet);
        if (onDelete != null) return onDelete();
        await Core.deleteEntry(e.at);
        Core.refresh();
      },
    ),
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.entry, required this.onDelete});

  final Entry entry;
  final VoidCallback onDelete;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final _text = CampoFormattato(text: widget.entry.text);
  final _sheet = DraggableScrollableController();
  final _focus = FocusNode();

  /// Il testo com'è salvato: quello che arriva a voce si riconosce perché lo allunga.
  late String _saved = widget.entry.text;

  /// Il suo colore: il cerchio in alto lo cambia (la tavolozza spunta lì), e si vede subito.
  late Colore? _colore = widget.entry.colore;

  /// Il suo titolo (null: non ne ha, si legge l'inizio del testo). Cambia toccandolo, o se ne arriva uno proposto.
  late String? _titolo = widget.entry.titolo;

  /// La rosa sopra il cerchio: il colore nuovo si vede subito; «Annulla» (nella rosa o nella pillola) lo rimette.
  void _scegliColore(Rect dove) => apriSceltaColore(
    context,
    sopra: dove,
    prima: {widget.entry.at: _colore},
    onCambiati: (ora) {
      if (mounted) setState(() => _colore = ora[widget.entry.at]);
    },
  );

  /// Il titolo nuovo, salvato subito; vuoto lo toglie.
  void _intitola(String titolo) {
    setState(() => _titolo = titolo.isEmpty ? null : titolo);
    Segni.intitola(widget.entry.at, titolo);
  }

  Timer? _saving;

  @override
  void initState() {
    super.initState();
    _text.addListener(_edited);
    Core.addListener(_reload);
    // Scrivendo serve tutto lo spazio che resta sopra la tastiera.
    _focus.addListener(() {
      if (_focus.hasFocus) _sheet.animateTo(0.94, duration: Durata.normale, curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _saving?.cancel();
    _save();
    Core.removeListener(_reload);
    Core.refresh();
    _text.dispose();
    _sheet.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// L'ultimo punto del cursore: Flutter lo cancella quando la tastiera si chiude, ma la voce deve entrare lì.
  int _cursore = -1;

  void _edited() {
    if (_text.selection.isValid) _cursore = _text.selection.end;
    _saving?.cancel();
    _saving = Timer(const Duration(milliseconds: 500), _save); // ds:eccezione: tempo di comportamento (salva mezzo secondo dopo l'ultima lettera)
  }

  /// Un testo svuotato non si salva: per eliminarlo c'è il cestino.
  void _save() {
    final now = _text.text;
    if (now == _saved || now.trim().isEmpty) return;
    _saved = now;
    Core.editEntry(widget.entry.at, now);
  }

  /// Sono arrivate parole a voce: entrano dov'era il cursore, e lui si sposta dopo di loro. È arrivato un titolo
  /// proposto: si vede.
  Future<void> _reload() async {
    final list = await Core.history();
    if (!mounted) return;
    final voce = list.where((e) => e.at == widget.entry.at).firstOrNull;
    if (voce == null) return;
    if (voce.titolo != null && voce.titolo != _titolo) setState(() => _titolo = voce.titolo);
    final now = voce.text;
    if (now == _saved) return;
    final grown = now.length - _saved.length;
    final at = _text.selection.isValid ? _text.selection.baseOffset : _cursore;
    _saved = now;
    final dopo = at >= 0 && at + grown <= now.length ? at + grown : -1;
    _text.value = TextEditingValue(text: now, selection: TextSelection.collapsed(offset: dopo));
    // Il cursore si sposta dopo le parole arrivate: la prossima voce entra lì.
    _cursore = dopo;
  }

  /// Quando la tastiera si chiude sparisce anche il cursore; il punto resta ricordato per la voce.
  double _keyboard = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = MediaQuery.viewInsetsOf(context).bottom;
    if (_keyboard > 0 && now == 0 && _focus.hasFocus) _focus.unfocus();
    _keyboard = now;
  }

  /// Prima di «Detta qui»: salva, chiede i permessi, chiude la tastiera. La registrazione la fa partire la barra.
  Future<bool> _preparaVoce() async {
    _saving?.cancel();
    _save();
    if (!await transcriReady(context)) return false;
    // La tastiera si chiude prima, così non copre il testo né la barra.
    if (_focus.hasFocus) {
      _focus.unfocus();
      await Future.delayed(const Duration(milliseconds: 320)); // ds:eccezione: tempo di comportamento (aspetta che la tastiera scenda)
    }
    return mounted;
  }

  /// Dove entrerà la voce: il cursore, o l'ultimo punto ricordato (-1 = in fondo).
  int _puntoVoce() => _text.selection.isValid ? _text.selection.end : _cursore;

  /// In cima: il titolo a sinistra (toccato si cambia), il cerchio del colore a destra, sotto il giorno, il modo e la
  /// provenienza.
  Widget _testata(Entry entry) {
    final colore = _colore;
    final titoli = Titoli.automatici.value;
    final dati = Row(
      children: [
        Flexible(
          child: Text(shortStamp(entry.at), style: orarioStyle(context, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (entry.mode != null) ...[const SizedBox(width: Spazio.s3), Flexible(child: EtichettaModo(entry.mode!, nome: true))],
        if (entry.source != null) ...[const SizedBox(width: Spazio.s3), SourceIcon(entry.source)],
      ],
    );
    // Senza «Titoli automatici» (prove, giro 7) niente titolo: in cima il giorno, il modo e da dove, col cerchio.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: titoli ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: !titoli
                  ? dati
                  : ListenableBuilder(
                      listenable: _text,
                      builder: (context, _) => TitoloModificabile(
                        titolo: _titolo ?? Titoli.taglia(_text.text),
                        suggerimento: Titoli.taglia(_text.text),
                        stile: Testo.titoloSezione,
                        onFatto: _intitola,
                      ),
                    ),
            ),
            const SizedBox(width: Spazio.s2),
            // Sempre qui, con o senza colore: la scelta del colore spunta da lui (sotto: sopra non c'è posto).
            Builder(
              builder: (punto) => CerchioColore(
                colore: colore == null ? null : PuntoColore.di(context, colore),
                onTap: () => _scegliColore(dovSta(punto)),
              ),
            ),
          ],
        ),
        if (titoli) dati,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final tk = context.col;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        controller: _sheet,
        initialChildSize: 0.6,
        maxChildSize: 0.94,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(24, 0, Spazio.s3, 24),
                children: [
                  _testata(entry),
                  const SizedBox(height: Spazio.s3),
                  // Mentre detti qui, il cursore arancione dice dove entrerà la voce.
                  Padding(
                    padding: const EdgeInsets.only(right: Spazio.s3),
                    child: CursoreVoce(
                      at: entry.at,
                      testo: _text,
                      punto: _puntoVoce,
                      child: ApriCollegamento(
                        testo: _text,
                        child: TextField(
                          controller: _text,
                          focusNode: _focus,
                          style: Testo.lettura(context).copyWith(color: tk.testo),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          decoration: CampoNudo.decorazione,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Sempre lì, anche in fondo a un testo lungo e sopra la tastiera.
            BarraInFondo(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tk.linea)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: VoceInBarra(at: entry.at, prepara: _preparaVoce, punto: _puntoVoce),
                        ),
                        DeleteButton(onDelete: widget.onDelete),
                        ListenableBuilder(
                          listenable: _text,
                          builder: (context, _) => CopyButton(text: _text.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
