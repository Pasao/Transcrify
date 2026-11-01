import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
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
  final _search = TextEditingController();

  /// Le note scelte tenendole premute. Finché ce n'è almeno una, toccare una nota la sceglie invece di aprirla.
  final selected = <String>{};

  void _toggle(String id) => setState(() => selected.contains(id) ? selected.remove(id) : selected.add(id));

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
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await Core.notes();
    if (mounted) setState(() => notes = list);
  }

  /// Le note che contengono tutte le parole cercate, nel titolo o nel testo, senza badare alle maiuscole.
  List<Note> _found(List<Note> all) {
    final words = _search.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return all;
    return all.where((n) {
      final hay = '${n.title}\n${n.text}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = notes;
    if (all == null) return const SizedBox.shrink();
    final tk = context.tk;
    final shown = _found(all);
    if (all.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottom + 24),
        child: const Column(mainAxisAlignment: MainAxisAlignment.end, children: [_EmptyNotes()]),
      );
    }
    final list = ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottom + 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SearchField(controller: _search, hint: 'Cerca quello che ricordi'),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          _Hint(top: 'Niente con «${_search.text.trim()}».', bottom: 'Prova con un\'altra parola.', color: tk.muted)
        else
          Masonry(
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
      ],
    );
    if (selected.isEmpty) return list;
    // Le azioni sulle note scelte, in fondo, sopra il Dock.
    return Stack(
      children: [
        list,
        Positioned(
          left: 16,
          right: 16,
          bottom: widget.bottom + 8,
          child: SelectionBar(
            label: selected.length == 1 ? '1 nota' : '${selected.length} note',
            onClose: () => setState(selected.clear),
            actions: [
              (Icons.content_copy_rounded, 'Copia', _copy),
              (Icons.share_rounded, 'Condividi', _share),
              (Icons.delete_outline_rounded, 'Elimina', _delete),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nessuna nota ancora: le sagome di quattro schede su due colonne, che sfumano, e una frase.
/// Dicono cosa arriverà senza fingere un contenuto, come le schede vuote di Trascrivi.
class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget ghost(double h, double opacity, List<double> lines) => Opacity(
      opacity: opacity,
      child: Container(
        height: h,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in lines)
              FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: tk.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  ghost(150, 1, [0.6, 0.9, 0.8, 0.5]),
                  const SizedBox(height: 10),
                  ghost(96, 0.5, [0.7, 0.4]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  ghost(100, 0.75, [0.5, 0.85]),
                  const SizedBox(height: 10),
                  ghost(130, 0.35, [0.8, 0.6, 0.3]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Le tue note stanno qui.\nScrivine una con la matita, in basso.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tk.muted),
        ),
      ],
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
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final a = await Core.albums();
    final n = await Core.notes();
    if (!mounted) return;
    setState(() {
      albums = a;
      notes = {for (final x in n) x.id: x};
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = albums;
    if (list == null) return const SizedBox.shrink();
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    if (list.isEmpty) {
      final ready = notes.values.where((n) => n.topics == 'ready').length;
      Widget ghost(double opacity) => Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.6,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(color: tk.border, borderRadius: BorderRadius.circular(5)),
                ),
              ),
              const Spacer(),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: tk.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, widget.bottom + 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 230,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                physics: const NeverScrollableScrollPhysics(),
                children: [ghost(1), ghost(0.7), ghost(0.45), ghost(0.25)],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                ready == 0
                    ? 'Gli argomenti di cui parli più spesso stanno qui.\nAccendi «Dividi per argomento» nelle impostazioni.'
                    : 'Gli argomenti di cui parli più spesso stanno qui.\nUno compare quando torna almeno tre volte.',
                style: t.bodyLarge?.copyWith(color: tk.muted),
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottom + 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final a = list[i];
        return Material(
          color: _topicColors[i % _topicColors.length].withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AlbumPage(album: a, notes: notes),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text('${a.pieces.length} pezzi da ${a.notes} note', style: monoStyle(context)),
                ],
              ),
            ),
          ),
        );
      },
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
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Paper(
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Text(album.name, style: display(context, size: 28)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
              child: Text('${album.pieces.length} pezzi da ${album.notes} note', style: t.bodySmall),
            ),
            for (final p in album.pieces)
              if (notes[p.note] case final note? when p.range.end <= note.text.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => openNote(context, note),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.text.substring(p.range.start, p.range.end).trim(), style: t.bodyMedium?.copyWith(height: 1.45)),
                            const SizedBox(height: 8),
                            Text(
                              'da «${note.title.trim().isEmpty ? dayLabel(note.updated) : note.title.trim()}» ›',
                              style: monoStyle(context, color: Tokens.blue),
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
    final tk = context.tk;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: tk.muted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: tk.muted),
                tooltip: 'Cancella',
                onPressed: controller.clear,
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Tokens.blue, width: 1.5),
        ),
      ),
    );
  }
}

/// Due colonne: ogni scheda va nella colonna più corta, così le note lunghe sono alte e le corte basse.
class Masonry extends StatelessWidget {
  const Masonry({super.key, required this.children, this.gap = 10});

  final List<NoteCard> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cols = [<Widget>[], <Widget>[]];
    final heights = [0.0, 0.0];
    for (final c in children) {
      final i = heights[0] <= heights[1] ? 0 : 1;
      cols[i].add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: c,
        ),
      );
      heights[i] += c.estimatedLines + 3;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: cols[0])),
        SizedBox(width: gap),
        Expanded(child: Column(children: cols[1])),
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
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Material(
      color: selected ? Tokens.blue.withValues(alpha: 0.14) : tk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? Tokens.blue : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onSelect();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title.trim().isNotEmpty) ...[
                Text(note.title.trim(), style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
              ],
              if (note.text.trim().isNotEmpty)
                Text(
                  note.text.trim(),
                  style: t.bodyMedium?.copyWith(height: 1.4, color: tk.muted),
                  maxLines: _maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
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
    'pending' => SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: context.tk.faint)),
    _ => const SizedBox.shrink(),
  };
}

/// I colori dei pezzi: tenui, uno dopo l'altro. Si leggono sia di giorno sia di notte.
const _topicColors = [Color(0xFFE8875F), Color(0xFF8E7CC3), Color(0xFF5FA778), Color(0xFF5C93C9), Color(0xFFC9A24B), Color(0xFFC9668E)];

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
          style: TextStyle(color: Tokens.blue, decoration: TextDecoration.underline, decorationColor: Tokens.blue),
        ),
      );
      at = m.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }

  static List<TextRange> _pairs(List<int> k) => [for (var i = 0; i + 1 < k.length; i += 2) TextRange(start: k[i], end: k[i + 1])];

  Color _color(int i) => _topicColors[i % _topicColors.length];

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
    final faded = TextStyle(color: (style?.color ?? const Color(0xFF1E1E1E)).withValues(alpha: 0.28));
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
class GrainIcon extends StatelessWidget {
  const GrainIcon({super.key, required this.level, this.size = 22, this.color});

  final int level;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GrainPainter(level, color ?? Tokens.blue, context.tk.faint));
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.level, this.on, this.off);

  final int level;
  final Color on, off;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    Paint pen(bool lit) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lit ? 2 : 1.3
      ..strokeCap = StrokeCap.round
      ..color = lit ? on : off;
    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(c, r * (4 - ring) / 3, pen(level == ring));
    }
    if (level == 4) {
      final p = pen(true);
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), p);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), p);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.level != level || old.on != on || old.off != off;
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

  /// Mentre tiri su il tasto: la scala delle grane, e quanto hai tirato.
  bool _sliding = false;
  double _slid = 0;
  int _slideFrom = 0;

  void _slideStart() {
    if (!_text.usable) return _setLevel(1);
    HapticFeedback.selectionClick();
    setState(() {
      _showSummary = false;
      _sliding = true;
      _slid = 0;
      _slideFrom = _text.level;
    });
  }

  /// Un gradino ogni 34 punti: più tiri su, più è preciso.
  void _slide(double by) {
    if (!_sliding) return;
    _slid += by;
    final l = (_slideFrom - (_slid / 34).round()).clamp(0, 4);
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

  Future<void> _loadTopics() async {
    if (widget.note.isEmpty) return;
    final t = await Core.noteTopics(widget.note.id);
    if (!mounted) return;
    setState(() {
      _text.topics = t;
      _text.topicsFor = widget.note.text;
    });
  }

  void _say(String s) {
    _labelTimer?.cancel();
    setState(() => _label = s);
    _labelTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _label = null);
    });
  }

  void _setLevel(int level) {
    if (!_text.usable) {
      // Il motivo, invece di niente: gli argomenti si fanno quando salvi.
      _say(switch (widget.note.topics) {
        'pending' => 'Sto dividendo per argomento…',
        'off' when !widget.note.isEmpty => 'Accendi «Dividi per argomento» nelle impostazioni',
        _ => 'Gli argomenti arrivano quando salvi',
      });
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
    final tk = context.tk;
    final fresh = widget.note.isEmpty;
    final plain = InputDecoration(
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: tk.faint),
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
                                  hintStyle: display(context, size: 24, color: tk.faint),
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(18)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 4; i >= 0; i--)
                                    Container(
                                      height: 34,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      color: i == _text.level ? Tokens.blue.withValues(alpha: 0.3) : Colors.transparent,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GrainIcon(level: i, size: 16, color: Colors.white),
                                          const SizedBox(width: 10),
                                          Text(
                                            _levels[i],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
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
                      // La grana scelta, per un attimo, in alto.
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: IgnorePointer(
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _label == null ? 0 : 1,
                              duration: const Duration(milliseconds: 160),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_text.usable) ...[
                                      GrainIcon(level: _text.level, size: 16, color: Colors.white),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _label ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
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
                onHold: (from) => _slide(from - _slid),
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
    required this.onHold,
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

  /// Tenendo il tasto e tirando su si sceglie la grana: [onSlide] riceve di quanto ti sei spostato.
  final VoidCallback onSlideStart, onSlideEnd;
  final ValueChanged<double> onSlide;

  /// Lo stesso, tenendolo premuto: riceve la distanza dal punto di partenza.
  final ValueChanged<double> onHold;

  /// Passa dal testo al riassunto e ritorno.
  final VoidCallback onSummarize;
  final bool summarizing;

  /// Si sta leggendo il riassunto: il tasto è acceso e riporta al testo intero.
  final bool summaryOn;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
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
              icon: Icon(Icons.format_list_bulleted_rounded, color: tk.text),
              tooltip: 'Elenco',
            ),
            // Gli argomenti: lo stesso del pizzico, per chi non lo conosce. Acceso = colorato.
            Tooltip(
                message: 'Tocca, tira su o pizzica la nota',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTopics,
                  onVerticalDragStart: (_) => onSlideStart(),
                  onVerticalDragUpdate: (d) => onSlide(d.delta.dy),
                  onVerticalDragEnd: (_) => onSlideEnd(),
                  onVerticalDragCancel: onSlideEnd,
                  onLongPressStart: (_) => onSlideStart(),
                  onLongPressMoveUpdate: (d) => onHold(d.offsetFromOrigin.dy),
                  onLongPressEnd: (_) => onSlideEnd(),
                  child: Padding(padding: const EdgeInsets.all(12), child: GrainIcon(level: topics)),
                ),
              ),
            IconButton(
                onPressed: onSummarize,
                tooltip: summaryOn ? 'Torna al testo intero' : 'Riassumi',
                icon: summarizing
                    ? const SizedBox.square(dimension: 24, child: VoiceCircle(phase: 'PROCESSING', size: 24))
                    : Icon(Icons.short_text_rounded, color: summaryOn ? Tokens.blue : tk.text),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
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
