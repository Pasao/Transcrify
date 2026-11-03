import 'package:flutter/material.dart';

import '../ds.dart';

/// Una piccola etichetta sospesa sopra la pagina, sul fondo scuro «floater»: il nome del potere che arriva,
/// la data mentre scorri veloce.
class EtichettaSospesa extends StatelessWidget {
  const EtichettaSospesa(this.testo, {super.key});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spazio.s3,
        vertical: Spazio.s2,
      ),
      decoration: BoxDecoration(
        color: c.floater,
        borderRadius: BorderRadius.circular(Raggio.pillola),
        boxShadow: Ombra.sospeso,
      ),
      child: Text(testo, style: Testo.etichetta.copyWith(color: c.suFloater)),
    );
  }
}
