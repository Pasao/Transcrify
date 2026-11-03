import 'package:flutter/material.dart';

import '../ds.dart';

enum TipoChip { successo, attenzione, errore, azione, neutro }

/// Una piccola etichetta colorata: fondo tenue, testo pieno dello stesso colore. Niente contorno.
class ChipStato extends StatelessWidget {
  const ChipStato(
    this.testo, {
    super.key,
    this.tipo = TipoChip.neutro,
    this.icona,
    this.onTap,
  });

  final String testo;
  final TipoChip tipo;
  final IconData? icona;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final (fondo, su) = switch (tipo) {
      TipoChip.successo => (c.successoTenue, c.successo),
      TipoChip.attenzione => (c.attenzioneTenue, c.attenzione),
      TipoChip.errore => (c.erroreTenue, c.errore),
      TipoChip.azione => (c.azioneTenue, c.suAzioneTenue),
      TipoChip.neutro => (c.scheda, c.testoSecondario),
    };
    return Material(
      color: fondo,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            icona == null ? Spazio.s3 : Spazio.s2,
            Spazio.s1,
            Spazio.s3,
            Spazio.s1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icona != null) ...[
                Icon(icona, size: Misura.iconaPiccola, color: su),
                const SizedBox(width: Spazio.s1),
              ],
              Text(testo, style: Testo.etichetta.copyWith(color: su)),
            ],
          ),
        ),
      ),
    );
  }
}
