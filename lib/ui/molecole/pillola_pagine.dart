import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';
import 'isola.dart';

/// Le pagine di un potere (in Pensieri: Note e Argomenti): una pillola che esce da dietro il medaglione.
/// Comincia sotto il suo centro, con l'angolo piccolo nascosto dietro di lui, e lascia uno stacco netto
/// prima della prima pagina. Quella in cui sei è Accesa, le altre nude.
class PillolaPagine extends StatelessWidget {
  const PillolaPagine({super.key, required this.pagine, required this.pagina, required this.onPagina});

  /// Lo spazio libero tra il bordo del medaglione e la prima pagina.
  static const stacco = 14.0;

  final List<(IconData, String)> pagine;
  final int pagina;
  final ValueChanged<int> onPagina;

  @override
  Widget build(BuildContext context) {
    const margine = (Misura.isola - Misura.tondo) / 2;
    return Isola(
      raggio: const BorderRadius.horizontal(left: Radius.circular(Raggio.campo), right: Radius.circular(Raggio.pillola)),
      padding: const EdgeInsets.fromLTRB(Misura.isola / 2 + stacco, margine, margine, margine),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Spazio.s1,
        children: [
          for (var i = 0; i < pagine.length; i++)
            BottoneIcona(
              pagine[i].$1,
              etichetta: pagine[i].$2,
              misura: Misura.tondo,
              tipo: i == pagina ? TipoIcona.acceso : TipoIcona.trasparente,
              onTap: () => onPagina(i),
            ),
        ],
      ),
    );
  }
}
