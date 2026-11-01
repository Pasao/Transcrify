import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
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

/// Il rosso di quando ascolta e il verde di quando ha finito: quelli della pillola.
var transcriRed = Tokens.red, transcriGreen = Tokens.green;

/// Transcri che lavora, dentro l'app: sempre questo cerchio, come la pillola sul bordo.
/// Quando ascolta è rosso e si allarga appena con la voce; quando trascrive i suoi colori scorrono e
/// dal bordo escono onde; quando ha finito è verde. Non occupa più spazio: cresce sopra quello che ha intorno.
class VoiceCircle extends StatefulWidget {
  const VoiceCircle({super.key, required this.phase, required this.size, this.child});

  /// "RECORDING", "PROCESSING" o "SUCCESS".
  final String phase;
  final double size;
  final Widget? child;

  @override
  State<VoiceCircle> createState() => _VoiceCircleState();
}

class _VoiceCircleState extends State<VoiceCircle> with SingleTickerProviderStateMixin {
  // Lo stesso giro della pillola: 1,6 secondi.
  late final _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  // Il volume arriva a scatti e gli stati cambiano di colpo: il cerchio li insegue, così non scatta mai.
  double _voice = 0, _work = 0;
  Color? _tint;

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, child) {
          final listening = widget.phase == 'RECORDING';
          final working = widget.phase == 'PROCESSING';
          _voice += ((listening ? Core.live.value.level : 0) - _voice) * 0.25;
          _work += ((working ? 1 : 0) - _work) * 0.12;
          final target = listening ? transcriRed : (widget.phase == 'SUCCESS' ? transcriGreen : transcriColors.first);
          _tint = Color.lerp(_tint ?? target, target, 0.14);
          return CustomPaint(
            painter: _VoicePainter(_tint!, _voice, _work, _flow.value),
            child: child,
          );
        },
        child: widget.child == null ? null : Center(child: widget.child),
      ),
    );
  }
}

class _VoicePainter extends CustomPainter {
  _VoicePainter(this.tint, this.voice, this.work, this.flow);

  final Color tint;
  final double voice, work, flow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width / 2 * (1 + voice * 0.14);
    final path = Path();
    const steps = 90;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      // Le onde vanno solo verso fuori, mai dentro: nessuna ammaccatura, come nella pillola.
      final r = base * (1 + work * 0.09 * (0.5 + 0.5 * math.sin(3 * a - flow * math.pi * 2)));
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = tint);
    if (work > 0.01) {
      // I due toni che si inseguono dall'alto in basso.
      final h = size.height;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              for (final k in [transcriColors[0], transcriColors[1], transcriColors[0]]) k.withValues(alpha: work.clamp(0.0, 1.0)),
            ],
            tileMode: TileMode.repeated,
          ).createShader(Rect.fromLTWH(0, h * flow - h, size.width, h)),
      );
    }
  }

  @override
  bool shouldRepaint(_VoicePainter old) => old.tint != tint || old.voice != voice || old.work != work || old.flow != flow;
}

String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String dayLabel(DateTime d) {
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

/// Giorno e ora in poco spazio, per le schede strette: «Oggi, 22:46», «28 ott, 14:47».
String shortStamp(DateTime d) {
  final day = dayLabel(d);
  final short = day == 'Oggi' || day == 'Ieri' ? day : '${d.day} ${_months[d.month - 1].substring(0, 3)}';
  return '$short, ${hm(d)}';
}

/// La barra delle cose scelte: quante sono, e cosa farne. Come in Samsung Note, in fondo, sopra il Dock.
class SelectionBar extends StatefulWidget {
  const SelectionBar({super.key, required this.label, required this.onClose, required this.actions});

  /// "1 nota", "3 trascrizioni".
  final String label;
  final VoidCallback onClose;
  final List<(IconData, String, VoidCallback)> actions;

  @override
  State<SelectionBar> createState() => _SelectionBarState();
}

class _SelectionBarState extends State<SelectionBar> {
  // La barra prende il posto di «Annulla», se c'è: lui sale, e quando la barra se ne va torna giù.
  static const _height = 68.0;

  void _lift(double by) => WidgetsBinding.instance.addPostFrameCallback((_) => _undoLift.value = by);

  @override
  void initState() {
    super.initState();
    _lift(_height);
  }

  @override
  void dispose() {
    _lift(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(32), boxShadow: islandShadow),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Annulla',
          ),
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          for (final (icon, name, onTap) in widget.actions)
            IconButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              tooltip: name,
              icon: Icon(icon, color: name == 'Elimina' ? const Color(0xFFFF8A70) : Colors.white),
            ),
        ],
      ),
    );
  }
}

/// Il simbolino di un testo arrivato da fuori: una nuvoletta con la cornetta, per i vocali di WhatsApp.
class SourceIcon extends StatelessWidget {
  const SourceIcon(this.source, {super.key, this.size = 14});

  final String? source;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (source != 'whatsapp') return const SizedBox.shrink();
    final color = context.tk.muted;
    return Tooltip(
      message: 'Da WhatsApp',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BubblePainter(color),
          child: Center(child: Icon(Icons.call_rounded, size: size * 0.52, color: color)),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.round;
    final circle = Path()..addOval(Rect.fromCircle(center: Offset(s * 0.52, s * 0.48), radius: s * 0.42));
    final tail = Path()
      ..moveTo(s * 0.26, s * 0.76)
      ..lineTo(s * 0.08, s * 0.94)
      ..lineTo(s * 0.46, s * 0.89);
    canvas.drawPath(Path.combine(PathOperation.union, circle, tail), pen);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
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
            decoration: BoxDecoration(color: armed ? Tokens.red : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(armed ? Icons.delete_rounded : Icons.delete_outline_rounded, size: 20, color: armed ? Colors.white : context.tk.faint),
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

/// Quanto manca prima che la nota se ne vada davvero: un cerchio che si consuma.
class Countdown extends StatelessWidget {
  const Countdown(this.duration, {super.key});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = Tokens.blue;
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

/// Quanto resta il messaggio "Annulla" dopo un'eliminazione.
const undoTime = Duration(seconds: 5);

/// Di quanto sale «Annulla» sopra la sua posizione: la barra di selezione, quando c'è, gli prende il posto.
final _undoLift = ValueNotifier<double>(0);

/// Chiude l'«Annulla» in corso: ce n'è uno solo alla volta.
void Function()? _closeUndo;

/// Una cosa appena eliminata: «Annulla» per qualche secondo, con il cerchio che si consuma.
/// Sta sopra il Dock, senza coprirlo. Restituisce true se l'hai ripresa; altrimenti si può cancellare davvero.
Future<bool> undoable(BuildContext context, String label) {
  HapticFeedback.mediumImpact();
  _closeUndo?.call();
  final done = Completer<bool>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _UndoPill(
      label: label,
      onDone: (again) {
        entry.remove();
        if (again) HapticFeedback.selectionClick();
        done.complete(again);
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return done.future;
}

class _UndoPill extends StatefulWidget {
  const _UndoPill({required this.label, required this.onDone});

  final String label;
  final ValueChanged<bool> onDone;

  @override
  State<_UndoPill> createState() => _UndoPillState();
}

class _UndoPillState extends State<_UndoPill> with SingleTickerProviderStateMixin {
  late final _show = AnimationController(vsync: this, duration: const Duration(milliseconds: 180))..forward();
  late final Timer _timer = Timer(undoTime, () => _leave(false));
  bool _leaving = false;

  /// Dove l'hai portata col dito. Abbastanza lontano, o con uno scatto, e se ne va: l'eliminazione resta.
  Offset _drag = Offset.zero;

  void _dragEnd(DragEndDetails d) {
    if (_drag.distance > 36 || d.velocity.pixelsPerSecond.distance > 400) {
      _leave(false);
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  void initState() {
    super.initState();
    _timer;
    _closeUndo = () => _leave(false);
  }

  Future<void> _leave(bool again) async {
    if (_leaving) return;
    _leaving = true;
    _timer.cancel();
    _closeUndo = null;
    await _show.reverse();
    widget.onDone(again);
  }

  @override
  void dispose() {
    _timer.cancel();
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = dockIsland + 12 + MediaQuery.viewPaddingOf(context).bottom + 8;
    return ValueListenableBuilder<double>(
      valueListenable: _undoLift,
      builder: (context, lift, child) => AnimatedPositioned(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        left: 16,
        right: 16,
        bottom: bottom + lift,
        child: child!,
      ),
      child: Center(
        child: FadeTransition(
          opacity: _show,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _drag += d.delta),
            onPanEnd: _dragEnd,
            child: Transform.translate(
              offset: _drag,
              child: Material(
            color: const Color(0xFF242424),
            borderRadius: BorderRadius.circular(24),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Countdown(undoTime),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Tokens.blue),
                    onPressed: () => _leave(true),
                    child: const Text('Annulla'),
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il colore delle isole che galleggiano sopra la pagina (il Dock, la casa di Transcri):
/// bianco di giorno; di notte un tono sopra il grigio delle schede delle note, o si confondono.
Color islandColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF353533) : Colors.white;

/// L'ombra delle isole: una larga e morbida che le solleva, e una stretta che fa da bordo appena
/// accennato, così si staccano anche quando sotto passa una scheda. Niente linee vere.
const islandShadow = [
  BoxShadow(color: Color(0x17000000), blurRadius: 18, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x14000000), blurRadius: 1.5, spreadRadius: 0.5),
];

/// Le misure del Dock: ogni isola è alta [dockIsland] e dentro ogni cosa tonda è [dockRound],
/// col suo margine uguale tutto intorno. Così la matita, Transcri e il potere sembrano grandi uguali.
const dockIsland = 64.0, dockRound = 52.0;
