import 'package:flutter/material.dart';

import '../ds.dart';

/// Il movimento di ciò che spunta (il fumetto: la scelta del colore, i colori dell'unione): cresce da [da]
/// con un piccolo rimbalzo e compare; se ne va più svelto.
class Spunta extends StatelessWidget {
  const Spunta({super.key, required this.animazione, required this.da, required this.child});

  final Animation<double> animazione;
  final Alignment da;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: animazione, curve: Curva.rimbalzo, reverseCurve: Curva.uscita);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animazione, curve: Curva.standard),
      child: ScaleTransition(scale: Tween(begin: Scala.spunta, end: 1.0).animate(curva), alignment: da, child: child),
    );
  }
}
