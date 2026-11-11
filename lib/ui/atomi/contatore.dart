import 'package:flutter/material.dart';

import '../ds.dart';

/// Il puntino col numero (10 nov): quanti filtri sono accesi sul tasto «Filtri», quante proposte di colore accanto a
/// «Trascrivi». Nel colore dell'azione, a pillola, grande quanto un'icona piccola; il numero non cresce col testo.
class Contatore extends StatelessWidget {
  const Contatore(this.quanti, {super.key});

  final int quanti;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      constraints: const BoxConstraints(minWidth: Misura.iconaPiccola, minHeight: Misura.iconaPiccola),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.azione, borderRadius: BorderRadius.circular(Raggio.pillola)),
      child: Text('$quanti', style: Testo.orario.copyWith(color: c.suAzione), textScaler: TextScaler.noScaling),
    );
  }
}
