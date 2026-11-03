import 'package:flutter/material.dart';

import '../ds.dart';

/// Una pagina ancora vuota (Trascrivi, Pensieri, Argomenti): due schede fantasma, solo la sagoma,
/// e una frase che dice cosa arriverà qui. Un pezzo solo per tutte e tre (B6 «StatoVuoto»).
class StatoVuoto extends StatelessWidget {
  const StatoVuoto({super.key, required this.frase, required this.bottom, this.titolo});

  final String frase;

  /// Lo spazio del Dock, in fondo.
  final double bottom;

  /// Sopra le schede (in Trascrivi: «Oggi»).
  final String? titolo;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: EdgeInsets.fromLTRB(Spazio.s5, 0, Spazio.s5, bottom + Spazio.s10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titolo != null) ...[
            Text(titolo!, style: Testo.titoloSezione.copyWith(color: c.testoSecondario)),
            const SizedBox(height: Spazio.s3),
          ],
          const Row(
            spacing: Spazio.s3,
            children: [
              Expanded(child: _Fantasma(opacita: 1, righe: [0.8, 0.65, 0.45])),
              Expanded(child: _Fantasma(opacita: 0.5, righe: [0.7, 0.4])),
            ],
          ),
          const SizedBox(height: Spazio.s6),
          Text(frase, style: Testo.testoGrande.copyWith(color: c.testoSecondario)),
        ],
      ),
    );
  }
}

/// Una scheda vuota, solo la sagoma: suggerisce cosa arriverà senza fingere un contenuto.
class _Fantasma extends StatelessWidget {
  const _Fantasma({required this.opacita, required this.righe});

  final double opacita;
  final List<double> righe;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Opacity(
      opacity: opacita,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(Spazio.s4),
        decoration: BoxDecoration(color: c.scheda, borderRadius: BorderRadius.circular(Raggio.scheda)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spazio.s2,
          children: [
            for (final w in righe)
              FractionallySizedBox(
                widthFactor: w,
                child: Container(height: Spazio.s2, decoration: BoxDecoration(color: c.linea, borderRadius: BorderRadius.circular(Raggio.piccolo))),
              ),
          ],
        ),
      ),
    );
  }
}
