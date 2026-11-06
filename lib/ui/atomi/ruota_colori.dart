import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ds.dart';

/// L'icona del colore (6 nov: una ruota dei colori, non la tavolozza da pittore di Material; 7 nov: l'unica, anche su
/// «Colore» nella barra delle scelte): un anello in cui girano le tinte della tavolozza (`Tinte`), alla loro luce di
/// base. Solo un disegno: il nome lo dà il tasto.
class RuotaColori extends StatelessWidget {
  const RuotaColori({super.key, this.lato = Misura.iconaGrande});

  final double lato;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(lato),
      painter: _Ruota([for (final t in Tinte.giro) Tinte.di(t, Tinte.luceFila)]),
    ),
  );
}

class _Ruota extends CustomPainter {
  _Ruota(this.tinte);

  final List<Color> tinte;

  /// Quanto è spesso l'anello, rispetto all'icona.
  static const _spessore = 0.24;

  @override
  void paint(Canvas canvas, Size size) {
    final spesso = size.shortestSide * _spessore;
    final cerchio = (Offset.zero & size).deflate(spesso / 2);
    final pennello = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spesso
      // Il giro si chiude sulla prima tinta: niente salto dove l'anello ricomincia.
      ..shader = SweepGradient(colors: [...tinte, tinte.first]).createShader(cerchio);
    canvas.drawOval(cerchio, pennello);
  }

  @override
  bool shouldRepaint(_Ruota old) => !listEquals(old.tinte, tinte);
}
