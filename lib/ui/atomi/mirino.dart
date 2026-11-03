import 'package:flutter/material.dart';

import '../ds.dart';

/// La grana degli argomenti: un mirino con tre anelli e le tacche della croce fuori dagli anelli.
/// 0 spento · 1 Argomenti (anello esterno) · 2 Specifici · 3 Frasi chiave (interno) · 4 Parole chiave (tacche e centro).
/// La parte scelta è più spessa e nel colore dell'azione; il resto si fa leggero.
class Mirino extends StatelessWidget {
  const Mirino({
    super.key,
    required this.livello,
    this.misura = Misura.iconaGrande,
    this.acceso,
    this.spento,
  });

  final int livello;
  final double misura;

  /// Di base l'azione e il testo secondario; su un fondo scuro si passano i colori del Floater.
  final Color? acceso, spento;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return CustomPaint(
      size: Size.square(misura),
      painter: _MirinoPainter(
        livello,
        acceso ?? c.azione,
        spento ?? c.testoSecondario,
      ),
    );
  }
}

class _MirinoPainter extends CustomPainter {
  _MirinoPainter(this.livello, this.acceso, this.spento);

  final int livello;
  final Color acceso, spento;

  @override
  void paint(Canvas canvas, Size size) {
    // Disegnato su 24 come in Figma, poi in scala.
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    const m = Offset(12, 12);
    final leggero = livello == 0
        ? spento
        : spento.withValues(alpha: spento.a * 0.55);
    Paint penna(bool on, double spessore) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = spessore
      ..color = on ? acceso : leggero;
    const raggi = [10.0, 6.6, 3.2];
    for (var i = 0; i < 3; i++) {
      final on = livello == i + 1;
      canvas.drawCircle(m, raggi[i], penna(on, on ? 2.4 : 1.4));
    }
    final parole = livello == 4;
    final p = penna(parole, parole ? 2.2 : 1.4);
    canvas.drawLine(const Offset(12, 0.5), const Offset(12, 5.5), p);
    canvas.drawLine(const Offset(12, 18.5), const Offset(12, 23.5), p);
    canvas.drawLine(const Offset(0.5, 12), const Offset(5.5, 12), p);
    canvas.drawLine(const Offset(18.5, 12), const Offset(23.5, 12), p);
    if (parole) canvas.drawCircle(m, 1.7, Paint()..color = acceso);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MirinoPainter old) =>
      old.livello != livello || old.acceso != acceso || old.spento != spento;
}
