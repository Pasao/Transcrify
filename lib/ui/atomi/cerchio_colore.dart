import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';

/// Il colore di una trascrizione aperta, in alto a destra, sempre nello stesso posto (6 nov, giro 6, Figma D5 riga 1).
/// Col colore: il tondo pieno con un anello sottile attorno, staccato, che dice «si tocca, si cambia». Senza colore è
/// l'invito: lo stesso tondo tratteggiato, col «+» dentro. Il tocco è grande quanto un dito.
class CerchioColore extends StatelessWidget {
  const CerchioColore({super.key, required this.colore, required this.onTap});

  /// Il colore della trascrizione; null: non ne ha (l'invito).
  final Color? colore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final pieno = colore;
    const lato = Misura.cerchioColore + 2 * (Misura.anelloStacco + Misura.anello);
    return Semantics(
      button: true,
      label: pieno == null ? 'Dai un colore' : 'Cambia colore',
      child: Tooltip(
        message: pieno == null ? 'Dai un colore' : 'Cambia colore',
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          radius: Misura.tocco / 2,
          child: SizedBox.square(
            dimension: Misura.tocco,
            child: Center(
              child: AnimatedSwitcher(
                duration: Durata.veloce,
                child: pieno == null
                    ? CustomPaint(
                        key: const ValueKey(false),
                        size: const Size.square(lato),
                        painter: _Tratteggio(c.testoSecondario),
                        child: Icon(Icons.add_rounded, size: Misura.iconaPiccola, color: c.testoSecondario),
                      )
                    : Container(
                        key: const ValueKey(true),
                        width: lato,
                        height: lato,
                        padding: const EdgeInsets.all(Misura.anelloStacco),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.testoSecondario, width: Misura.anello),
                        ),
                        child: DecoratedBox(decoration: BoxDecoration(color: pieno, shape: BoxShape.circle)),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il tondo tratteggiato dell'invito: tanti archi corti uguali, alla misura del tondo pieno.
class _Tratteggio extends CustomPainter {
  _Tratteggio(this.colore);

  final Color colore;

  static const _tratti = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: Misura.cerchioColore / 2);
    final pennello = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = Misura.anello
      ..strokeCap = StrokeCap.round;
    const passo = 2 * math.pi / _tratti;
    for (var i = 0; i < _tratti; i++) {
      canvas.drawArc(r, i * passo, passo / 2, false, pennello);
    }
  }

  @override
  bool shouldRepaint(_Tratteggio prima) => prima.colore != colore;
}
