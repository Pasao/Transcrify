import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formato.dart';
import '../core/native.dart';
import '../core/ricerca.dart';
import '../core/scrittura.dart';
import 'barra_nota.dart';
import 'common.dart';
import 'molecole/apri_collegamento.dart';
import 'molecole/lista_categoria.dart';
import 'molecole/pezzo_argomento.dart';
import 'molecole/scheda_argomento.dart';
import 'molecole/stato_vuoto.dart';
import 'theme.dart';

/// Apre una nota (o una nuova, vuota) e ci pensa lui a salvarla quando torni indietro.
/// Se l'hai eliminata, per qualche secondo la puoi riavere.
Future<void> openNote(BuildContext context, [Note? note]) async {
  final start = note ?? Note.blank();
  // La tastiera rimasta aperta dalla ricerca alzerebbe la barra e taglierebbe il testo.
  FocusManager.instance.primaryFocus?.unfocus();
  final result = await Navigator.of(context).push<Note?>(MaterialPageRoute(builder: (_) => NoteEditor(note: start)));
  final existed = note != null;
  if (result == null) {
    // Eliminata dall'editor: va via subito, e "Annulla" la rimette com'era.
    if (existed) {
      await Core.deleteNote(start.id);
      Core.refresh();
      if (context.mounted && await undoable(context, 'Nota eliminata')) {
        await Core.saveNote(start);
        Core.refresh();
      }
    }
    return;
  }
  if (result.isEmpty) {
    // Svuotata: una nota vuota non serve a niente.
    if (existed) await Core.deleteNote(start.id);
  } else if (result.title != start.title || result.text != start.text || result.summary != start.summary) {
    await Core.saveNote(result);
  }
  Core.refresh();
}

/// Pensieri: le tue note. Cerca in cima, poi le note su due colonne, come in Samsung Note.
class PensieriPage extends StatefulWidget {
  const PensieriPage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock.
  final double bottom;

  @override
  State<PensieriPage> createState() => _PensieriPageState();
}

class _PensieriPageState extends State<PensieriPage> {
  List<Note>? notes;

  /// Le note scelte tenendole premute. Finché ce n'è almeno una, toccare una nota la sceglie invece di aprirla.
  final selected = <String>{};

  void _toggle(String id) {
    final prima = selected.isEmpty;
    setState(() => selected.contains(id) ? selected.remove(id) : selected.add(id));
    // Appena cominci a scegliere, se eri in fondo la lista sale: la barra non copre le ultime.
    if (prima && selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final p = _scroll.position;
        if (p.maxScrollExtent - p.pixels <= ConSelezione.spazio(true) + Spazio.s1) {
          _scroll.animateTo(p.maxScrollExtent, duration: Durata.normale, curve: Curva.standard);
        }
      });
    }
  }

  final _scroll = ScrollController();

  List<Note> get _chosen => [
    for (final n in notes ?? <Note>[])
      if (selected.contains(n.id)) n,
  ];

  String _textOf(List<Note> list) => list.map((n) => [n.title, n.text].where((s) => s.trim().isNotEmpty).join('\n\n')).join('\n\n———\n\n');

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _textOf(_chosen)));
    HapticFeedback.mediumImpact();
    setState(selected.clear);
  }

  Future<void> _share() async {
    await Core.share(_textOf(_chosen));
    setState(selected.clear);
  }

  /// Eliminare: le note spariscono subito, «Annulla» le rimette tutte.
  Future<void> _delete() async {
    final gone = _chosen;
    setState(selected.clear);
    for (final n in gone) {
      await Core.deleteNote(n.id);
    }
    Core.refresh();
    if (!mounted) return;
    if (await undoable(context, gone.length == 1 ? 'Nota eliminata' : '${gone.length} note eliminate')) {
      for (final n in gone) {
        await Core.saveNote(n);
      }
      Core.refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    Core.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await Core.notes();
    // Il nativo avvisa spesso (la pillola, gli argomenti): se non è cambiato niente, non si ridisegna niente.
    if (mounted && !listEquals(list, notes)) setState(() => notes = list);
  }

  @override
  Widget build(BuildContext context) {
    final all = notes;
    if (all == null) return const SizedBox.shrink();
    if (all.isEmpty) {
      return StatoVuoto(frase: 'Le tue note stanno qui.\nScrivine una con la matita, in basso.', bottom: widget.bottom);
    }
    // Le note si costruiscono solo quando arrivano sullo schermo (Masonry è fatta di due liste pigre).
    final list = CustomScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // Cercare si fa dalla lente in cima (la stessa ricerca di Trascrivi).
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottom + 24 + ConSelezione.spazio(selected.isNotEmpty)),
          sliver: Masonry(
            children: [
              for (final n in all)
                NoteCard(
                  key: ValueKey(n.id),
                  note: n,
                  selected: selected.contains(n.id),
                  selecting: selected.isNotEmpty,
                  onOpen: selected.isEmpty ? () => openNote(context, n) : () => _toggle(n.id),
                  onSelect: () => _toggle(n.id),
                ),
            ],
          ),
        ),
      ],
    );
    // Le azioni sulle note scelte, in fondo, sopra il Dock.
    return ConSelezione(
      bottom: widget.bottom,
      bar: selected.isEmpty
          ? null
          : SelectionBar(
              quante: selected.length,
              onClose: () => setState(selected.clear),
              actions: [
                (Icons.content_copy_rounded, 'Copia', (_) => _copy()),
                (Icons.share_rounded, 'Condividi', (_) => _share()),
                (Icons.delete_outline_rounded, 'Elimina', (_) => _delete()),
              ],
            ),
      child: list,
    );
  }
}

/// Argomenti: la seconda pagina dei Pensieri, nel Dock. Gli argomenti che tornano in più note,
/// ognuno una scheda col suo nome e quanti pezzi raccoglie. Toccandola si vedono tutti i pezzi.
class ArgomentiPage extends StatefulWidget {
  const ArgomentiPage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock.
  final double bottom;

  @override
  State<ArgomentiPage> createState() => _ArgomentiPageState();
}

class _ArgomentiPageState extends State<ArgomentiPage> {
  List<Album>? albums;
  Map<String, Note> notes = {};

  @override
  void initState() {
    super.initState();
    Core.addListener(_load);
    Ricerca.perCategorie.addListener(_ridisegna);
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    Ricerca.perCategorie.removeListener(_ridisegna);
    super.dispose();
  }

  Future<void> _load() async {
    final a = await Core.albums();
    final c = await Ricerca.categorie();
    final n = await Core.notes();
    if (!mounted) return;
    // Se non è cambiato niente, non si ridisegna niente.
    if (listEquals(a, albums) && listEquals(n, _lette) && listEquals(c, _categorie)) return;
    _lette = n;
    setState(() {
      albums = a;
      _categorie = c;
      notes = {for (final x in n) x.id: x};
    });
  }

  /// Le categorie fisse (la scelta del 3 nov), con le loro frasi chiave.
  List<Categoria>? _categorie;

  void _ridisegna() => setState(() {});

  /// Ogni categoria come lista di frasi chiave; toccandone una si apre la nota.
  Widget _perCategorie(List<Categoria> tutte) => ListView.separated(
    padding: EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s4, widget.bottom + Spazio.s6),
    itemCount: tutte.length,
    separatorBuilder: (_, _) => const SizedBox(height: Spazio.s5),
    itemBuilder: (context, i) {
      final frasi = [
        for (final f in tutte[i].frasi)
          if (notes[f.note] case final n? when f.range.end <= n.text.length) (nota: n, testo: f.range.textInside(n.text).trim()),
      ];
      return ListaCategoria(
        nome: tutte[i].nome,
        frasi: [for (final f in frasi) f.testo],
        onApri: (k) => openNote(context, frasi[k].nota),
      );
    },
  );

  /// Le note come sono arrivate l'ultima volta.
  List<Note>? _lette;

  @override
  Widget build(BuildContext context) {
    final list = albums;
    if (list == null) return const SizedBox.shrink();
    final categorie = _categorie;
    if (Ricerca.perCategorie.value && categorie != null && categorie.isNotEmpty) return _perCategorie(categorie);
    if (list.isEmpty) {
      final ready = notes.values.where((n) => n.topics == 'ready').length;
      return StatoVuoto(
        frase: ready == 0
            ? 'Gli argomenti di cui parli più spesso stanno qui.\nAccendi «Dividi per argomento» nelle impostazioni.'
            : 'Gli argomenti di cui parli più spesso stanno qui.\nUno compare quando torna almeno tre volte.',
        bottom: widget.bottom,
      );
    }
    // I grandi concetti, nell'ordine in cui arrivano (dal più grande); il nome lo dà il motore.
    final concetti = <int, List<Album>>{};
    for (final a in list) {
      (concetti[a.concetto < 0 ? -a.id : a.concetto] ??= []).add(a);
    }
    final gruppi = concetti.values.toList();
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s4, widget.bottom + Spazio.s6),
      itemCount: gruppi.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spazio.s3),
      itemBuilder: (context, i) => SchedaArgomento(
        nome: gruppi[i].first.concettoNome,
        colore: context.col.argomenti[i % context.col.argomenti.length],
        album: gruppi[i],
        onApri: (a) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(album: a, notes: notes))),
      ),
    );
  }
}

/// Un album: tutti i pezzi che parlano di quell'argomento, da note diverse, uno sotto l'altro.
/// Ognuno dice da quale nota viene; toccandolo si apre la nota.
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key, required this.album, required this.notes});

  final Album album;
  final Map<String, Note> notes;

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    return Paper(
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spazio.s1, 0, Spazio.s1, Spazio.s1),
              child: Text(album.name, style: Testo.titoloPagina.copyWith(color: tk.testo)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Spazio.s1, 0, Spazio.s1, Spazio.s5),
              child: Text('${SchedaArgomento.pezzi(album.pieces.length)} da ${album.notes == 1 ? '1 nota' : '${album.notes} note'}', style: Testo.orario.copyWith(color: tk.testoSecondario)),
            ),
            for (final p in album.pieces)
              if (notes[p.note] case final note? when p.range.end <= note.text.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spazio.s3),
                  child: PezzoArgomento(
                    testo: note.text.substring(p.range.start, p.range.end).trim(),
                    daNota: note.title.trim().isEmpty ? dayLabel(note.updated) : note.title.trim(),
                    onApriNota: () => openNote(context, note),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Due colonne: ogni scheda va nella colonna più corta, così le note lunghe sono alte e le corte basse.
/// È un pezzo di lista (sliver): ogni colonna è una lista pigra, le schede si fanno quando arrivano sullo schermo.
class Masonry extends StatelessWidget {
  const Masonry({super.key, required this.children, this.gap = 10});

  final List<NoteCard> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cols = [<NoteCard>[], <NoteCard>[]];
    final heights = [0.0, 0.0];
    for (final c in children) {
      final i = heights[0] <= heights[1] ? 0 : 1;
      cols[i].add(c);
      heights[i] += c.estimatedLines + 3;
    }
    Widget colonna(List<NoteCard> cards) => SliverCrossAxisExpanded(
      flex: 1,
      sliver: SliverList.builder(
        itemCount: cards.length,
        itemBuilder: (_, i) => Padding(padding: EdgeInsets.only(bottom: gap), child: cards[i]),
      ),
    );
    return SliverCrossAxisGroup(
      slivers: [
        colonna(cols[0]),
        SliverConstrainedCrossAxis(maxExtent: gap, sliver: const SliverToBoxAdapter()),
        colonna(cols[1]),
      ],
    );
  }
}

/// Una nota nella lista: il titolo, se c'è, poi l'inizio del testo e quando l'hai toccata l'ultima volta.
/// Tenendola premuta la copi, come le trascrizioni.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onOpen, required this.onSelect, this.selected = false, this.selecting = false});

  final Note note;
  final VoidCallback onOpen;

  /// Tenerla premuta la sceglie, come in Samsung Note: poi in fondo compaiono le azioni.
  final VoidCallback onSelect;
  final bool selected;

  /// Se ne stanno scegliendo: un tocco sceglie, i collegamenti nel testo non si aprono.
  final bool selecting;

  static const _maxLines = 9;

  /// Più o meno quante righe occupa: serve solo a scegliere la colonna.
  double get estimatedLines =>
      (note.title.isEmpty ? 0 : 1.4) + (note.text.length / 22).clamp(1, _maxLines.toDouble()) + '\n'.allMatches(note.text).length * 0.5;

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    // La Scheda del design system: «scelta» = fondo tenue e contorno.
    return Material(
      color: Scheda.fondo(tk, scelta: selected),
      shape: Scheda.forma(tk, scelta: selected),
      child: InkWell(
        borderRadius: BorderRadius.circular(Raggio.scheda),
        onTap: onOpen,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onSelect();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s3, Spazio.s4, Spazio.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title.trim().isNotEmpty) ...[
                Text(note.title.trim(), style: Testo.titoloScheda.copyWith(color: tk.testo), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Spazio.s1),
              ],
              if (note.text.trim().isNotEmpty) Anteprima(note.text.trim(), righe: _maxLines, stile: TextStyle(color: tk.testoSecondario), collegamenti: !selecting),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(shortStamp(note.updated), style: orarioStyle(context), overflow: TextOverflow.ellipsis),
                  ),
                  if (note.source != null) ...[SourceIcon(note.source), const SizedBox(width: 6)],
                  TopicsBadge(state: note.topics),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il segno degli argomenti su una nota: il mirino se sono pronti (si può pizzicare),
/// un cerchio che gira mentre li sta facendo. Niente se sono spenti o se la nota è cambiata.
class TopicsBadge extends StatelessWidget {
  const TopicsBadge({super.key, required this.state});

  final String state;

  @override
  Widget build(BuildContext context) => switch (state) {
    'ready' => const Tooltip(message: 'Divisa per argomento: pizzica la nota', child: BarreGrana(livello: Grana.argomenti, misura: 14)),
    'pending' => SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.col.testoSecondario)),
    _ => const SizedBox.shrink(),
  };
}

/// Scrivere una nota: il titolo (se vuoi) e il testo. Si salva da sola quando torni indietro.
/// Ritorna la nota com'è adesso, o null se l'hai eliminata.
class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note.title);
  late final _text = TopicTextController(text: widget.note.text);
  final _undo = UndoHistoryController();

  /// Il testo com'era un attimo fa: serve a capire se sei appena andato a capo dentro un elenco.
  late String _before = _text.text;

  /// Le dettature arrivate dopo che hai aperto la nota. Transcri fuori copia sempre negli appunti:
  /// qui ti offriamo di incollare l'ultima dove sei, con un tocco. Non decide da solo.
  final _opened = DateTime.now();
  Entry? _dictation;
  DateTime? _pasted;

  @override
  void initState() {
    super.initState();
    _text.addListener(_continueList);
    Core.addListener(_checkDictation);
    Core.addListener(_loadTopics);
    _loadTopics();
  }

  // --- Gli argomenti: si accendono pizzicando, col tasto nella barra, o tirandolo su ---

  /// Mentre tieni il tasto: la scala delle grane. La grana è quella della riga sotto il dito
  /// (dove capita il dito, non quanto l'hai spostato): si sale e si scende liberamente.
  bool _sliding = false;
  final _scala = GlobalKey();
  static const _rigaScala = 40.0;

  void _slideStart() {
    if (!_text.usable) return _setLevel(1);
    HapticFeedback.selectionClick();
    setState(() {
      _showSummary = false;
      _sliding = true;
    });
  }

  /// [dito]: dov'è il dito sullo schermo. Sotto la scala (sul tasto) non cambia niente; sopra la scala è la più fine.
  void _slide(Offset dito) {
    if (!_sliding) return;
    final box = _scala.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final y = box.globalToLocal(dito).dy - Spazio.s2;
    if (y > _rigaScala * Grana.nomi.length) return;
    final l = (Grana.ultima - (y / _rigaScala).floor()).clamp(Grana.spenta, Grana.ultima);
    if (l == _text.level) return;
    HapticFeedback.selectionClick();
    setState(() => _text.level = l);
  }

  void _slideEnd() {
    if (_sliding) setState(() => _sliding = false);
  }

  /// Il testo scorre col suo controller: mentre pizzichi resta fermo dov'era.
  final _scroll = ScrollController();
  double? _frozenAt;

  /// La scritta che compare per un attimo mentre pizzichi.
  String? _label;
  Timer? _labelTimer;

  /// Il testo com'era all'ultimo salvataggio: gli argomenti che arrivano sono di questo.
  late String _salvato = widget.note.text;

  /// La grana chiesta mentre gli argomenti si facevano: appena arrivano si accende.
  int? _livelloAtteso;

  Future<void> _loadTopics() async {
    if (_salvato.trim().isEmpty) return;
    final t = await Core.noteTopics(widget.note.id);
    if (!mounted) return;
    setState(() {
      _text.topics = t;
      _text.topicsFor = _salvato;
    });
    final atteso = _livelloAtteso;
    if (_text.usable && atteso != null) {
      _livelloAtteso = null;
      _setLevel(atteso);
    }
  }

  /// Hai cambiato la nota e chiedi gli argomenti: si salva adesso (è il suo «commit») e arrivano appena pronti.
  Future<void> _salvaPerArgomenti(int level) async {
    _livelloAtteso = level;
    _salvato = _text.text;
    _say('Salvo e divido per argomento…');
    await Core.saveNote(_current);
    Core.refresh();
  }

  void _say(String s) {
    _labelTimer?.cancel();
    setState(() => _label = s);
    _labelTimer = Timer(Durata.etichetta, () {
      if (mounted) setState(() => _label = null);
    });
  }

  void _setLevel(int level) {
    if (!_text.usable) {
      if (widget.note.topics == 'off' && !widget.note.isEmpty) return _say('Accendi «Dividi per argomento» nelle impostazioni');
      if (_text.text.trim().isEmpty) return _say('Scrivi qualcosa, poi lo divido per argomento');
      if (_livelloAtteso != null && _salvato == _text.text) return _say('Sto dividendo per argomento…');
      // Gli argomenti si fanno sul testo salvato: si salva adesso, senza chiederti niente.
      _salvaPerArgomenti(level.clamp(Grana.argomenti, Grana.ultima));
      return;
    }
    // Gli argomenti stanno sul testo intero: il riassunto si fa da parte.
    if (_showSummary) setState(() => _showSummary = false);
    final l = level.clamp(Grana.spenta, Grana.ultima);
    if (l == _text.level) return;
    HapticFeedback.selectionClick();
    setState(() => _text.level = l);
    _say(Grana.nomi[l]);
  }

  // Il pizzico, letto direttamente dalle dita: non ruba né lo scorrimento né la selezione del testo.
  final _fingers = <int, Offset>{};
  double? _pinchFrom;
  int _levelFrom = 0;

  double get _spread {
    final p = _fingers.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _fingers[e.pointer] = e.position;
    if (_fingers.length == 2) {
      _pinchFrom = _spread;
      _levelFrom = _text.level;
      // Con due dita si pizzica, non si scorre: il testo resta dov'era.
      setState(() => _frozenAt = _scroll.hasClients ? _scroll.offset : null);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_fingers.containsKey(e.pointer)) return;
    _fingers[e.pointer] = e.position;
    final from = _pinchFrom;
    if (_fingers.length != 2 || from == null || from == 0) return;
    final frozen = _frozenAt;
    if (frozen != null && _scroll.hasClients && _scroll.offset != frozen) _scroll.jumpTo(frozen);
    // Un gradino ogni volta che la distanza tra le dita cresce (o cala) di un terzo.
    final steps = (math.log(_spread / from) / math.log(1.35)).truncate();
    // Allargare = più dettaglio, come nelle mappe; nelle prove si può girare.
    _setLevel(_levelFrom + (Core.pinchReversed.value ? -steps : steps));
  }

  void _up(PointerEvent e) {
    _fingers.remove(e.pointer);
    if (_fingers.length < 2 && _pinchFrom != null) {
      _pinchFrom = null;
      setState(() => _frozenAt = null);
    }
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _scroll.dispose();
    Core.removeListener(_loadTopics);
    Core.removeListener(_checkDictation);
    _title.dispose();
    _text.dispose();
    _undo.dispose();
    super.dispose();
  }

  Note get _current => widget.note.edited(title: _title.text, text: _text.text, summary: _summaryOf == _text.text ? _summary : null);

  Future<void> _checkDictation() async {
    final h = await Core.history();
    if (!mounted || h.isEmpty) return;
    final last = h.first;
    if (last.at.isAfter(_opened) && last.at != _pasted && last.at != _dictation?.at) setState(() => _dictation = last);
  }

  void _set(String text, int cursor) {
    _before = text;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  TextSelection get _selection {
    final s = _text.selection;
    return s.isValid ? s : TextSelection.collapsed(offset: _text.text.length);
  }

  /// Mette [s] dove c'è il cursore (o al posto di quello che hai selezionato).
  void _insert(String s) {
    final sel = _selection;
    _set(_text.text.replaceRange(sel.start, sel.end, s), sel.start + s.length);
  }

  /// Una nota nata da un audio resta fedele; il riassunto lo chiedi tu. Sta accanto al testo e non lo tocca:
  /// il tasto passa dall'uno all'altro. Se poi cambi il testo, il riassunto vecchio non vale più.
  bool _summarizing = false;
  bool _showSummary = false;
  late String? _summary = widget.note.summary;
  late String _summaryOf = widget.note.text;

  Future<void> _summarize() async {
    if (_summarizing || _text.text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    if (_showSummary) {
      setState(() => _showSummary = false);
      return _say('Testo intero');
    }
    if (_summary == null || _summaryOf != _text.text) {
      setState(() => _summarizing = true);
      try {
        final of = _text.text;
        final short = await Core.summarize(of);
        _summary = short;
        _summaryOf = of;
        // Si salva subito: la prossima volta il riassunto è già lì, anche se l'app si chiude prima di uscire dalla nota.
        _salvato = of;
        await Core.saveNote(_current);
      } on PlatformException {
        if (mounted) {
          setState(() => _summarizing = false);
          _say('Riassunto non riuscito');
        }
        return;
      }
      if (!mounted) return;
      setState(() => _summarizing = false);
    }
    setState(() => _showSummary = true);
    _say('Riassunto');
  }

  void _pasteDictation() {
    final d = _dictation;
    if (d == null) return;
    final before = _text.text.substring(0, _selection.start);
    // Uno spazio se stai continuando una frase, niente se sei a inizio riga.
    final glue = before.isEmpty || before.endsWith('\n') || before.endsWith(' ') ? '' : ' ';
    _insert('$glue${d.text}');
    HapticFeedback.selectionClick();
    setState(() {
      _pasted = d.at;
      _dictation = null;
    });
  }

  /// Un ritocco della barra ([Scrittura]) sul testo com'è adesso.
  void _ritocca(TextEditingValue Function(TextEditingValue v) ritocco) {
    HapticFeedback.selectionClick();
    final v = ritocco(_text.value);
    _before = v.text;
    _text.value = v;
  }

  /// Il tasto «Link»: l'indirizzo è quello negli appunti, se ce n'è uno.
  Future<void> _collega() async {
    final appunti = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final url = Formato.indirizzo(appunti?.text ?? '');
    if (url == null && _selection.isCollapsed) return _say('Copia un link, poi tocca qui');
    _ritocca((v) => Scrittura.collega(v, url));
  }

  /// Andando a capo dentro un elenco il pallino continua ([Scrittura.continua]).
  void _continueList() {
    final prima = _before;
    _before = _text.text;
    final v = Scrittura.continua(prima, _text.value);
    if (v == null) return;
    _before = v.text;
    _text.value = v;
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    final fresh = widget.note.isEmpty;
    final plain = CampoNudo.decorazione.copyWith(hintStyle: TextStyle(color: tk.testoSecondario));
    return PopScope<Note?>(
      canPop: false,
      // Indietro (gesto o tasto): si esce salvando.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_current);
      },
      child: Paper(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Indietro',
              onPressed: () => Navigator.of(context).pop(_current),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(_current), child: const Text('Fatto')),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Listener(
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _title,
                                style: display(context, size: 24),
                                textCapitalization: TextCapitalization.sentences,
                                textInputAction: TextInputAction.next,
                                maxLines: null,
                                decoration: plain.copyWith(
                                  hintText: 'Titolo',
                                  hintStyle: display(context, size: 24, color: tk.testoSecondario),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_showSummary)
                                Expanded(
                                  child: SingleChildScrollView(child: Text.rich(Formattato.span(context, _summary ?? '', stile: Testo.lettura(context).copyWith(color: tk.testo)))),
                                ),
                              Expanded(
                                flex: _showSummary ? 0 : 1,
                                child: Visibility(
                                  visible: !_showSummary,
                                  maintainState: true,
                                  child: ApriCollegamento(
                                    testo: _text,
                                    child: TextField(
                                      controller: _text,
                                      undoController: _undo,
                                      scrollController: _scroll,
                                      scrollPhysics: _frozenAt != null ? const NeverScrollableScrollPhysics() : null,
                                      autofocus: fresh,
                                      style: Testo.lettura(context).copyWith(color: tk.testo),
                                      textCapitalization: TextCapitalization.sentences,
                                      keyboardType: TextInputType.multiline,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: plain.copyWith(hintText: 'Scrivi…'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // La scala delle grane, sopra il tasto, mentre lo tiri.
                      if (_sliding)
                        Positioned(
                          left: 120,
                          bottom: 4,
                          child: IgnorePointer(
                            child: Container(
                              key: _scala,
                              padding: const EdgeInsets.all(Spazio.s2),
                              decoration: BoxDecoration(color: context.col.floater, borderRadius: BorderRadius.circular(Raggio.scheda), boxShadow: Ombra.sospeso),
                              // Le righe larghe tutte uguali: quella scelta si colora per intero.
                              child: IntrinsicWidth(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    for (var i = Grana.ultima; i >= Grana.spenta; i--)
                                      AnimatedContainer(
                                        duration: Durata.veloce,
                                        height: _rigaScala,
                                        padding: const EdgeInsets.symmetric(horizontal: Spazio.s3),
                                        decoration: BoxDecoration(
                                          // Sul fondo scuro, la scelta usa i toni tenui dell'azione (regola di Figma per ciò che è sospeso).
                                          color: i == _text.level ? context.col.azioneTenue : Colors.transparent,
                                          borderRadius: BorderRadius.circular(Raggio.pillola),
                                        ),
                                        child: Row(
                                          spacing: Spazio.s3,
                                          children: [
                                            BarreGrana(
                                              livello: i,
                                              misura: Misura.iconaPiccola,
                                              acceso: i == _text.level ? context.col.suAzioneTenue : context.col.suFloater,
                                              spento: i == _text.level ? context.col.suAzioneTenue : context.col.suFloater,
                                            ),
                                            Text(
                                              Grana.nomi[i],
                                              style: Testo.etichetta.copyWith(
                                                color: i == _text.level ? context.col.suAzioneTenue : context.col.suFloater,
                                                fontWeight: i == _text.level ? FontWeight.w600 : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // La grana scelta, per un attimo, in alto.
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _label == null ? 0 : 1,
                              duration: Durata.veloce,
                              // La grana scelta: l'etichetta sospesa del design system.
                              child: EtichettaSospesa(_label ?? ''),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              BarraNota(
                undo: _undo,
                onGrassetto: () => _ritocca((v) => Scrittura.segna(v, TipoPezzo.grassetto)),
                onCorsivo: () => _ritocca((v) => Scrittura.segna(v, TipoPezzo.corsivo)),
                onElenco: () => _ritocca(Scrittura.elenco),
                onLink: _collega,
                dictation: _dictation,
                onPaste: _pasteDictation,
                topics: _text.usable && !_showSummary ? _text.level : 0,
                onTopics: () => _setLevel(Grana.dopo(_text.level)),
                onSlideStart: _slideStart,
                onSlide: _slide,
                onSlideEnd: _slideEnd,
                onSummarize: _summarize,
                summarizing: _summarizing,
                summaryOn: _showSummary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
