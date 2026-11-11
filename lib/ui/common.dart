import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/orario.dart';
import 'theme.dart';

export '../core/orario.dart';
export 'molecole/barra_scelte.dart';
export 'molecole/pillola_annulla.dart';

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
  late final _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(); // ds:eccezione: il movimento di Transcri

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
          final target = listening ? context.col.errore : (widget.phase == 'SUCCESS' ? context.col.successo : context.col.transcriA);
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
    // Di pochi punti, gli stessi a ogni misura: su un cerchio piccolo una percentuale non si vedrebbe.
    final base = size.width / 2 + voice * 5;
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
              for (final k in [Colori.adesso.transcriA, Colori.adesso.transcriB, Colori.adesso.transcriA]) k.withValues(alpha: work.clamp(0.0, 1.0)),
            ],
            tileMode: TileMode.repeated,
          ).createShader(Rect.fromLTWH(0, h * flow - h, size.width, h)),
      );
    }
  }

  @override
  bool shouldRepaint(_VoicePainter old) => old.tint != tint || old.voice != voice || old.work != work || old.flow != flow;
}

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
/// Di un altro anno, l'anno al posto dell'ora: «28 ott 2025».
String shortStamp(DateTime d) {
  final day = dayLabel(d);
  final short = day == 'Oggi' || day == 'Ieri' ? day : '${d.day} ${_months[d.month - 1].substring(0, 3)}';
  return d.year == DateTime.now().year ? '$short, ${hm(d)}' : '$short ${d.year}';
}

/// Il simbolino di un testo arrivato da fuori: l'icona vera dell'app che l'ha mandato (WhatsApp, Telegram…).
/// Finché non arriva, o se l'app non si conosce, l'onda di un audio.
class SourceIcon extends StatelessWidget {
  const SourceIcon(this.source, {super.key, this.size = 14});

  final String? source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    if (source == null) return const SizedBox.shrink();
    return FutureBuilder<Provenienza>(
      // Se è già arrivata, c'è dal primo fotogramma: scorrendo, l'icona non lampeggia.
      initialData: Core.provenienzaPronta(source),
      future: Core.provenienza(source),
      builder: (context, snap) {
        final p = snap.data;
        final icona = p?.icona;
        return Tooltip(
          message: p?.nome == null ? 'Audio condiviso' : 'Da ${p!.nome}',
          child: icona == null
              ? Icon(Icons.graphic_eq_rounded, size: size, color: context.col.testoSecondario)
              // Decodificata già piccola, alla misura in cui si vede (l'icona dell'app è molto più grande).
              : ClipOval(
                  child: Image.memory(
                    icona,
                    width: size,
                    height: size,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
                    gaplessPlayback: true,
                  ),
                ),
        );
      },
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
    await Future.delayed(Durata.conferma);
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
        duration: Durata.veloce,
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done
            // Copiato: per un attimo una ✓ sul fondo del successo (B4 «Copia»).
            ? Container(
                key: const ValueKey(1),
                width: Misura.bottoneBasso,
                height: Misura.bottoneBasso,
                decoration: BoxDecoration(color: context.col.successoTenue, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: Misura.iconaMedia, color: context.col.successo),
              )
            : Icon(Icons.content_copy_rounded, key: const ValueKey(0), size: Misura.iconaMedia, color: context.col.testoSecondario),
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
    _disarm = Timer(Durata.armato, () {
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
            duration: Durata.normale,
            curve: Curves.easeOutBack,
            height: 40, // 40 × 40 come il tasto copia: le icone vicine hanno la stessa misura.
            constraints: const BoxConstraints(minWidth: 40),
            padding: EdgeInsets.symmetric(horizontal: armed ? 12 : 10),
            // Armato: gli stessi colori del chip di errore (B4 «Cestino»).
            decoration: BoxDecoration(color: armed ? context.col.erroreTenue : Colors.transparent, borderRadius: BorderRadius.circular(Raggio.pillola)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(armed ? Icons.delete_rounded : Icons.delete_outline_rounded, size: Misura.iconaMedia, color: armed ? context.col.errore : context.col.testoSecondario),
                AnimatedSize(
                  duration: Durata.normale,
                  child: armed
                      ? Padding(
                          padding: const EdgeInsets.only(left: Spazio.s2),
                          child: Text('Elimina', style: Testo.etichetta.copyWith(color: context.col.errore)),
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
