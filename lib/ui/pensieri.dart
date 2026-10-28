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
          _Hint(top: 'Le tue note stanno qui.', bottom: 'Scrivine una con la matita, in basso.', color: tk.muted)
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

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Note get _current => widget.note.edited(title: _title.text, text: _text.text);

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
          body: Padding(
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
      ),
    );
  }
}
