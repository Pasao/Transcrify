import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';

/// Un filtro da accendere e spegnere (Trascrivi: la fonte, il modo, il colore). Spento ha il fondo delle schede, acceso
/// quello tenue dell'azione, come la pagina scelta nel Dock. Niente contorno né spunta; il tocco è alto quanto un dito.
/// Con [punto] (un colore) davanti al nome c'è il suo puntino. Con [togli] (i filtri accesi sotto il titolo) dopo il
/// nome c'è la ×: toccarlo lo spegne.
class ChipFiltro extends StatelessWidget {
  const ChipFiltro(this.testo, {super.key, required this.acceso, required this.onTap, this.punto, this.togli = false});

  final String testo;
  final bool acceso, togli;
  final VoidCallback onTap;
  final Color? punto;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return ChoiceChip(
      label: togli
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Spazio.s1,
              children: [
                Flexible(child: Text(testo, overflow: TextOverflow.ellipsis)),
                Icon(Icons.close_rounded, size: Misura.iconaPiccola, color: acceso ? c.suAzioneTenue : c.testo),
              ],
            )
          : Text(testo),
      avatar: punto == null
          ? null
          : Container(
              width: Misura.iconaPiccola,
              height: Misura.iconaPiccola,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
      selected: acceso,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: c.scheda,
      selectedColor: c.azioneTenue,
      labelStyle: Testo.etichetta.copyWith(color: acceso ? c.suAzioneTenue : c.testo),
      padding: const EdgeInsets.symmetric(horizontal: Spazio.s1),
    );
  }
}
