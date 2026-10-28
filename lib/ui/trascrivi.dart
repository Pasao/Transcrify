import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
import 'mode_icon.dart';
import 'theme.dart';

/// Trascrivi: quello che hai dettato, giorno per giorno. Oggi sta in basso, vicino al pollice.
class TrascriviPage extends StatefulWidget {
  const TrascriviPage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock: le schede non ci finiscono sotto.
  final double bottom;

  @override
  State<TrascriviPage> createState() => _TrascriviPageState();
}

class _TrascriviPageState extends State<TrascriviPage> {
  final Set<String> openDays = {};
  List<Entry>? entries;

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

  /// Le letture si possono accavallare: vale solo l'ultima.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final list = await Core.history();
    if (!mounted || n != _loads) return;
    setState(() => entries = list.where((x) => !_deleting.contains(x.at)).toList());
  }

  /// Le trascrizioni appena cancellate: spariscono subito, ma per qualche secondo si possono riavere.
  /// Si cancellano davvero solo quando il messaggio "Annulla" se ne va.
  final _deleting = <DateTime>{};

  Future<void> _delete(Entry e) async {
    setState(() {
      _deleting.add(e.at);
      entries = entries?.where((x) => !_deleting.contains(x.at)).toList();
    });
    if (!await undoable(context, 'Trascrizione eliminata')) await Core.deleteEntry(e.at);
    _deleting.remove(e.at);
    _load();
  }

  void _open(Entry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _EntrySheet(
        entry: e,
        onDelete: () async {
          Navigator.pop(sheet);
          await _delete(e);
        },
      ),
    );
  }

  /// Le trascrizioni in gruppi per giorno, dal più vecchio (in alto) a oggi (in basso, vicino al pollice).
  List<(String, List<Entry>)> _groups(List<Entry> list) {
    final out = <(String, List<Entry>)>[];
    for (final e in list) {
      final label = dayLabel(e.at);
      if (out.isNotEmpty && out.last.$1 == label) {
        out.last.$2.add(e);
      } else {
        out.add((label, [e]));
      }
    }
    return out.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final list = entries;
    return list == null
        ? const SizedBox.shrink()
        : list.isEmpty
        // Da vuota la pagina non scorre: non c'è niente sotto.
        ? _Empty(bottom: widget.bottom)
        // Le schede stanno in basso, dove arriva il pollice; se sono tante, si scorre.
        : LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              // Si apre dal fondo: oggi è subito lì.
              reverse: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final (label, items) in _groups(list)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(label, style: display(context, size: 24)),
                            const SizedBox(width: 10),
                            Text('${items.length}', style: monoStyle(context, color: tk.faint)),
                            const Spacer(),
                            if (items.length >= 4)
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: tk.muted),
                                onPressed: () => setState(() => openDays.contains(label) ? openDays.remove(label) : openDays.add(label)),
                                iconAlignment: IconAlignment.end,
                                icon: AnimatedRotation(
                                  turns: openDays.contains(label) ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  child: const Icon(Icons.expand_more_rounded, size: 20),
                                ),
                                label: Text(openDays.contains(label) ? 'Chiudi' : 'Tutte'),
                              ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: openDays.contains(label)
                            // Il giorno aperto: due colonne, si legge tutto senza scorrere di lato.
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    final w = (box.maxWidth - 10) / 2;
                                    return Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final e in items)
                                          _MiniCard(
                                            key: ValueKey(e.at),
                                            entry: e,
                                            width: w,
                                            onOpen: () => _open(e),
                                            onDelete: () => _delete(e),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              )
                            : SizedBox(
                                height: 176,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (_, i) => _MiniCard(
                                    key: ValueKey(items[i].at),
                                    entry: items[i],
                                    onOpen: () => _open(items[i]),
                                    onDelete: () => _delete(items[i]),
                                  ),
                                ),
                              ),
                      ),
                    ],
                    SizedBox(height: widget.bottom + 24),
                  ],
                ),
              ),
            ),
          );
  }
}

/// Stato vuoto: un giorno ancora senza schede e una frase. Sta in basso, vicino al bottone.
class _Empty extends StatelessWidget {
  const _Empty({required this.bottom});

  final double bottom;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Oggi', style: display(context, size: 24, color: tk.faint)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[_Ghost(opacity: 1 - i * 0.3), const SizedBox(width: 10)],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Quello che detti compare qui,\ngiorno per giorno.', style: t.bodyLarge?.copyWith(color: tk.muted)),
        ],
      ),
    );
  }
}

/// Una scheda vuota, solo la sagoma: suggerisce cosa arriverà senza fingere un contenuto.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget line(double w) => Container(
      width: w,
      height: 8,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: tk.border, borderRadius: BorderRadius.circular(4)),
    );
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 180,
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(140), line(118), line(80), const Spacer(), line(36)]),
      ),
    );
  }
}

/// Scheda piccola nel carosello del giorno.
/// Tenendo premuto il cestino la scheda si fa rossa, trema e sparisce.
class _MiniCard extends StatefulWidget {
  const _MiniCard({super.key, required this.entry, required this.onOpen, required this.onDelete, this.width = 240});

  final Entry entry;
  final double width;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard> with SingleTickerProviderStateMixin {
  late final _gone = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void dispose() {
    _gone.dispose();
    super.dispose();
  }

  // Fino a questo punto lasciare annulla; dopo, la scheda è andata.
  static const _commit = 0.6;
  bool _committed = false;

  void _holdStart() {
    _committed = false;
    HapticFeedback.selectionClick();
    _gone.animateTo(_commit, duration: const Duration(milliseconds: 700), curve: Curves.linear).then((_) {
      if (!mounted || _gone.value < _commit) return;
      _committed = true;
      HapticFeedback.heavyImpact();
      _gone.animateTo(1, duration: const Duration(milliseconds: 420), curve: Curves.easeIn).then((_) {
        if (mounted) widget.onDelete();
      });
    });
  }

  void _holdEnd() {
    if (_committed) return;
    // Ripensamento: torna com'era.
    _gone.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final entry = widget.entry;
    return AnimatedBuilder(
      animation: _gone,
      builder: (context, child) {
        final v = _gone.value;
        // Prima si arrossa e trema, poi si rimpicciolisce e svanisce.
        // Fino alla soglia: si arrossa e trema sempre di più. Dopo: smette di tremare e svanisce.
        final hold = (v / _commit).clamp(0.0, 1.0);
        final red = hold;
        final shake = v < _commit ? math.sin(v * 140) * 5 * hold : 0.0;
        final out = Curves.easeIn.transform(((v - _commit) / (1 - _commit)).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Opacity(
            opacity: 1 - out,
            child: Transform.scale(
              scale: 1 - out * 0.25,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Tokens.red.withValues(alpha: red * 0.55), BlendMode.srcATop),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _card(context, tk, entry),
    );
  }

  Widget _card(BuildContext context, Tokens tk, Entry entry) {
    final onOpen = widget.onOpen;
    return SizedBox(
      width: widget.width,
      height: 176,
      child: Material(
        color: tk.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: entry.text));
            // Il messaggio "copiato" lo mostra già Android: qui basta la vibrazione.
            HapticFeedback.mediumImpact();
          },
          child: Padding(
            // Il cestino non sta attaccato all'angolo: lo stesso respiro del testo, a destra e sotto.
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      entry.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Row(
                  children: [
                    // A sinistra ora e modo: si stringono loro se la scheda è stretta (vista "Tutte").
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(hm(entry.at), style: monoStyle(context), overflow: TextOverflow.clip),
                          ),
                          if (entry.mode != null) ...[const SizedBox(width: 8), _ModeTag(entry.mode!)],
                        ],
                      ),
                    ),
                    DeleteButton(onDelete: widget.onDelete, onHoldStart: _holdStart, onHoldEnd: _holdEnd),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Con che modo è stata pulita la trascrizione: l'icona, e nel testo aperto anche il nome.
class _ModeTag extends StatelessWidget {
  const _ModeTag(this.mode, {this.label = false});

  final String mode;
  final bool label;

  static const _names = {'fedele': 'Fedele', 'pulita': 'Pulita', 'riassunto': 'Riassunto'};

  @override
  Widget build(BuildContext context) {
    final color = context.tk.muted;
    final icon = CustomPaint(size: const Size(16, 13), painter: ModeIcon(mode, color));
    if (!label) return Tooltip(message: _names[mode] ?? mode, child: icon);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(_names[mode] ?? mode, style: monoStyle(context, size: 12, color: color)),
      ],
    );
  }
}

/// Il testo intero, aperto dal basso. Copia ed elimina stanno in alto: con i testi lunghi sono subito lì.
class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.entry, required this.onDelete});

  final Entry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 12, 40),
        children: [
          Row(
            children: [
              Text('${dayLabel(entry.at)}, ${hm(entry.at)}', style: monoStyle(context, size: 12)),
              if (entry.mode != null) ...[const SizedBox(width: 10), _ModeTag(entry.mode!, label: true)],
              const Spacer(),
              DeleteButton(onDelete: onDelete),
              CopyButton(text: entry.text),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
            child: SelectableText(entry.text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
