import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/ricerca.dart';
import 'common.dart';
import 'molecole/lista_categoria.dart';
import 'molecole/riga_trovata.dart';
import 'molecole/pezzo_argomento.dart';
import 'molecole/scheda_argomento.dart';
import 'molecole/stato_vuoto.dart';
import 'theme.dart';
import 'trascrivi.dart';

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
  final _search = TextEditingController();

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
    // Solo quando cambia il testo cercato (non il cursore).
    _search.addListener(() {
      if (_search.text == _cercato) return;
      setState(() => _cercato = _search.text);
      _attesa?.cancel();
      _attesa = Timer(Durata.normale, _cerca);
    });
    Ricerca.comeFrasi.addListener(_ridisegna);
    _load();
  }

  void _ridisegna() => setState(() {});

  String _cercato = '';

  /// Si cerca quando smetti di scrivere per un attimo, non a ogni lettera.
  Timer? _attesa;

  /// Quello che ha trovato il motore per [_cercato]; null finché non ha risposto.
  List<Trovato>? _trovati;

  /// Le trascrizioni, per mostrare quelle trovate (solo nella lista di frasi).
  Map<String, Entry> _voci = {};

  bool get _cercando => _cercato.trim().isNotEmpty && _trovati != null;

  Future<void> _cerca() async {
    final q = _cercato;
    if (q.trim().isEmpty) return setState(() => _trovati = null);
    final r = await Ricerca.cerca(q);
    final voci = await Core.history();
    // Nel frattempo hai scritto altro: questa risposta è vecchia.
    if (!mounted || q != _cercato) return;
    setState(() {
      _trovati = r;
      _voci = {for (final e in voci) '${e.at.millisecondsSinceEpoch}': e};
    });
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    Ricerca.comeFrasi.removeListener(_ridisegna);
    _attesa?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await Core.notes();
    // Il nativo avvisa spesso (la pillola, gli argomenti): se non è cambiato niente, non si ridisegna niente.
    if (mounted && !listEquals(list, notes)) setState(() => notes = list);
  }

  /// Le note trovate, nell'ordine del motore (prima per parola, poi per senso). Senza ricerca, tutte.
  List<Note> _found(List<Note> all) {
    if (!_cercando) return all;
    final perId = {for (final n in all) n.id: n};
    return [
      for (final x in _trovati!)
        if (x.nota && perId[x.id] != null) perId[x.id]!,
    ];
  }

  /// Le frasi trovate, da note e trascrizioni insieme: la frase, e sotto da dove viene.
  List<Widget> _frasi(List<Note> all) {
    final perId = {for (final n in all) n.id: n};
    return [
      for (final x in _trovati ?? const <Trovato>[])
        if ((x.nota ? perId[x.id]?.text : _voci[x.id]?.text) case final testo? when x.frase.end <= testo.length)
          Padding(
            padding: const EdgeInsets.only(bottom: Spazio.s3),
            child: RigaTrovata(
              frase: x.frase.textInside(testo).trim(),
              cercato: _cercato,
              nota: x.nota,
              daDove: x.nota
                  ? (perId[x.id]!.title.trim().isEmpty ? shortStamp(perId[x.id]!.updated) : perId[x.id]!.title.trim())
                  : 'Trascrizione · ${shortStamp(_voci[x.id]!.at)}',
              onApri: () => x.nota ? openNote(context, perId[x.id]) : openEntry(context, _voci[x.id]!),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = notes;
    if (all == null) return const SizedBox.shrink();
    final tk = context.col;
    final shown = _found(all);
    final frasi = _cercando && Ricerca.comeFrasi.value ? _frasi(all) : null;
    if (all.isEmpty) {
      return StatoVuoto(frase: 'Le tue note stanno qui.\nScrivine una con la matita, in basso.', bottom: widget.bottom);
    }
    // Le note si costruiscono solo quando arrivano sullo schermo (Masonry è fatta di due liste pigre).
    final list = CustomScrollView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          sliver: SliverToBoxAdapter(child: SearchField(controller: _search, hint: 'Cerca quello che ricordi')),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottom + 24 + ConSelezione.spazio(selected.isNotEmpty)),
          sliver: (frasi?.isEmpty ?? shown.isEmpty)
              ? SliverToBoxAdapter(
                  child: _Hint(top: 'Niente con «${_search.text.trim()}».', bottom: 'Prova a dirlo con altre parole.', color: tk.testoSecondario),
                )
              : frasi != null
              ? SliverList.list(children: frasi)
              : Masonry(
                  children: [
                    for (final n in shown)
                      NoteCard(
                        key: ValueKey(n.id),
                        note: n,
                        selected: selected.contains(n.id),
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
              label: selected.length == 1 ? '1 nota' : '${selected.length} note',
              onClose: () => setState(selected.clear),
              actions: [
                (Icons.content_copy_rounded, 'Copia', _copy),
                (Icons.share_rounded, 'Condividi', _share),
                (Icons.delete_outline_rounded, 'Elimina', _delete),
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

class _Hint extends StatelessWidget {
  const _Hint({required this.top, required this.bottom, required this.color});

  final String top, bottom;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 40, 4, 0),
      child: Text('$top\n$bottom', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
    );
  }
}

/// La barra per cercare: tonda, in cima alla pagina.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: tk.testoSecondario),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: tk.testoSecondario),
                tooltip: 'Cancella',
                onPressed: controller.clear,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Raggio.foglio), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Raggio.foglio), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raggio.foglio),
          borderSide: BorderSide(color: context.col.azione, width: 1.5),
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
  const NoteCard({super.key, required this.note, required this.onOpen, required this.onSelect, this.selected = false});

  final Note note;
  final VoidCallback onOpen;

  /// Tenerla premuta la sceglie, come in Samsung Note: poi in fondo compaiono le azioni.
  final VoidCallback onSelect;
  final bool selected;

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
              if (note.text.trim().isNotEmpty) Anteprima(note.text.trim(), righe: _maxLines, stile: Testo.testo.copyWith(color: tk.testoSecondario)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(shortStamp(note.updated), style: monoStyle(context), overflow: TextOverflow.ellipsis),
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
    'ready' => const Tooltip(message: 'Divisa per argomento: pizzica la nota', child: GrainIcon(level: 1, size: 14)),
    'pending' => SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.col.testoSecondario)),
    _ => const SizedBox.shrink(),
  };
}

/// I colori dei pezzi: tenui, uno dopo l'altro. Si leggono sia di giorno sia di notte.

/// Il testo della nota con gli argomenti illuminati dietro le lettere, alla grana scelta.
/// Solo finché il testo è quello per cui sono stati fatti: appena scrivi, si spengono e tornano
/// al prossimo salvataggio.
class TopicTextController extends TextEditingController {
  TopicTextController({super.text});

  NoteTopics? topics;

  /// Il testo per cui [topics] vale.
  String? topicsFor;

  /// 0 spento, 1 argomenti, 2 argomenti specifici, 3 frasi chiave, 4 parole chiave.
  int get level => _level;
  int _level = 0;

  /// Cambia la grana e ridisegna il testo coi nuovi colori.
  set level(int l) {
    if (l == _level) return;
    _level = l;
    notifyListeners();
  }

  bool get usable => topics != null && text == topicsFor;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Mentre la tastiera sta componendo una parola si lascia fare a Flutter (la sottolineatura della parola).
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    if (level == 0 || !usable) return _plain(style);
    return switch (level) {
      3 => _accents(style, topics!.keyRanges, bold: false),
      4 => _accents(style, _pairs(topics!.keywords), bold: true),
      _ => _pieces(style, topics!.pieces(level)),
    };
  }

  static final _link = RegExp(r'(https?://|www\.)[^\s]+');

  /// Il testo normale, coi link riconoscibili: colore delle azioni e sottolineati.
  TextSpan _plain(TextStyle? style) {
    final children = <TextSpan>[];
    var at = 0;
    for (final m in _link.allMatches(text)) {
      if (m.start > at) children.add(TextSpan(text: text.substring(at, m.start)));
      children.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(color: Colori.adesso.azione, decoration: TextDecoration.underline, decorationColor: Colori.adesso.azione),
        ),
      );
      at = m.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }

  static List<TextRange> _pairs(List<int> k) => [for (var i = 0; i + 1 < k.length; i += 2) TextRange(start: k[i], end: k[i + 1])];

  Color _color(int i) => Colori.adesso.argomenti[i % Colori.adesso.argomenti.length];

  TextSpan _pieces(TextStyle? style, List<TextRange> pieces) {
    final children = <TextSpan>[];
    var at = 0;
    for (var i = 0; i < pieces.length; i++) {
      final r = pieces[i];
      if (r.start > at) children.add(TextSpan(text: text.substring(at, r.start)));
      children.add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(backgroundColor: _color(i).withValues(alpha: 0.24)),
        ),
      );
      at = r.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }

  /// Le ultime due grane: il testo si fa leggero e restano accesi solo dei pezzi (le frasi chiave,
  /// o le parole chiave), ognuno col colore del suo argomento medio. Si legge l'essenziale in un colpo d'occhio.
  TextSpan _accents(TextStyle? style, List<TextRange> lit, {required bool bold}) {
    final faded = TextStyle(color: (style?.color ?? Colori.adesso.testo).withValues(alpha: 0.28));
    final pieces = topics!.pieces(2);
    int pieceOf(int at) {
      for (var i = 0; i < pieces.length; i++) {
        if (at < pieces[i].end) return i;
      }
      return pieces.length - 1;
    }

    final children = <TextSpan>[];
    var at = 0;
    for (final r in lit) {
      if (r.start < at) continue;
      if (r.start > at) children.add(TextSpan(text: text.substring(at, r.start), style: faded));
      children.add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(fontWeight: bold ? FontWeight.w600 : null, backgroundColor: _color(pieceOf(r.start)).withValues(alpha: 0.3)),
        ),
      );
      at = r.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at), style: faded));
    return TextSpan(style: style, children: children);
  }
}

/// La grana in un'icona, come un mirino: tre cerchi alla stessa distanza uno dall'altro.
/// Acceso il più grande = argomenti larghi, quello di mezzo = medi, il piccolo = frasi chiave;
/// il mirino (la croce) = parole chiave, il punto più preciso. Spenti: tutti appena accennati.
/// La grana degli argomenti: ora è il Mirino del design system (atomi.dart). Il nome resta per chi lo usa.
class GrainIcon extends StatelessWidget {
  const GrainIcon({super.key, required this.level, this.size = 22, this.color});

  final int level;
  final double size;

  /// Su un fondo scuro (il selettore della grana) tutto in un colore solo.
  final Color? color;

  @override
  Widget build(BuildContext context) => Mirino(livello: level, misura: size, acceso: color, spento: color);
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
    if (y > _rigaScala * 5) return;
    final l = (4 - (y / _rigaScala).floor()).clamp(0, 4);
    if (l == _text.level) return;
    HapticFeedback.selectionClick();
    setState(() => _text.level = l);
  }

  void _slideEnd() {
    if (_sliding) setState(() => _sliding = false);
  }

  static const _levels = ['Spento', 'Argomenti', 'Argomenti specifici', 'Frasi chiave', 'Parole chiave'];

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
      _salvaPerArgomenti(level.clamp(1, 4));
      return;
    }
    // Gli argomenti stanno sul testo intero: il riassunto si fa da parte.
    if (_showSummary) setState(() => _showSummary = false);
    final l = level.clamp(0, 4);
    if (l == _text.level) return;
    HapticFeedback.selectionClick();
    setState(() => _text.level = l);
    _say(_levels[l]);
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

  static const _bullet = '• ';

  int _lineStart(String text, int at) => at <= 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;

  /// Il tasto elenco: mette o toglie il pallino all'inizio della riga dove sei.
  void _toggleList() {
    final text = _text.text;
    final at = _selection.start;
    final start = _lineStart(text, at);
    HapticFeedback.selectionClick();
    if (text.startsWith(_bullet, start)) {
      _set(text.replaceRange(start, start + _bullet.length, ''), (at - _bullet.length).clamp(start, text.length));
    } else {
      _set(text.replaceRange(start, start, _bullet), at + _bullet.length);
    }
  }

  /// Andando a capo dentro un elenco il pallino continua; su una riga vuota col pallino, l'elenco finisce.
  void _continueList() {
    final now = _text.text;
    final before = _before;
    _before = now;
    if (now.length != before.length + 1) return;
    final c = _text.selection.baseOffset;
    if (c < 1 || now[c - 1] != '\n') return;
    final start = _lineStart(now, c - 1);
    final line = now.substring(start, c - 1);
    if (!line.startsWith(_bullet)) return;
    if (line == _bullet) {
      _set(now.replaceRange(start, c, ''), start);
    } else {
      _set(now.replaceRange(c, c, _bullet), c + _bullet.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    final fresh = widget.note.isEmpty;
    final plain = InputDecoration(
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: tk.testoSecondario),
    );
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
                                  child: SingleChildScrollView(child: Text(_summary ?? '', style: Theme.of(context).textTheme.bodyLarge)),
                                ),
                              Expanded(
                                flex: _showSummary ? 0 : 1,
                                child: Visibility(
                                  visible: !_showSummary,
                                  maintainState: true,
                                  child: TextField(
                                  controller: _text,
                                  undoController: _undo,
                                  scrollController: _scroll,
                                  scrollPhysics: _frozenAt != null ? const NeverScrollableScrollPhysics() : null,
                                  autofocus: fresh,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  textCapitalization: TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: plain.copyWith(hintText: 'Scrivi…'),
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
                                    for (var i = 4; i >= 0; i--)
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
                                            GrainIcon(level: i, size: Misura.iconaPiccola, color: i == _text.level ? context.col.suAzioneTenue : context.col.suFloater),
                                            Text(
                                              _levels[i],
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
              NoteToolbar(
                undo: _undo,
                onList: _toggleList,
                dictation: _dictation,
                onPaste: _pasteDictation,
                topics: _text.usable && !_showSummary ? _text.level : 0,
                onTopics: () => _setLevel(_text.level == 4 ? 0 : _text.level + 1),
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

/// La barra sotto la nota, sopra la tastiera: annulla e ripeti, l'elenco, e quando hai
/// appena dettato qualcosa con Transcri, il tasto per incollarlo qui.
class NoteToolbar extends StatelessWidget {
  const NoteToolbar({
    super.key,
    required this.undo,
    required this.onList,
    required this.dictation,
    required this.onPaste,
    required this.topics,
    required this.onTopics,
    required this.onSlideStart,
    required this.onSlide,
    required this.onSlideEnd,
    required this.onSummarize,
    this.summarizing = false,
    this.summaryOn = false,
  });

  final UndoHistoryController undo;
  final VoidCallback onList;
  final Entry? dictation;
  final VoidCallback onPaste;

  /// La grana degli argomenti (0–4). Il tasto c'è sempre: se non sono pronti, toccandolo dice perché.
  final int topics;
  final VoidCallback onTopics;

  /// Tenendo il tasto si sceglie la grana: [onSlide] riceve dov'è il dito sullo schermo.
  final VoidCallback onSlideStart, onSlideEnd;
  final ValueChanged<Offset> onSlide;

  /// Passa dal testo al riassunto e ritorno.
  final VoidCallback onSummarize;
  final bool summarizing;

  /// Si sta leggendo il riassunto: il tasto è acceso e riporta al testo intero.
  final bool summaryOn;

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          children: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: undo,
              builder: (context, v, _) => Row(
                children: [
                  IconButton(onPressed: v.canUndo ? undo.undo : null, icon: const Icon(Icons.undo_rounded), tooltip: 'Annulla'),
                  IconButton(onPressed: v.canRedo ? undo.redo : null, icon: const Icon(Icons.redo_rounded), tooltip: 'Ripeti'),
                ],
              ),
            ),
            IconButton(
              onPressed: onList,
              icon: Icon(Icons.format_list_bulleted_rounded, color: tk.testo),
              tooltip: 'Elenco',
            ),
            // Gli argomenti: lo stesso del pizzico, per chi non lo conosce. Acceso = colorato.
            Tooltip(
                message: 'Tocca, tira su o pizzica la nota',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTopics,
                  onVerticalDragStart: (_) => onSlideStart(),
                  onVerticalDragUpdate: (d) => onSlide(d.globalPosition),
                  onVerticalDragEnd: (_) => onSlideEnd(),
                  onVerticalDragCancel: onSlideEnd,
                  onLongPressStart: (_) => onSlideStart(),
                  onLongPressMoveUpdate: (d) => onSlide(d.globalPosition),
                  onLongPressEnd: (_) => onSlideEnd(),
                  child: Padding(padding: const EdgeInsets.all(12), child: GrainIcon(level: topics)),
                ),
              ),
            IconButton(
                onPressed: onSummarize,
                tooltip: summaryOn ? 'Torna al testo intero' : 'Riassumi',
                icon: summarizing
                    ? const SizedBox.square(dimension: 24, child: VoiceCircle(phase: 'PROCESSING', size: 24))
                    : Icon(Icons.short_text_rounded, color: summaryOn ? context.col.azione : tk.testo),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: Durata.normale,
                  transitionBuilder: (c, a) => ScaleTransition(
                    scale: a,
                    child: FadeTransition(opacity: a, child: c),
                  ),
                  child: dictation == null
                      ? const SizedBox.shrink()
                      : Tooltip(
                          key: ValueKey(dictation!.at),
                          message: 'Incolla la dettatura',
                          child: FilledButton.icon(
                            onPressed: onPaste,
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                            icon: const Icon(Icons.mic_rounded, size: 18),
                            label: const Text('Incolla', maxLines: 1, overflow: TextOverflow.ellipsis),
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
