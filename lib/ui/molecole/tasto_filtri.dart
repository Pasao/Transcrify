import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';
import 'fumetto.dart';

/// Il tasto «Filtri» di Trascrivi (6 nov, giro 7): un tondo tra le azioni in cima, allo stesso posto nella barra e
/// nelle pillole. Col numero dei filtri accesi nel puntino in alto a destra. Toccato apre il [pannello] sotto di sé.
class TastoFiltri extends StatelessWidget {
  const TastoFiltri({super.key, required this.quanti, required this.pannello});

  final int quanti;
  final WidgetBuilder pannello;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Builder(
      builder: (tasto) => Semantics(
        button: true,
        excludeSemantics: true,
        label: quanti == 0 ? 'Filtri' : (quanti == 1 ? 'Filtri, 1 acceso' : 'Filtri, $quanti accesi'),
        onTap: () => apriFumetto<void>(tasto, sopra: dovSta(tasto), builder: pannello),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BottoneIcona(
              Icons.filter_list_rounded,
              etichetta: 'Filtri',
              misura: Misura.tondo,
              tipo: quanti == 0 ? TipoIcona.trasparente : TipoIcona.acceso,
              onTap: () => apriFumetto<void>(tasto, sopra: dovSta(tasto), builder: pannello),
            ),
            if (quanti > 0)
              Positioned(
                top: Spazio.s1,
                right: Spazio.s1,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(minWidth: Misura.iconaPiccola, minHeight: Misura.iconaPiccola),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.azione, borderRadius: BorderRadius.circular(Raggio.pillola)),
                    child: Text('$quanti', style: Testo.orario.copyWith(color: c.suAzione), textScaler: TextScaler.noScaling),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
