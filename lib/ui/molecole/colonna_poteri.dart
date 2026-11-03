import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';
import '../potere.dart';

/// La colonna dei poteri: sale dal medaglione quando lo tocchi. In basso il potere in cui sei
/// (col colore del medaglione), sopra gli altri col nome: tocchi e ci vai.
class ColonnaPoteri extends StatelessWidget {
  const ColonnaPoteri({super.key, required this.attuale, required this.onScegli});

  final Power attuale;
  final ValueChanged<Power> onScegli;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    // Dall'alto in basso: gli altri, poi quello in cui sei (vicino al dito).
    final ordine = [...Power.values.where((p) => p != attuale), attuale];
    return Container(
      padding: const EdgeInsets.all(Spazio.s2),
      decoration: BoxDecoration(color: c.isola, borderRadius: BorderRadius.circular(Raggio.gruppo), boxShadow: Ombra.sospeso),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spazio.s1,
        children: [for (final p in ordine) _Riga(potere: p, qui: p == attuale, onTap: () => onScegli(p))],
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.potere, required this.qui, required this.onTap});

  final Power potere;
  final bool qui;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return InkWell(
      borderRadius: BorderRadius.circular(Raggio.pillola),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s1, Spazio.s1, Spazio.s5, Spazio.s1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Spazio.s3,
          children: [
            Container(
              width: Misura.tondo,
              height: Misura.tondo,
              decoration: BoxDecoration(shape: BoxShape.circle, color: qui ? c.azione : Colors.transparent),
              child: Icon(potere.icon, size: Misura.iconaGrande, color: qui ? c.suAzione : c.testoSecondario),
            ),
            Text(potere.label, style: (qui ? Testo.titoloScheda : Testo.testo).copyWith(color: qui ? c.testoSecondario : c.testo)),
          ],
        ),
      ),
    );
  }
}
