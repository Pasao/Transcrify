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

/// I colori di Transcri: quelli del telefono (Material You), gli stessi della parte nativa.
/// Arrivano col primo stato letto; fino ad allora due toni neutri.
var transcriColors = [const Color(0xFF8AA4FF), const Color(0xFFC3A6F0)];

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
    if (state == AppLifecycleState.resumed) {
      // Il nativo dimentica il nido quando l'app va in pausa: al ritorno va detto di nuovo.
      Core.forgetNest();
      _load();
    }
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

  /// Le letture si possono accavallare: vale solo l'ultima, così una vecchia non fa scattare il nido indietro.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final list = await Core.history();
    final s = await Core.state();
    final w = await Core.waiting();
    if (!mounted || n != _loads) return;
    setState(() {
      entries = list.where((x) => !_deleting.contains(x.at)).toList();
      waiting = w;
      pillOn = s.pillOn;
      transcriColors = [s.accentA, s.accentB];
      if (s.accentMain != Tokens.blue) Tokens.useAccent(s.accentMain, s.accentSecond);
      limitedUntil = s.limited == null ? null : s.resetAt;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (result == 'removed') widget.onKeyRemoved();
    if (result == 'intro') widget.onReplayIntro();
    _load();
  }

  /// Le note appena cancellate: spariscono subito, ma per qualche secondo si possono riavere.
  /// Si cancellano davvero solo quando il messaggio "Annulla" se ne va.
  final _deleting = <DateTime>{};
  static const _undoTime = Duration(seconds: 5);

  Future<void> _delete(Entry e) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _deleting.add(e.at);
      entries = entries?.where((x) => !_deleting.contains(x.at)).toList();
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            content: const Row(children: [_Countdown(_undoTime), SizedBox(width: 14), Text('Nota eliminata')]),
            duration: _undoTime,
            action: SnackBarAction(label: 'Annulla', onPressed: () {}),
          ),
        )
        .closed;
    if (reason == SnackBarClosedReason.action) {
      HapticFeedback.selectionClick();
      _deleting.remove(e.at);
    } else {
      await Core.deleteEntry(e.at);
      _deleting.remove(e.at);
    }
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
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings_rounded), tooltip: 'Impostazioni'),
        ],
      ),
    );
    return Paper(child: Scaffold(
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
    ));
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
                            child: Text(_hm(entry.at), style: monoStyle(context), overflow: TextOverflow.clip),
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
            height: 40, // 40 × 40 come il tasto copia: le icone vicine hanno la stessa misura.
            constraints: const BoxConstraints(minWidth: 40),
            padding: EdgeInsets.symmetric(horizontal: armed ? 12 : 10),
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

/// Il nido di Transcri: la sua casa in fondo all'app. Lì sta seduto, respira, sbatte
/// gli occhi e si guarda intorno. Toccando il nido esce e vola al bordo; toccandolo di
/// nuovo torna, atterra con un sobbalzo e il nido si illumina.
class _PillLauncher extends StatefulWidget {
  const _PillLauncher({required this.on, required this.limitedUntil, required this.onChanged});

  final bool on;

  /// Se i minuti sono finiti: quando tornano. Il nido dorme fino ad allora.
  final DateTime? limitedUntil;
  final VoidCallback onChanged;

  @override
  State<_PillLauncher> createState() => _PillLauncherState();
}

class _PillLauncherState extends State<_PillLauncher> with TickerProviderStateMixin {
  static const _outroMs = 640; // come OUTRO_MS nel nativo
  static const _nestH = 96.0, _slot = 68.0, _pad = 14.0;

  // 0 = a riposo, 1 = schiacciato fino in fondo; al rilascio torna con una molla che rimbalza.
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  // Il ritorno a casa: sobbalzo di Transcri e luce nel nido.
  late final _land = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  // La rincorsa prima di uscire: si gonfia, e la bolla nativa parte da quella misura.
  late final _swell = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  final _transcriKey = GlobalKey();
  bool busy = false;
  bool? shownOn;

  /// Trascinandolo da fuori, Transcri è sopra il nido: la casa si accende per accoglierlo.
  bool _hot = false;

  @override
  void initState() {
    super.initState();
    Core.onNestHot((hot) {
      if (mounted) setState(() => _hot = hot);
    });
  }

  @override
  void dispose() {
    Core.onNestHot(null);
    Core.setNest(null);
    _carried?.remove();
    _press.dispose();
    _land.dispose();
    _swell.dispose();
    super.dispose();
  }

  /// Centro e rettangolo di Transcri nel nido, in pixel fisici dello schermo.
  (Offset, List<double>) _home() {
    final box = _transcriKey.currentContext!.findRenderObject() as RenderBox;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final tl = box.localToGlobal(Offset.zero) * ratio;
    final br = box.localToGlobal(box.size.bottomRight(Offset.zero)) * ratio;
    final c = Offset((tl.dx + br.dx) / 2, (tl.dy + br.dy) / 2);
    return (c, [tl.dx, tl.dy, br.dx, br.dy]);
  }

  /// I permessi si chiedono qui, la prima volta che serve Transcri.
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

  /// Spento solo se i minuti sono finiti e Transcri è a casa: richiamarlo si può sempre.
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

  /// Il rilascio: il nido rimbalza e, nel rimbalzo, Transcri parte (o torna).
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
    widget.onChanged();
  }

  // Lo stato mostrato resta quello voluto finché l'app non conferma lo stesso: niente testo che scatta.
  @override
  void didUpdateWidget(covariant _PillLauncher old) {
    super.didUpdateWidget(old);
    // Rientrato da solo (trascinato nel nido): atterra come quando lo richiami tu.
    if (old.on && !widget.on && !busy && shownOn == null) _landed();
    if (!busy && shownOn != null && shownOn == widget.on) shownOn = null;
  }

  /// L'arrivo nel nido: la bolla nativa ci si è tuffata dentro, qui lui rispunta.
  /// Il nido ne sente il peso: si schiaccia all'impatto e torna su con una molla, come quando lo premi tu.
  void _landed() {
    HapticFeedback.mediumImpact();
    _hot = false;
    _land.forward(from: 0);
    _press.value = 1;
    _press.animateBack(0, duration: const Duration(milliseconds: 620), curve: Curves.elasticOut);
  }

  /// Dice al nativo dov'è il nido, solo finché questa pagina è quella in primo piano.
  void _reportNest(bool visible) {
    if (!mounted) return;
    if (!visible || _transcriKey.currentContext == null) {
      Core.setNest(null);
      return;
    }
    Core.setNest(_home().$2);
  }

  Future<void> _launch(int g) async {
    if (!await _permissions()) return;
    if (g != _gen) return;
    await _swell.animateTo(1, curve: Curves.easeOutCubic);
    if (g != _gen || !mounted) return;
    // Il rettangolo misurato è già quello gonfio: la trasformazione conta.
    final (c, home) = _home();
    HapticFeedback.lightImpact();
    await Core.startPill(c.dx, c.dy, home: home);
    // La bolla nativa compare in qualche fotogramma: il nido si svuota solo quando lei lo copre già.
    await Future.delayed(const Duration(milliseconds: 90));
    if (g != _gen || !mounted) return;
    setState(() => shownOn = true);
    _swell.value = 0;
    await Future.delayed(const Duration(milliseconds: 540));
  }

  Future<void> _recall(int g) async {
    final (c, home) = _home();
    // Finché vola il nido resta vuoto; si riempie quando arriva.
    setState(() => shownOn = true);
    await Core.stopPill(x: c.dx, y: c.dy, home: home);
    await Future.delayed(const Duration(milliseconds: _outroMs - 20));
    if (g != _gen || !mounted) return;
    setState(() {
      shownOn = false;
      _landed();
    });
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // --- Tirarlo fuori a mano ---

  OverlayEntry? _carried;
  Offset _carryAt = Offset.zero;

  Future<void> _grab(Offset at) async {
    if (_blocked || (shownOn ?? widget.on) || busy) return;
    if (!await _permissions()) return;
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _press.animateBack(0);
    _carryAt = at;
    _carried = OverlayEntry(
      builder: (_) => Positioned(
        left: _carryAt.dx - _Transcri.w / 2,
        top: _carryAt.dy - _Transcri.h / 2,
        child: IgnorePointer(
          child: Transform.scale(scale: 1.15, child: _Transcri(away: false, sleeping: false, land: _land)),
        ),
      ),
    );
    Overlay.of(context).insert(_carried!);
    setState(() {});
  }

  void _carry(Offset at) {
    _carryAt = at;
    _carried?.markNeedsBuild();
  }

  Future<void> _drop(Offset at) async {
    final entry = _carried;
    if (entry == null) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final c = at * ratio;
    final hw = _Transcri.w * ratio / 2, hh = _Transcri.h * ratio / 2;
    final g = ++_gen;
    busy = true;
    _wantOut = true;
    setState(() => shownOn = true);
    await Core.startPill(c.dx, c.dy, home: [c.dx - hw, c.dy - hh, c.dx + hw, c.dy + hh], place: true);
    // Sparisce la copia sotto il dito quando la bolla nativa è già lì.
    await Future.delayed(const Duration(milliseconds: 90));
    entry.remove();
    _carried = null;
    if (!mounted) return;
    setState(() {});
    if (g != _gen) return;
    busy = false;
    _wantOut = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final on = shownOn ?? widget.on;
    final sleeping = _blocked;
    // Una pagina sopra (impostazioni, una nota aperta): il nido non si vede, non si rientra lì.
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportNest(visible));
    final (title, line) = sleeping
        ? ('Transcri dorme', 'Ha finito i minuti di oggi. Torna alle ${_hm(widget.limitedUntil!)}.')
        : on
        ? ('Transcri è fuori', 'Tocca qui per richiamarlo.')
        : ('Transcri', 'Toccalo e ti segue in ogni app.');
    // Il nido è neutro: il colore lo porta Transcri. Quando è fuori il nido resta vuoto.
    final home = (!on && !sleeping) || _hot;
    final fg = tk.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _release(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            // Premuto: il nido si abbassa appena. La molla elastica lo fa rimbalzare.
            final v = _press.value;
            return Transform.scale(scaleX: 1 - v * 0.02, scaleY: 1 - v * 0.06, child: child);
          },
          child: AnimatedScale(
            // Transcri sopra il nido: la casa si gonfia appena, pronta ad accoglierlo.
            scale: _hot ? 1.04 : 1,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  height: _nestH,
                  padding: const EdgeInsets.all(_pad),
                  decoration: BoxDecoration(
                    // Con lui a casa il nido prende i suoi colori, tutto; quando esce si spegne. Niente alone.
                    gradient: LinearGradient(
                      colors: [
                        for (final c in transcriColors) home ? Color.alphaBlend(c.withValues(alpha: 0.24), tk.surface) : tk.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(_nestH / 2 - 14),
                    border: Border.all(color: tk.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          // Il testo si stacca dalla curva del nido.
                          padding: const EdgeInsets.only(left: 10),
                          // Titolo e riga cambiano insieme, uno alla volta: il vecchio sparisce, poi entra il nuovo.
                          // Ognuno resta centrato per conto suo, quindi niente salti se le righe sono di più o di meno.
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: const Interval(0.45, 1, curve: Curves.easeOut),
                            switchOutCurve: const Interval(0.55, 1, curve: Curves.easeIn),
                            layoutBuilder: (current, previous) =>
                                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                            child: Column(
                              key: ValueKey(title),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: display(context, size: 19, color: fg)),
                                const SizedBox(height: 3),
                                Text(line, maxLines: 2, style: TextStyle(fontSize: 13, height: 1.3, color: tk.muted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Il posto di Transcri, a destra: prima si legge cosa fa, poi lo vedi.
                      // Toccandolo si gonfia un attimo (prende la rincorsa) e da lì parte.
                      SizedBox(
                        width: _slot,
                        height: _slot,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _swell,
                            builder: (context, child) => Transform.scale(scale: 1 + 0.3 * _swell.value, child: child),
                            child: GestureDetector(
                              onLongPressStart: (d) => _grab(d.globalPosition),
                              onLongPressMoveUpdate: (d) => _carry(d.globalPosition),
                              onLongPressEnd: (d) => _drop(d.globalPosition),
                              child: KeyedSubtree(
                                key: _transcriKey,
                                child: _Transcri(away: on || _carried != null, sleeping: sleeping, land: _land),
                              ),
                            ),
                          ),
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
    );
  }
}

/// Transcri a casa: una capsula bianca con due occhi. Respira, ogni tanto sbatte gli occhi,
/// si guarda intorno e fa un piccolo saltello. Quando è fuori resta il suo contorno;
/// quando dorme (minuti finiti) ha gli occhi chiusi e sta fermo.
class _Transcri extends StatefulWidget {
  const _Transcri({required this.away, required this.sleeping, required this.land});

  static const w = 46.0, h = 40.0;
  static const radius = 17.0;

  final bool away, sleeping;
  final Animation<double> land;

  @override
  State<_Transcri> createState() => _TranscriState();
}

class _TranscriState extends State<_Transcri> with SingleTickerProviderStateMixin {
  // Un ciclo di vita di 7 secondi: dentro ci sono respiro, battito d'occhi, sguardo e saltello.
  late final _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 7000))..repeat();

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _Transcri.w,
      height: _Transcri.h,
      child: AnimatedBuilder(
        animation: Listenable.merge([_life, widget.land]),
        builder: (context, _) => CustomPaint(
          painter: _TranscriPainter(
            t: _life.value,
            land: widget.land.value,
            away: widget.away,
            sleeping: widget.sleeping,
            outline: context.tk.faint,
          ),
        ),
      ),
    );
  }
}

class _TranscriPainter extends CustomPainter {
  _TranscriPainter({
    required this.t,
    required this.land,
    required this.away,
    required this.sleeping,
    required this.outline,
  });

  final double t, land;
  final bool away, sleeping;
  final Color outline;

  /// 0→1→0 dentro la finestra [a, b] del ciclo.
  double _bump(double a, double b) {
    if (t < a || t > b) return 0;
    return math.sin((t - a) / (b - a) * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (away) {
      // Il posto vuoto: contorno tratteggiato.
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_Transcri.radius)));
      final paint = Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final m in path.computeMetrics()) {
        // Trattini tutti uguali anche dove il contorno si chiude: il passo si adatta alla lunghezza.
        final n = (m.length / 6).round();
        final step = m.length / n;
        for (var i = 0; i < n; i++) {
          canvas.drawPath(m.extractPath(i * step, i * step + step / 2), paint);
        }
      }
      return;
    }
    final alive = !sleeping;
    // Respiro: due respiri per ciclo. Saltello verso la fine. Atterraggio: schiacciato e poi su.
    final breath = alive ? math.sin(t * math.pi * 4) * 0.025 : math.sin(t * math.pi * 2) * 0.012;
    final hop = alive ? _bump(0.88, 0.95) : 0.0;
    // Il ritorno: la bolla nativa si tuffa nel nido e sparisce; da lì lui rispunta piccolo,
    // si gonfia un attimo oltre la sua misura (si riprende il posto) e si sistema.
    final pop = land == 0 || land == 1 ? 1.0 : 0.4 + 0.6 * Curves.easeOutBack.transform(land);
    final sy = 1 + breath - hop * 0.04;
    final sx = 1 - breath * 0.6 + hop * 0.02;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale(pop);
    canvas.translate(-w / 2, -h / 2);
    canvas.translate(w / 2, h);
    canvas.scale(sx, sy);
    canvas.translate(-w / 2, -h - hop * 6);
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_Transcri.radius));
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in transcriColors) c.withValues(alpha: sleeping ? 0.5 : 1)],
        ).createShader(Offset.zero & size),
    );

    // Gli occhi: sbatte due volte per ciclo, guarda a destra e poi a sinistra.
    final look = alive ? (_bump(0.40, 0.58) * 2.2 - _bump(0.62, 0.76) * 2.2) : 0.0;
    final blink = alive ? math.max(_bump(0.20, 0.235), _bump(0.71, 0.745)) : 1.0;
    final eye = Paint()..color = Colors.white;
    // Stesse proporzioni degli occhi che disegna la parte nativa in volo: non cambia personaggio.
    final ey = h * 0.36;
    final r = math.min(w, h) * 0.075;
    for (final dx in [-w * 0.17, w * 0.17]) {
      final c = Offset(w / 2 + dx + look, ey);
      if (blink > 0.85 || sleeping) {
        // Occhi chiusi: un trattino.
        canvas.drawLine(
          c - Offset(r * 1.2, 0),
          c + Offset(r * 1.2, 0),
          eye
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 2.4 * (1 - blink)), eye);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TranscriPainter old) =>
      old.t != t || old.land != land || old.away != away || old.sleeping != sleeping || old.outline != outline;
}

/// Quanto manca prima che la nota se ne vada davvero: un cerchio che si consuma.
class _Countdown extends StatelessWidget {
  const _Countdown(this.duration);

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).snackBarTheme.actionTextColor ?? Theme.of(context).colorScheme.inversePrimary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: duration,
      builder: (context, left, _) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(value: left, strokeWidth: 2.5, color: color, backgroundColor: color.withValues(alpha: 0.2)),
      ),
    );
  }
}
