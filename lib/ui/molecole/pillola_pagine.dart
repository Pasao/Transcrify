import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';
import 'isola.dart';

/// Le pagine di un potere (in Pensieri: Note e Argomenti): una pillola che esce da dietro il medaglione.
/// Comincia sotto il suo centro, con l'angolo piccolo nascosto dietro di lui, e lascia uno stacco netto
/// prima della prima pagina. Quella in cui sei è Accesa, le altre nude; cambiando pagina il fondo acceso
/// scivola da una all'altra (6 nov: «salta»), e l'icona cambia colore insieme a lui.
class PillolaPagine extends StatelessWidget {
  const PillolaPagine({super.key, required this.pagine, required this.pagina, required this.onPagina});

  /// Lo spazio libero tra il bordo del medaglione e la prima pagina.
  static const stacco = 14.0;

  /// Lo spazio tra una pagina e l'altra.
  static const _tra = Spazio.s1;

  final List<(IconData, String)> pagine;
  final int pagina;
  final ValueChanged<int> onPagina;

  @override
  Widget build(BuildContext context) {
    final (fondo, _) = BottoneIcona.colori(context.col, TipoIcona.acceso);
    return Isola(
      raggio: const BorderRadius.horizontal(left: Radius.circular(Raggio.campo), right: Radius.circular(Raggio.pillola)),
      padding: const EdgeInsets.fromLTRB(Misura.isola / 2 + stacco, Isola.margine, Isola.margine, Isola.margine),
      child: Stack(
        children: [
          // Il fondo della pagina in cui sei: uno solo, che si sposta.
          AnimatedPositioned(
            key: const ValueKey('pagina scelta'),
            duration: Durata.normale,
            curve: Curva.scambio,
            left: pagina.clamp(0, pagine.length) * (Misura.tondo + _tra),
            top: 0,
            width: Misura.tondo,
            height: Misura.tondo,
            child: DecoratedBox(decoration: BoxDecoration(color: fondo, shape: BoxShape.circle)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _tra,
            children: [
              for (var i = 0; i < pagine.length; i++)
                BottoneIcona(
                  pagine[i].$1,
                  etichetta: pagine[i].$2,
                  misura: Misura.tondo,
                  tipo: i == pagina ? TipoIcona.acceso : TipoIcona.trasparente,
                  conFondo: false,
                  onTap: () => onPagina(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
