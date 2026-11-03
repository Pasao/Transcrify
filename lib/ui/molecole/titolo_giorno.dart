import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Il titolo di un giorno in Trascrivi: «Oggi» (titolo di sezione, 22), quante trascrizioni,
/// e a destra «Tutte» / «Chiudi» quando il giorno ne ha abbastanza da aprirlo.
class TitoloGiorno extends StatelessWidget {
  const TitoloGiorno({super.key, required this.giorno, required this.quante, this.aperto, this.onApri});

  final String giorno;
  final int quante;

  /// null: niente «Tutte» (il giorno ne ha poche).
  final bool? aperto;
  final VoidCallback? onApri;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Row(
      children: [
        Expanded(
          child: Row(
            spacing: Spazio.s2,
            children: [
              Flexible(
                child: Text(
                  giorno,
                  style: Testo.titoloSezione.copyWith(color: c.testo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$quante', style: Testo.orario.copyWith(color: c.testoSecondario)),
            ],
          ),
        ),
        if (aperto != null)
          TextButton.icon(
            style: Bottone.stile(c, TipoBottone.testo, alto: false, colore: c.testoSecondario),
            onPressed: onApri,
            iconAlignment: IconAlignment.end,
            icon: AnimatedRotation(
              turns: aperto! ? 0.5 : 0,
              duration: Durata.normale,
              child: const Icon(Icons.expand_more_rounded, size: Misura.iconaMedia),
            ),
            label: Text(aperto! ? 'Chiudi' : 'Tutte'),
          ),
      ],
    );
  }
}
