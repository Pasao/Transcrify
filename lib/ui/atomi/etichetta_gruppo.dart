import 'package:flutter/material.dart';

import '../ds.dart';

/// Il titoletto MAIUSCOLO sopra un gruppo.
class EtichettaGruppo extends StatelessWidget {
  const EtichettaGruppo(this.testo, {super.key, this.colore});

  final String testo;

  /// Di base il testo secondario; la zona pericolosa usa l'errore.
  final Color? colore;

  @override
  Widget build(BuildContext context) => Text(
    testo.toUpperCase(),
    style: Testo.gruppo.copyWith(color: colore ?? context.col.testoSecondario),
  );
}
