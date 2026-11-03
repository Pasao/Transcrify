import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ds.dart';

/// Transcri al lavoro: una goccia coi suoi due toni, il bordo che ondeggia piano (sua richiesta, 2 nov:
/// la sua caratteristica è ondulare, non un cerchio fermo). Lo stesso disegno del Floater (BlobLavoro in PillUi.kt).
class BlobLavoro extends StatefulWidget {
  const BlobLavoro({super.key, required this.lato});

  final double lato;

  @override
  State<BlobLavoro> createState() => _BlobLavoroState();
}

class _BlobLavoroState extends State<BlobLavoro> with SingleTickerProviderStateMixin {
  late final _giro = AnimationController(vsync: this, duration: Durata.giroBlob)..repeat();

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sto trascrivendo',
      child: SizedBox.square(
        dimension: widget.lato,
        child: AnimatedBuilder(
          animation: _giro,
          builder: (context, _) => CustomPaint(painter: _Goccia(_giro.value * 2 * math.pi, context.col.gradienteTranscri)),
        ),
      ),
    );
  }
}

class _Goccia extends CustomPainter {
  _Goccia(this.giro, this.gradiente);

  final double giro;
  final LinearGradient gradiente;

  static const _punti = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r0 = size.shortestSide / 2 * 0.86;
    final path = Path();
    for (var i = 0; i <= _punti; i++) {
      final a = i * 2 * math.pi / _punti;
      final r = r0 * (1 + 0.07 * math.sin(3 * a + giro) + 0.05 * math.sin(2 * a - 1.7 * giro));
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..shader = gradiente.createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(_Goccia old) => old.giro != giro;
}
