import 'package:flutter/material.dart';

import '../ds.dart';

/// Come appare una cosa mentre se ne scelgono (schede, cartelle): scelta resta a colori e si stringe un poco
/// (`Scala.scelta`); le altre si spengono (`Velo.nonScelta`) e perdono il colore (`Velo.spento`), così la scelta si
/// stacca anche quando sono tutte dello stesso marrone. Velo, grigio e misura cambiano insieme e piano
/// (`Durata.scelta`, `Curva.standard`): niente scatti. Fuori dalla scelta resta com'è, senza livelli in più (il filtro
/// del colore c'è solo mentre il grigio non è zero; [child] tiene il suo stato quando il filtro arriva o se ne va).
class AspettoScelta extends StatefulWidget {
  const AspettoScelta({super.key, required this.scegliendo, required this.scelta, required this.child});

  final bool scegliendo, scelta;
  final Widget child;

  @override
  State<AspettoScelta> createState() => _AspettoSceltaState();
}

class _AspettoSceltaState extends State<AspettoScelta> {
  /// Il contenuto resta lo stesso pezzo con o senza filtro: non si ricostruisce.
  final _contenuto = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final spenta = widget.scegliendo && !widget.scelta;
    return AnimatedScale(
      duration: Durata.scelta,
      curve: Curva.standard,
      scale: widget.scelta ? Scala.scelta : 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: spenta ? 1 : 0),
        duration: Durata.scelta,
        curve: Curva.standard,
        child: KeyedSubtree(key: _contenuto, child: widget.child),
        builder: (context, grigio, child) => Opacity(
          opacity: 1 - (1 - Velo.nonScelta) * grigio,
          child: grigio == 0 ? child : ColorFiltered(colorFilter: Velo.spento(grigio), child: child),
        ),
      ),
    );
  }
}
