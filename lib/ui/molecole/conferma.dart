import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// La coppia di ogni conferma (7 nov, sua richiesta: «tutti i bottoni di conferma uguali»): a destra il principale,
/// pieno ([Bottone], alto); a sinistra di lui il secondario, solo testo. La usano la rosa («Fatto»), il titolo
/// («Fatto»), «Rinomina», i dialoghi («Rimuovi», «Apri») e il testo del modo («Salva»). Il fondo dell'introduzione
/// ([PiedeIntro]) usa lo stesso principale.
/// - [colore]: solo per un'azione che toglie qualcosa (rosso: «Rimuovi»).
class Conferma extends StatelessWidget {
  const Conferma({
    super.key,
    required this.principale,
    required this.onPrincipale,
    required this.onAnnulla,
    this.annulla = 'Annulla',
    this.colore,
  });

  final String principale, annulla;

  /// Null: spento (es. «Rinomina» finché il nome non cambia).
  final VoidCallback? onPrincipale;
  final VoidCallback onAnnulla;
  final Color? colore;

  @override
  // Sempre su una riga, nello stesso ordine: stretti o col testo grande si stringono un poco, non vanno a capo.
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    spacing: Spazio.s2,
    children: [
      Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, child: Bottone(annulla, tipo: TipoBottone.testo, onPressed: onAnnulla)),
      ),
      Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, child: Bottone(principale, onPressed: onPrincipale, colore: colore)),
      ),
    ],
  );
}
