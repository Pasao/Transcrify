import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
import 'theme.dart';

/// Apre una nota (o una nuova, vuota) e ci pensa lui a salvarla quando torni indietro.
/// Se l'hai eliminata, per qualche secondo la puoi riavere.
Future<void> openNote(BuildContext context, [Note? note]) async {
  final start = note ?? Note.blank();
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
  } else if (result.title != start.title || result.text != start.text) {
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
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottom + 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (all.isNotEmpty) ...[SearchField(controller: _search, hint: 'Cerca quello che ricordi'), const SizedBox(height: 14)],
        if (all.isEmpty)
          const _EmptyNotes()
        else if (shown.isEmpty)
          _Hint(top: 'Niente con «${_search.text.trim()}».', bottom: 'Prova con un\'altra parola.', color: tk.muted)
        else
          Masonry(
            children: [for (final n in shown) NoteCard(key: ValueKey(n.id), note: n, onOpen: () => openNote(context, n))],
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
  const NoteCard({super.key, required this.note, required this.onOpen});

  final Note note;
  final VoidCallback onOpen;

  static const _maxLines = 9;

  /// Più o meno quante righe occupa: serve solo a scegliere la colonna.
  double get estimatedLines =>
      (note.title.isEmpty ? 0 : 1.4) + (note.text.length / 22).clamp(1, _maxLines.toDouble()) + '\n'.allMatches(note.text).length * 0.5;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Material(
      color: tk.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        onLongPress: () async {
          await Clipboard.setData(ClipboardData(text: [note.title, note.text].where((s) => s.trim().isNotEmpty).join('\n\n')));
          // Il messaggio "copiato" lo mostra già Android: qui basta la vibrazione.
          HapticFeedback.mediumImpact();
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
              Text(dayLabel(note.updated), style: monoStyle(context)),
            ],
          ),
        ),
      ),
    );
  }
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
  late final _text = TextEditingController(text: widget.note.text);
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
  }

  @override
  void dispose() {
    Core.removeListener(_checkDictation);
    _title.dispose();
    _text.dispose();
    _undo.dispose();
    super.dispose();
  }

  Note get _current => widget.note.edited(title: _title.text, text: _text.text);

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
              if (!fresh) DeleteButton(onDelete: () => Navigator.of(context).pop(null)),
              TextButton(onPressed: () => Navigator.of(context).pop(_current), child: const Text('Fatto')),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                      Expanded(
                        child: TextField(
                          controller: _text,
                          undoController: _undo,
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
                    ],
                  ),
                ),
              ),
              NoteToolbar(undo: _undo, onList: _toggleList, dictation: _dictation, onPaste: _pasteDictation),
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
  const NoteToolbar({super.key, required this.undo, required this.onList, required this.dictation, required this.onPaste});

  final UndoHistoryController undo;
  final VoidCallback onList;
  final Entry? dictation;
  final VoidCallback onPaste;

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
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(
                scale: a,
                child: FadeTransition(opacity: a, child: c),
              ),
              child: dictation == null
                  ? const SizedBox.shrink()
                  : FilledButton.icon(
                      key: ValueKey(dictation!.at),
                      onPressed: onPaste,
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      icon: const Icon(Icons.mic_rounded, size: 18),
                      label: const Text('Incolla la dettatura'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
