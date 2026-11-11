import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// La ricerca appena aperta, prima di scrivere (7 nov): le ultime ricerche, toccata una si rifà, con la × si toglie.
/// Nessuna: una riga che dice cosa si può cercare. Niente disegni.
class RicercheFatte extends StatelessWidget {
  const RicercheFatte({super.key, required this.ricerche, required this.onScegli, required this.onTogli});

  final List<String> ricerche;
  final ValueChanged<String> onScegli, onTogli;

  /// Quello che si legge quando non hai ancora cercato niente.
  static const invito = 'Cerca una parola o un\'idea: trovo anche per significato';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    if (ricerche.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s5, Spazio.s10, Spazio.s5, 0),
        child: Text(invito, style: Testo.testoGrande.copyWith(color: c.testoSecondario)),
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s2, Spazio.s2),
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(Spazio.s1, 0, 0, Spazio.s1), child: EtichettaGruppo('Recenti')),
        for (final r in ricerche)
          InkWell(
            onTap: () => onScegli(r),
            borderRadius: BorderRadius.circular(Raggio.campo),
            child: Row(
              spacing: Spazio.s3,
              children: [
                const SizedBox(width: Spazio.s1),
                Icon(Icons.history_rounded, size: Misura.iconaMedia, color: c.testoSecondario),
                Expanded(child: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.testo.copyWith(color: c.testo))),
                BottoneIcona(Icons.close_rounded, etichetta: 'Togli «$r»', onTap: () => onTogli(r), misura: Misura.bottoneBasso),
              ],
            ),
          ),
      ],
    );
  }
}
