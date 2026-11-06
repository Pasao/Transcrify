import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';

/// I colori in gioco quando unisci schede di colori diversi (`apriColoreUnione`): sopra la domanda ([titolo]), sotto
/// i loro puntini in una fila, larga quanto una scheda (se sono tanti, scorre di lato). Null in [colori] = senza
/// colore. Scegliere un colore per le trascrizioni è la rosa (`tavolozza.dart`), non questa.
class FilaColori extends StatelessWidget {
  const FilaColori({super.key, required this.colori, required this.titolo, required this.onColore});

  /// Quanti posti si vedono senza scorrere: cinque posti da un tocco (48) fanno la larghezza di una scheda.
  static const inVista = 5;
  static const posto = Misura.schedaLarga / inVista;

  final List<Colore?> colori;
  final String titolo;
  final ValueChanged<Colore?> onColore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Misura.schedaLarga,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spazio.s3, Spazio.s1, Spazio.s3, Spazio.s1),
            child: Text(titolo, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.etichetta.copyWith(color: context.col.testo)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final colore in colori)
                  SizedBox(
                    width: posto,
                    child: PuntoColore(
                      PuntoColore.di(context, colore),
                      etichetta: colore == null ? 'Senza colore' : Tinte.nome(colore.tinta, colore.luce),
                      onTap: () => onColore(colore),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
