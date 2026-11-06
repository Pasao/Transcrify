import 'package:flutter/material.dart';

import '../ds.dart';

/// Nell'angolo di una scheda mentre se ne scelgono: un tondo vuoto (si può scegliere) o pieno con la spunta
/// (scelta). Il tondo è nel colore del testo: si vede su ogni tinta.
class SpuntaScelta extends StatelessWidget {
  const SpuntaScelta({super.key, required this.scelta});

  final bool scelta;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Semantics(
      selected: scelta,
      child: AnimatedContainer(
        duration: Durata.scelta,
        curve: Curva.standard,
        width: Misura.iconaGrande,
        height: Misura.iconaGrande,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scelta ? c.testo : c.scheda,
          border: Border.all(color: c.testo, width: Misura.bordoScelta),
        ),
        // La spunta arriva crescendo, insieme al tondo che si riempie.
        child: AnimatedScale(
          duration: Durata.scelta,
          curve: Curva.standard,
          scale: scelta ? 1 : 0,
          child: Icon(Icons.check_rounded, size: Misura.iconaPiccola, color: c.pagina),
        ),
      ),
    );
  }
}
