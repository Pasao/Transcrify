import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Dentro una scheda, trascrizione o nota (11 nov, suo: «le note come le trascrizioni»): in alto il contenuto, la
/// parte che si offusca ([Offuscabile], larga quanto la scheda); in fondo la fascia, sempre in vista: il [titolo] e,
/// sotto, le informazioni ([info]: l'ora, da dove arriva…). [riempie]: la scheda ha un'altezza sua (le trascrizioni,
/// tutte uguali) e il contenuto prende quello che resta; se no è alto quanto il testo (le note).
class CorpoScheda extends StatelessWidget {
  const CorpoScheda({
    super.key,
    required this.testo,
    required this.coperta,
    required this.copertura,
    required this.titolo,
    required this.info,
    this.riempie = false,
  });

  /// Il respiro del testo dai bordi, e quello della fascia: il cestino non sta attaccato all'angolo, col suo margine
  /// dentro dal bordo destro e da quello in basso c'è lo stesso respiro del testo a sinistra.
  static const margineTesto = EdgeInsets.fromLTRB(Spazio.s4, Spazio.s3, Spazio.s4, 0);
  static const margineFascia = EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s2, Spazio.s1);

  final Widget testo, titolo, info;
  final bool coperta, riempie;
  final CoperturaPrivata copertura;

  @override
  Widget build(BuildContext context) {
    final alto = Offuscabile(
      coperta: coperta,
      riempie: riempie,
      copertura: copertura,
      testo: Padding(padding: margineTesto, child: testo),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: riempie ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (riempie) Expanded(child: alto) else alto,
        Padding(
          padding: margineFascia,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [titolo, info]),
        ),
      ],
    );
  }
}
