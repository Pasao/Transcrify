import 'package:flutter/material.dart';

import '../ds.dart';

/// In cima alla pagina: il titolo grande, che si rimpicciolisce quando scorri ([ridotta]);
/// a destra quello che serve ([azioni]: «Dati finti», le impostazioni); sotto, se c'è, una riga
/// ([sotto]: le registrazioni in attesa). Ridotta, la riga si fa da parte e resta [accanto] al titolo.
class Intestazione extends StatelessWidget {
  const Intestazione({super.key, required this.titolo, required this.ridotta, this.azioni = const [], this.sotto, this.accanto});

  final String titolo;
  final bool ridotta;
  final List<Widget> azioni;
  final Widget? sotto, accanto;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final stile = (ridotta ? Testo.titoloSezione : Testo.titoloPagina).copyWith(color: c.testo);
    return AnimatedPadding(
      duration: Durata.normale,
      curve: Curva.standard,
      padding: EdgeInsets.fromLTRB(Spazio.s5, ridotta ? Spazio.s2 : Spazio.s4, Spazio.s2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Il titolo (e il segno accanto) prende lo spazio che resta; le azioni stanno sempre al bordo destro.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: Durata.normale,
                        layoutBuilder: (attuale, prima) => Stack(alignment: Alignment.centerLeft, children: [...prima, ?attuale]),
                        child: AnimatedDefaultTextStyle(
                          key: ValueKey(titolo),
                          duration: Durata.normale,
                          curve: Curva.standard,
                          style: stile,
                          child: Text(titolo, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    if (ridotta && accanto != null)
                      Padding(
                        padding: const EdgeInsets.only(left: Spazio.s2),
                        child: accanto,
                      ),
                  ],
                ),
              ),
              ...azioni,
            ],
          ),
          AnimatedSize(
            duration: Durata.normale,
            curve: Curva.standard,
            alignment: Alignment.topLeft,
            child: !ridotta && sotto != null
                ? Padding(
                    padding: const EdgeInsets.only(right: Spazio.s3),
                    child: sotto,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
