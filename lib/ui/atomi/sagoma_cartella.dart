import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ds.dart';

/// La forma di una cartella (Figma D2, riga 3): rettangolare, col dorso e la sua linguetta in alto a sinistra,
/// e davanti la tasca che lo copre quasi tutto. Tra i due, in alto, sporge quello che c'è dentro ([dentro]).
/// [apertura] (0 → 1) la apre: la tasca davanti si piega in avanti e quello che c'è dentro sale un poco.
/// Solo la forma: i colori e il contenuto li dà chi la usa (la cartella vera, o la sagoma vuota dello stato vuoto).
class SagomaCartella extends StatelessWidget {
  const SagomaCartella({super.key, required this.dorso, required this.davanti, this.dentro, this.apertura = kAlwaysDismissedAnimation, this.child});

  final Color dorso, davanti;

  /// Quello che sporge dall'alto tra il dorso e la tasca (i fogli). Prende tutta la larghezza.
  final Widget? dentro;

  final Animation<double> apertura;

  /// Sulla tasca davanti, in basso a sinistra.
  final Widget? child;

  /// Quanto è alta la linguetta, e quanto è larga rispetto alla cartella.
  static const linguetta = Spazio.s3;
  static const _largaLinguetta = 0.4;

  /// Quanto del dorso si vede sopra la tasca: lì sporgono i fogli.
  static const bocca = Spazio.s8;

  /// Quanto è alta almeno la tasca, rispetto alla larghezza: ~154 × 180 in tutto a 360 dp, due per riga (5 nov sera, sua
  /// richiesta: «un pochino più alte», in piedi come una cartella vera).
  static const _altaTasca = 0.88;


  /// Aprendola: di quanto si piega la tasca (radianti) e di quanto salgono i fogli.
  static const _piega = 0.38, _salgono = Spazio.s2;

  /// La prospettiva della tasca che si piega: quanto si avvicina la parte che viene verso di te.
  static const _prospettiva = 0.002;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => AnimatedBuilder(
      animation: apertura,
      builder: (context, _) {
        final t = apertura.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: CustomPaint(painter: _Dorso(dorso))),
            if (dentro case final dentro?) Positioned(left: 0, right: 0, top: linguetta + Spazio.s1 - _salgono * t, height: bocca + Spazio.s4, child: dentro),
            Padding(
              padding: const EdgeInsets.only(top: linguetta + bocca),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, _prospettiva)
                  ..rotateX(_piega * t),
                child: Container(
                  constraints: BoxConstraints(minHeight: box.maxWidth * _altaTasca),
                  width: double.infinity,
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(Spazio.s3),
                  decoration: BoxDecoration(color: davanti, borderRadius: BorderRadius.circular(Raggio.campo)),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Il dorso: la linguetta in alto a sinistra, che scende morbida nel corpo; gli angoli col raggio delle cose piccole.
class _Dorso extends CustomPainter {
  _Dorso(this.colore);

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    const h = SagomaCartella.linguetta, r = Raggio.campo, rl = Raggio.campo / 2;
    final w = size.width, fine = math.max(w * SagomaCartella._largaLinguetta, rl * 2);
    final p = Path()
      ..moveTo(0, rl)
      ..arcToPoint(const Offset(rl, 0), radius: const Radius.circular(rl))
      ..lineTo(fine, 0)
      // La spalla della linguetta: scende morbida fino al corpo.
      ..cubicTo(fine + h / 2, 0, fine + h / 2, h, fine + h, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h + r), radius: const Radius.circular(r))
      ..lineTo(w, size.height - r)
      ..arcToPoint(Offset(w - r, size.height), radius: const Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: const Radius.circular(r))
      ..close();
    canvas.drawPath(p, Paint()..color = colore);
  }

  @override
  bool shouldRepaint(_Dorso old) => old.colore != colore;
}
