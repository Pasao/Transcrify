import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';
import '../potere.dart';

/// Il potere in cui sei, in basso a sinistra sotto il pollice: un tondo grande come le isole, col
/// colore pieno dell'azione. Due gesti (sua scelta):
/// - lo TRASCINI su: ti segue un pezzetto e, superata la soglia, passa al prossimo potere;
///   mentre lo tiri [onTira] dice quanto (0 → 1 = abbastanza), per mostrare il nome di chi arriva;
/// - lo TOCCHI: si apre la colonna con tutti i poteri ([onTocco]).
class Medaglione extends StatefulWidget {
  const Medaglione({super.key, required this.potere, required this.onTocco, required this.onProssimo, required this.onTira});

  final Power potere;
  final VoidCallback onTocco;
  final VoidCallback onProssimo;
  final ValueChanged<double> onTira;

  /// Quanto bisogna tirarlo su per passare al prossimo (o una spinta veloce).
  static const soglia = 28.0;
  static const spinta = 500.0;

  @override
  State<Medaglione> createState() => _MedaglioneState();
}

class _MedaglioneState extends State<Medaglione> with SingleTickerProviderStateMixin {
  /// Il battito quando arriva un altro potere.
  late final _battito = AnimationController(vsync: this, duration: Durata.battito);

  @override
  void didUpdateWidget(covariant Medaglione prima) {
    super.didUpdateWidget(prima);
    if (prima.potere != widget.potere) _battito.forward(from: 0);
  }

  @override
  void dispose() {
    _battito.dispose();
    super.dispose();
  }

  /// Quanto l'hai tirato su, in punti (positivo = su).
  double _tirato = 0;

  void _muovi(DragUpdateDetails d) {
    final prima = _tirato >= Medaglione.soglia;
    setState(() => _tirato = (_tirato - d.delta.dy).clamp(0, Medaglione.soglia * 1.4));
    if (!prima && _tirato >= Medaglione.soglia) HapticFeedback.selectionClick();
    widget.onTira(_tirato / Medaglione.soglia);
  }

  void _lascia(DragEndDetails d) {
    if (_tirato >= Medaglione.soglia || -(d.primaryVelocity ?? 0) > Medaglione.spinta) {
      HapticFeedback.lightImpact();
      widget.onProssimo();
    }
    setState(() => _tirato = 0);
    widget.onTira(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Semantics(
      button: true,
      label: '${widget.potere.label}: trascina su per il prossimo potere, tocca per vederli tutti',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTocco();
        },
        onVerticalDragUpdate: _muovi,
        onVerticalDragEnd: _lascia,
        child: AnimatedSlide(
          // Ti segue per un pezzetto, poi torna al suo posto con un piccolo rimbalzo.
          offset: Offset(0, -_tirato / Misura.isola * 0.35),
          duration: _tirato == 0 ? Durata.normale : Duration.zero,
          curve: Curva.rimbalzo,
          // Cambiando potere batte una volta, e dentro il segno di prima esce in alto mentre quello nuovo sale dal
          // basso: lo stesso verso del gesto (tirarlo su porta al prossimo).
          child: ScaleTransition(
            scale: _battito.drive(TweenSequence([
              TweenSequenceItem(tween: Tween(begin: 1.0, end: Scala.battito).chain(CurveTween(curve: Curva.standard)), weight: 1),
              TweenSequenceItem(tween: Tween(begin: Scala.battito, end: 1.0).chain(CurveTween(curve: Curva.scambio)), weight: 1),
            ])),
            child: Container(
              width: Misura.isola,
              height: Misura.isola,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: c.azione, shape: BoxShape.circle, boxShadow: Ombra.appoggiato),
              child: AnimatedSwitcher(
                duration: Durata.normale,
                switchInCurve: Curva.standard,
                switchOutCurve: Curva.uscita,
                transitionBuilder: (w, a) => SlideTransition(
                  position: Tween(begin: Offset(0, w.key == ValueKey(widget.potere) ? 1 : -1), end: Offset.zero).animate(a),
                  child: FadeTransition(opacity: a, child: w),
                ),
                child: Icon(widget.potere.icon, key: ValueKey(widget.potere), size: Misura.iconaGrande, color: c.suAzione),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
