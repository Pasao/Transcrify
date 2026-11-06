import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Lo stato vuoto delle cartelle: la sagoma di una cartella, senza fogli né nome, nei colori delle schede
/// fantasma (StatoVuoto). Suggerisce cosa arriverà, senza fingere una cartella vera.
class CartellaVuota extends StatelessWidget {
  const CartellaVuota({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return SagomaCartella(dorso: c.linea, davanti: c.scheda);
  }
}
