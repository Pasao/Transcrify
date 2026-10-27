import 'package:flutter/material.dart';

/// L'icona di un modo: righe di testo che si semplificano.
/// Fedele: quattro righe piene, con le virgole. Pulita: tre righe lisce. Riassunto: un punto e due tratti.
class ModeIcon extends CustomPainter {
  ModeIcon(this.mode, this.color);

  final String mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Disegnata su una griglia di 28: si scala alla misura data.
    canvas.scale(size.width / 28);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    void row(double y, double from, double to) => canvas.drawLine(Offset(from, y), Offset(to, y), line);
    switch (mode) {
      case 'fedele':
        row(3, 1, 12);
        row(3, 16, 27);
        row(9, 1, 21);
        canvas.drawCircle(const Offset(25, 9), 1.4, dot);
        row(15, 1, 8);
        row(15, 12, 27);
        row(21, 1, 17);
        canvas.drawCircle(const Offset(21, 21), 1.4, dot);
      case 'pulita':
        row(5, 1, 27);
        row(11, 1, 27);
        row(17, 1, 18);
      default:
        canvas.drawCircle(const Offset(3, 7), 2.4, dot);
        row(7, 9, 24);
        canvas.drawCircle(const Offset(3, 15), 2.4, dot);
        row(15, 9, 19);
    }
  }

  @override
  bool shouldRepaint(ModeIcon old) => old.mode != mode || old.color != color;
}
