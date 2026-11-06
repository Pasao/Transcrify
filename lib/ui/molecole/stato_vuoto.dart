import 'package:flutter/material.dart';

import '../ds.dart';

/// Una pagina ancora vuota (Trascrivi, Pensieri, Argomenti): due schede fantasma, solo la sagoma,
/// e una frase che dice cosa arriverà qui. Un pezzo solo per tutte e tre (B6 «StatoVuoto»), e per le cartelle
/// (con le loro [sagome] al posto delle schede).
class StatoVuoto extends StatelessWidget {
  const StatoVuoto({super.key, required this.frase, required this.bottom, this.titolo, this.sagome});

  final String frase;

  /// Lo spazio del Dock, in fondo.
  final double bottom;

  /// Sopra le schede (in Trascrivi: «Oggi»).
  final String? titolo;

  /// Le due sagome al posto delle schede fantasma (le cartelle: la loro forma). La seconda è più tenue.
  final List<Widget>? sagome;

  static const _opacita = [1.0, 0.5];

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: EdgeInsets.fromLTRB(Spazio.s5, 0, Spazio.s5, bottom + Spazio.s10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titolo != null) ...[Text(titolo!, style: Testo.titoloSezione.copyWith(color: c.testoSecondario)), const SizedBox(height: Spazio.s3)],
          Row(
            spacing: Spazio.s3,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, sagoma)
                  in (sagome ??
                          const [
                            _Fantasma(righe: [0.8, 0.65, 0.45]),
                            _Fantasma(righe: [0.7, 0.4]),
                          ])
                      .indexed)
                Expanded(
                  child: Opacity(opacity: _opacita[i % _opacita.length], child: sagoma),
                ),
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
  const _Fantasma({required this.righe});

  final List<double> righe;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
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
              child: Container(
                height: Spazio.s2,
                decoration: BoxDecoration(color: c.linea, borderRadius: BorderRadius.circular(Raggio.piccolo)),
              ),
            ),
        ],
      ),
    );
  }
}
