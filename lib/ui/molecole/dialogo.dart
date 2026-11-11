import 'package:flutter/material.dart';

import '../ds.dart';
import 'conferma.dart';

/// La cornice di ogni dialogo dell'app: il fondo dell'isola, gli angoli del foglio, il titolo, il contenuto e in fondo
/// la [Conferma]. La usano «Rinomina», «Togli l'etichetta» e «Proponi etichette» (10 nov).
class Dialogo extends StatelessWidget {
  const Dialogo({super.key, required this.titolo, required this.children, required this.conferma});

  final String titolo;
  final List<Widget> children;
  final Conferma conferma;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Dialog(
      backgroundColor: c.isola,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raggio.foglio)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s6, Spazio.s6, Spazio.s6, Spazio.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titolo, style: Testo.titoloSezione.copyWith(color: c.testo)),
            const SizedBox(height: Spazio.s4),
            ...children,
            const SizedBox(height: Spazio.s3),
            conferma,
          ],
        ),
      ),
    );
  }
}
