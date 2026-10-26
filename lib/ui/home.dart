import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/native.dart';
import 'mode_icon.dart';
import 'settings.dart';
import 'theme.dart';

const _days = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
const _months = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Ieri';
  if (diff < 7) return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  if (d.year == now.year) return '${d.day} ${_months[d.month - 1]}';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onKeyRemoved, required this.onReplayIntro});

  final VoidCallback onKeyRemoved;
  final VoidCallback onReplayIntro;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Set<String> openDays = {};
  List<Entry>? entries;
  List<Waiting> waiting = [];
  bool flushing = false;
  bool pillOn = false;
  DateTime? limitedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Core.onChanged(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  /// "Riprova ora": trascrive quello che è rimasto indietro.
  Future<void> _flush() async {
    final w = await Core.waiting();
    if (w.isEmpty || flushing) return;
    setState(() => flushing = true);
    await Core.flushWaiting();
    if (!mounted) return;
    setState(() => flushing = false);
    _load();
  }

  Future<void> _load() async {
    final list = await Core.history();
    final s = await Core.state();
    final w = await Core.waiting();
    if (!mounted) return;
    setState(() {
      entries = list;
      waiting = w;
      pillOn = s.pillOn;
      limitedUntil = s.limited == null ? null : s.resetAt;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (result == 'removed') widget.onKeyRemoved();
    _load();
  }

  Future<void> _delete(Entry e) async {
    HapticFeedback.mediumImpact();
    await Core.deleteEntry(e.at);
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
      final label = _dayLabel(e.at);
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
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text('Transcrify', style: display(context, size: 26))),
          TextButton(
            onPressed: widget.onReplayIntro,
            style: TextButton.styleFrom(
              foregroundColor: Tokens.blue,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Come funziona'),
          ),
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings_rounded), tooltip: 'Impostazioni'),
        ],
      ),
    );
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                header,
                Expanded(
                  child: list == null
                      ? const SizedBox.shrink()
                      : list.isEmpty && waiting.isEmpty
                      // Da vuota la pagina non scorre: non c'è niente sotto.
                      ? const _Empty()
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
                                              onPressed: () => setState(
                                                () => openDays.contains(label)
                                                    ? openDays.remove(label)
                                                    : openDays.add(label),
                                              ),
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
                                  if (waiting.isNotEmpty)
                                    _WaitingList(
                                      items: waiting,
                                      busy: flushing,
                                      onRetry: _flush,
                                      onDiscard: (w) async {
                                        await Core.discardWaiting(w.id);
                                        _load();
                                      },
                                    ),
                                  const SizedBox(height: 200),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _PillLauncher(on: pillOn, limitedUntil: limitedUntil, onChanged: _load),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registrazioni salvate ma non ancora trascritte: aspettano la rete. Non si perdono.
class _WaitingList extends StatelessWidget {
  const _WaitingList({required this.items, required this.busy, required this.onRetry, required this.onDiscard});

  final List<Waiting> items;
  final bool busy;
  final VoidCallback onRetry;
  final ValueChanged<Waiting> onDiscard;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        decoration: BoxDecoration(
          color: Tokens.yellow.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Tokens.yellow.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('In attesa', style: display(context, size: 20))),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(onPressed: onRetry, child: const Text('Riprova ora')),
              ],
            ),
            Text('Registrazioni salvate che non sono riuscite a partire. Riprova quando hai rete.', style: t.bodySmall),
            const SizedBox(height: 6),
            for (final w in items)
              Row(
                children: [
                  const Icon(Icons.graphic_eq_rounded, size: 18, color: Tokens.yellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_dayLabel(w.at)}, ${_hm(w.at)} · ${_duration(w.seconds)}',
                      style: t.bodyMedium?.copyWith(color: tk.text),
                    ),
                  ),
                  DeleteButton(onDelete: () => onDiscard(w)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _duration(int s) => s < 60 ? '$s s' : '${s ~/ 60} min ${s % 60 > 0 ? '${s % 60} s' : ''}'.trim();
}

/// Stato vuoto: un giorno ancora senza schede e una frase. Sta in basso, vicino al bottone.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 220),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [line(140), line(118), line(80), const Spacer(), line(36)],
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
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
                            child: Text(_hm(entry.at), style: monoStyle(context), overflow: TextOverflow.clip),
                          ),
                          if (entry.mode != null) ...[const SizedBox(width: 8), _ModeTag(entry.mode!)],
                        ],
                      ),
                    ),
                    DeleteButton(onDelete: widget.onDelete, onHoldStart: _holdStart, onHoldEnd: _holdEnd),
                    CopyButton(text: entry.text),
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
    final color = Tokens.blue.withValues(alpha: 0.85);
    final icon = CustomPaint(size: const Size(14, 11), painter: ModeIcon(mode, color));
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

/// Copia: diventa una ✓ verde per un attimo.
class CopyButton extends StatefulWidget {
  const CopyButton({super.key, required this.text});

  final String text;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool done = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.selectionClick();
    setState(() => done = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => done = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      onPressed: _copy,
      tooltip: 'Copia',
      iconSize: 20,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done
            ? const Icon(Icons.check_rounded, key: ValueKey(1), size: 22, color: Tokens.green)
            : Icon(Icons.content_copy_rounded, key: const ValueKey(0), size: 20, color: context.tk.muted),
      ),
    );
  }
}

/// Cestino sicuro: un tocco lo arma (diventa rosso), un secondo tocco cancella.
/// Tenendolo premuto cancella subito, per chi deve fare pulizia in fretta.
class DeleteButton extends StatefulWidget {
  const DeleteButton({super.key, required this.onDelete, this.onHoldStart, this.onHoldEnd});

  final VoidCallback onDelete;

  /// Tenendo premuto: inizia e finisce la pressione (la scheda decide se è abbastanza).
  /// Se mancano, tenere premuto cancella subito.
  final VoidCallback? onHoldStart, onHoldEnd;

  @override
  State<DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<DeleteButton> {
  bool armed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _tap() {
    if (armed) return widget.onDelete();
    HapticFeedback.selectionClick();
    setState(() => armed = true);
    _disarm?.cancel();
    _disarm = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => armed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (armed) setState(() => armed = false);
      },
      child: Semantics(
        button: true,
        label: armed ? 'Tocca ancora per eliminare' : 'Elimina, tieni premuto per eliminare subito',
        child: GestureDetector(
          onTap: _tap,
          onLongPressStart: widget.onHoldStart == null ? null : (_) => widget.onHoldStart!(),
          onLongPressEnd: widget.onHoldEnd == null ? null : (_) => widget.onHoldEnd!(),
          onLongPress: widget.onHoldStart == null ? widget.onDelete : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: EdgeInsets.symmetric(horizontal: armed ? 12 : 8),
            decoration: BoxDecoration(
              color: armed ? Tokens.red : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  armed ? Icons.delete_rounded : Icons.delete_outline_rounded,
                  size: 20,
                  color: armed ? Colors.white : context.tk.faint,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: armed
                      ? const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            'Elimina',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
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
              Text('${_dayLabel(entry.at)}, ${_hm(entry.at)}', style: monoStyle(context, size: 12)),
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

/// Il bottone che fa uscire la pillola. Tenendolo premuto si schiaccia; lasciandolo
/// rimbalza e fa saltare fuori la bolla, che nasce dentro il bottone (dove non si vede)
/// e ne esce schizzando qualche goccia. Al ritorno la bolla si tuffa dentro.
class _PillLauncher extends StatefulWidget {
  const _PillLauncher({required this.on, required this.limitedUntil, required this.onChanged});

  final bool on;

  /// Se i minuti sono finiti: quando tornano. Il bottone si spegne fino ad allora.
  final DateTime? limitedUntil;
  final VoidCallback onChanged;

  @override
  State<_PillLauncher> createState() => _PillLauncherState();
}

class _PillLauncherState extends State<_PillLauncher> with TickerProviderStateMixin {
  static const _buttonW = 252.0, _buttonH = 58.0;
  static const _outroMs = 640; // come OUTRO_MS nel nativo

  late final _drops = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  // 0 = a riposo, 1 = schiacciato fino in fondo; al rilascio torna con una molla che rimbalza.
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  final _buttonKey = GlobalKey();
  bool busy = false;
  bool inward = false;
  bool? shownOn;

  @override
  void dispose() {
    _drops.dispose();
    _press.dispose();
    super.dispose();
  }

  /// Centro e rettangolo della capsula di casa, in pixel fisici dello schermo.
  (Offset, List<double>) _home() {
    final box = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final c = box.localToGlobal(_homeCenter) * ratio;
    final w = _homeW * ratio / 2, h = _homeH * ratio / 2;
    return (c, [c.dx - w, c.dy - h, c.dx + w, c.dy + h]);
  }

  // Dove sta la capsula dentro il bottone (vedi _Button: margine 22, casella larga 16).
  static const _homeCenter = Offset(22 + 8, _buttonH / 2);
  static const _homeW = 10.0, _homeH = 30.0;

  /// I permessi si chiedono qui, la prima volta che serve la pillola.
  Future<bool> _permissions() async {
    if (!await Permission.microphone.isGranted) {
      final s = await Permission.microphone.request();
      await Permission.notification.request();
      if (!s.isGranted) {
        if (s.isPermanentlyDenied) await openAppSettings();
        return false;
      }
    }
    if (!await Core.canDrawOverlays()) {
      if (!mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Un ultimo permesso'),
          content: const Text(
            'Per stare sul bordo dello schermo, Transcrify deve poter “mostrare sopra altre app”. '
            'Nella prossima schermata attivalo e torna qui.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non ora')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apri')),
          ],
        ),
      );
      if (go == true) await Core.openOverlaySettings();
      return false;
    }
    return true;
  }

  /// Spento solo se i minuti sono finiti e la pillola è dentro: richiamarla si può sempre.
  bool get _blocked => widget.limitedUntil != null && !(_wantOut ?? widget.on);

  /// Dove l'ultimo tocco vuole Transcri: fuori (true) o a casa (false). Null = nessun tocco in corso.
  bool? _wantOut;

  /// Ogni tocco apre una generazione nuova. I passi ancora in sospeso di quella vecchia
  /// se ne accorgono e si fermano: così un tocco può interrompere un'animazione a metà.
  int _gen = 0;

  void _down() {
    if (_blocked) return;
    HapticFeedback.selectionClick();
    _press.animateTo(1, curve: Curves.easeOut);
  }

  /// Il rilascio: il bottone rimbalza su e, nel rimbalzo, Transcri parte (o torna).
  /// Funziona anche a metà di un volo: il nuovo parte da dove si trova la bolla.
  void _release() {
    if (_blocked) return;
    _press.animateBack(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
    _go();
  }

  void _cancel() => _press.animateBack(0, duration: const Duration(milliseconds: 200));

  Future<void> _go() async {
    final out = !(_wantOut ?? widget.on);
    _wantOut = out;
    final g = ++_gen;
    busy = true;
    if (out) {
      await _launch(g);
    } else {
      await _recall(g);
    }
    // Solo l'ultima generazione chiude: se nel frattempo c'è stato un altro tocco, tocca a lui.
    if (g != _gen || !mounted) return;
    busy = false;
    _wantOut = null;
    setState(() => shownOn = null);
    widget.onChanged();
  }

  Future<void> _launch(int g) async {
    if (!await _permissions()) return;
    if (g != _gen) return;
    final (c, home) = _home();
    HapticFeedback.lightImpact();
    await Core.startPill(c.dx, c.dy, home: home);
    // La bolla nativa copre la capsula in un paio di fotogrammi: allora la casa resta vuota.
    await Future.delayed(const Duration(milliseconds: 50));
    if (g != _gen || !mounted) return;
    setState(() {
      inward = false;
      shownOn = true;
    });
    // Si stacca dalla capsula: lo schizzo.
    await Future.delayed(const Duration(milliseconds: 40));
    if (g != _gen) return;
    HapticFeedback.selectionClick();
    _drops.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _recall(int g) async {
    final (c, home) = _home();
    // Finché vola la casa resta vuota; si riempie quando arriva.
    setState(() => shownOn = true);
    await Core.stopPill(x: c.dx, y: c.dy, home: home);
    await Future.delayed(const Duration(milliseconds: _outroMs - 20));
    if (g != _gen || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      inward = true;
      shownOn = false;
    });
    _drops.forward(from: 0);
    _press.value = 0.7;
    _press.animateBack(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final on = shownOn ?? widget.on;
    return SizedBox(
      height: _buttonH + 120,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 24 + _buttonH + 14,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _blocked
                  ? Text(
                      'Hai finito i minuti di trascrizione di oggi.',
                      key: const ValueKey('limit'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tk.muted),
                    )
                  : AnimatedOpacity(
                      key: const ValueKey('hint'),
                      opacity: on && !busy ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        'Transcri è sul bordo dello schermo. Puoi chiudere l\'app.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tk.muted),
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 24,
            child: GestureDetector(
              onTapDown: (_) => _down(),
              onTapUp: (_) => _release(),
              onTapCancel: _cancel,
              child: AnimatedBuilder(
                animation: _press,
                builder: (context, child) {
                  // Schiacciato: più basso e un filo più largo. La molla elastica lo fa rimbalzare oltre.
                  final v = _press.value;
                  return Transform.scale(scaleX: 1 + v * 0.04, scaleY: 1 - v * 0.14, child: child);
                },
                child: KeyedSubtree(
                  key: _buttonKey,
                  child: _Button(
                    on: on,
                    until: _blocked ? widget.limitedUntil : null,
                    width: _buttonW,
                    height: _buttonH,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            height: _buttonH + 110,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _drops,
                builder: (_, _) => CustomPaint(
                  painter: _SplashPainter(
                    t: _drops.value,
                    inward: inward,
                    button: const Size(_buttonW, _buttonH),
                    color: Tokens.blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Il bottone stesso: blu pieno quando la pillola è dentro, blu tenue quando è fuori.
class _Button extends StatelessWidget {
  const _Button({required this.on, required this.until, required this.width, required this.height});

  final bool on;
  final DateTime? until;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    if (until != null) {
      // Minuti finiti: spento, con l'ora in cui torna.
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        height: height,
        decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(height / 2)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 20, color: tk.muted),
            const SizedBox(width: 10),
            Text(
              'Si ricarica alle ${_hm(until!)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tk.muted),
            ),
          ],
        ),
      );
    }
    final fg = on ? Tokens.blue : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      padding: const EdgeInsets.only(left: 22, right: 26),
      decoration: BoxDecoration(
        color: on ? Tokens.blue.withValues(alpha: 0.12) : Tokens.blue,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: on
            ? null
            : [BoxShadow(color: Tokens.blue.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          // Transcri abita nel bottone: quando esce, il suo posto resta vuoto.
          _Home(out: on, color: fg),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              on ? 'Richiama Transcri' : 'Fai uscire Transcri',
              style: display(context, size: 18, color: fg).copyWith(letterSpacing: -0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// La casa di Transcri dentro il bottone: una capsula che respira piano.
/// Quando Transcri è fuori resta solo il contorno tratteggiato del suo posto.
class _Home extends StatefulWidget {
  const _Home({required this.out, required this.color});

  final bool out;
  final Color color;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 34,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (_, _) {
          final b = Curves.easeInOut.transform(_breath.value);
          return CustomPaint(
            painter: _HomePainter(out: widget.out, color: widget.color, scale: widget.out ? 1 : 0.88 + 0.12 * b),
          );
        },
      ),
    );
  }
}

class _HomePainter extends CustomPainter {
  _HomePainter({required this.out, required this.color, required this.scale});

  final bool out;
  final Color color;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final w = 10.0, h = 30.0 * scale;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: h), Radius.circular(w / 2));
    if (!out) {
      canvas.drawRRect(r, Paint()..color = color);
      return;
    }
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HomePainter old) => old.out != out || old.color != color || old.scale != scale;
}

/// Lo schizzo nel punto in cui la bolla attraversa l'estremità destra del bottone.
/// Le gocce partono a ventaglio nella direzione del volo (o, al ritorno, all'indietro
/// e in alto), cadono per gravità e si allungano nella direzione in cui vanno.
/// Intorno al punto, un'increspatura sul bordo del bottone.
class _SplashPainter extends CustomPainter {
  _SplashPainter({required this.t, required this.inward, required this.button, required this.color});

  final double t;
  final bool inward;
  final Size button;
  final Color color;

  // angolo (gradi, 0 = destra, -90 = su), velocità (px/s), raggio
  // In uscita: verso l'alto e un po' a destra, dove va la bolla.
  static const _out = [
    (-80.0, 420.0, 4.2),
    (-62.0, 380.0, 3.4),
    (-96.0, 340.0, 3.0),
    (-48.0, 300.0, 2.6),
    (-70.0, 260.0, 2.2),
    (-108.0, 240.0, 2.0),
    (-38.0, 220.0, 1.8),
    (-86.0, 180.0, 1.6),
  ];
  // Al ritorno: una corona che si apre da entrambi i lati.
  static const _back = [
    (-130.0, 340.0, 3.6),
    (-50.0, 340.0, 3.6),
    (-150.0, 280.0, 2.6),
    (-30.0, 280.0, 2.6),
    (-110.0, 230.0, 2.2),
    (-70.0, 230.0, 2.2),
    (-165.0, 200.0, 1.8),
    (-15.0, 200.0, 1.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final secs = t * 0.7;
    const g = 900.0;
    final center = Offset(size.width / 2, size.height - button.height / 2);
    // La capsula di casa: a sinistra nel bottone, lo schizzo parte dalla sua cima.
    final origin = center + Offset(-button.width / 2 + 30, -15);

    // Increspatura: un anello che si allarga e svanisce.
    final ring = Curves.easeOut.transform((t / 0.55).clamp(0.0, 1.0));
    if (ring < 1) {
      canvas.drawCircle(
        origin,
        8 + 34 * ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - ring)
          ..color = color.withValues(alpha: 0.5 * (1 - ring)),
      );
    }

    for (final (deg, speed, r0) in inward ? _back : _out) {
      final a = deg * math.pi / 180;
      final v = Offset(math.cos(a), math.sin(a)) * speed;
      final p = origin + v * secs + Offset(0, 0.5 * g * secs * secs);
      final vel = v + Offset(0, g * secs);
      final life = (1 - t).clamp(0.0, 1.0);
      final r = r0 * (0.4 + 0.6 * life);
      // Goccia allungata lungo la velocità: una capsula ruotata.
      final stretch = 1 + (vel.distance / 600).clamp(0.0, 1.4);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.atan2(vel.dy, vel.dx));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 2 * stretch, height: r * 2),
          Radius.circular(r),
        ),
        Paint()..color = color.withValues(alpha: 0.95 * math.min(1, life * 1.6)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.t != t || old.inward != inward;
}
