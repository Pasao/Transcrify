import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../ds.dart';

/// L'onda della voce mentre detti (piccola): gli ultimi livelli del microfono, il più nuovo a destra.
/// Serve a sapere se sta davvero registrando (sua richiesta, 2 nov). In pausa resta ferma.
class OndaVoce extends StatefulWidget {
  const OndaVoce({super.key, required this.larga, required this.alta});

  final double larga, alta;

  @override
  State<OndaVoce> createState() => _OndaVoceState();
}

class _OndaVoceState extends State<OndaVoce> {
  static const _tratti = 20;
  final _livelli = List<double>.filled(_tratti, 0, growable: true);

  void _nuovo() {
    final live = Core.live.value;
    if (live.paused || !live.listening) return;
    setState(() {
      _livelli
        ..removeAt(0)
        ..add(live.level.clamp(0.0, 1.0));
    });
  }

  @override
  void initState() {
    super.initState();
    Core.live.addListener(_nuovo);
  }

  @override
  void dispose() {
    Core.live.removeListener(_nuovo);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(widget.larga, widget.alta), painter: _Tratti(List.of(_livelli), context.col.errore));
  }
}

class _Tratti extends CustomPainter {
  _Tratti(this.livelli, this.colore);

  final List<double> livelli;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final passo = size.width / livelli.length;
    final pen = Paint()
      ..color = colore
      ..strokeWidth = passo * 0.55
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < livelli.length; i++) {
      final h = (size.height * livelli[i]).clamp(pen.strokeWidth, size.height);
      final x = passo * (i + 0.5);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), pen);
    }
  }

  @override
  bool shouldRepaint(_Tratti old) => true;
}
