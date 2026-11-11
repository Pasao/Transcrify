import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Il fondo di ogni pagina dell'introduzione, sempre uguale (7 nov, sua richiesta: stessi posti, stesso ordine):
/// a sinistra il secondario («Salta»), in mezzo a che pagina sei, a destra il principale. Così il pollice trova
/// sempre la stessa cosa nello stesso punto, pagina dopo pagina.
/// - [conta]: «1 di 3» (null fuori dall'introduzione, es. la chiave dalle impostazioni).
/// - [principale] / [onPrincipale]: l'azione della pagina (null = spenta, es. mentre controlla).
/// - [secondario] / [onSecondario]: di solito «Salta»; senza, a sinistra resta il posto vuoto.
class PiedeIntro extends StatelessWidget {
  const PiedeIntro({
    super.key,
    this.conta,
    required this.principale,
    required this.onPrincipale,
    this.secondario,
    this.onSecondario,
  });

  final String? conta;
  final String principale;
  final VoidCallback? onPrincipale;
  final String? secondario;
  final VoidCallback? onSecondario;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s4, Spazio.s4),
        child: Row(
          spacing: Spazio.s2,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                // Stretto o col testo grande, i bottoni si stringono un poco invece di andare a capo: i posti restano quelli.
                child: secondario == null
                    ? null
                    : FittedBox(fit: BoxFit.scaleDown, child: Bottone(secondario!, tipo: TipoBottone.testo, onPressed: onSecondario)),
              ),
            ),
            if (conta != null) Text(conta!, style: Testo.piccolo.copyWith(color: c.testoSecondario)),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                heightFactor: 1,
                child: FittedBox(fit: BoxFit.scaleDown, child: Bottone(principale, onPressed: onPrincipale)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
