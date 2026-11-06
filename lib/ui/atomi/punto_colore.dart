import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/segni.dart';
import '../ds.dart';

/// Un colore da toccare: un puntino tondo; quello scelto ha un anello attorno e la spunta dentro (5 nov: si deve
/// capire senza dubbi qual è). Il tocco è largo quanto un bottone basso anche se il puntino è piccolo.
class PuntoColore extends StatelessWidget {
  const PuntoColore(this.colore, {super.key, this.scelto = false, this.misura = Misura.iconaGrande, this.onTap, this.etichetta, this.icona});

  final Color colore;
  final bool scelto;

  /// Quanto è grande il puntino (l'anello sta fuori).
  final double misura;
  final VoidCallback? onTap;

  /// Il nome, per il suggerimento e per chi usa il lettore dello schermo.
  final String? etichetta;

  /// Un segno dentro il puntino al posto della spunta (la ✕ di «senza colore» al centro della rosa): scelto, ha l'anello.
  final IconData? icona;

  static const _anello = 2.0;

  /// Il puntino di un colore della tavolozza; nessun colore è un puntino neutro.
  static Color di(BuildContext context, Colore? c) => c == null ? context.col.linea : Tinte.di(c.tinta, c.luce);

  void _tocca() {
    HapticFeedback.selectionClick();
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final punto = AnimatedContainer(
      duration: Durata.veloce,
      padding: const EdgeInsets.all(_anello),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scelto ? context.col.testo : Colors.transparent, width: _anello),
      ),
      child: Container(
        width: misura,
        height: misura,
        decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
        // La spunta chiara sui colori scuri, scura sui chiari: si vede su tutti.
        child: scelto || icona != null
            ? Icon(
                icona ?? Icons.check_rounded,
                size: Misura.iconaPiccola,
                color: ThemeData.estimateBrightnessForColor(colore) == Brightness.dark ? Colori.chiaro.pagina : Colori.chiaro.testo,
              )
            : null,
      ),
    );
    final tocco = Semantics(
      button: onTap != null,
      selected: scelto,
      label: etichetta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : _tocca,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: Misura.bottoneBasso, minHeight: Misura.bottoneBasso),
          child: Center(child: punto),
        ),
      ),
    );
    return etichetta == null ? tocco : Tooltip(message: etichetta!, child: tocco);
  }
}
