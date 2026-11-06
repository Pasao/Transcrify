import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atomi.dart';
import '../ds.dart';
import 'fumetto.dart';

/// Una voce del menu: l'icona, il nome, cosa fa.
typedef VoceMenu = (IconData, String, VoidCallback);

/// Il tasto ⋮ (6 nov, sua scelta: in alto a destra la lente e il ⋮). Il tocco apre le [voci] in un fumetto che
/// spunta da lui, come la scelta del colore; toccando una voce il fumetto si chiude e la voce si fa.
class TastoMenu extends StatelessWidget {
  const TastoMenu({super.key, required this.voci});

  final List<VoceMenu> voci;

  Future<void> _apri(BuildContext tasto) async {
    final scelta = await apriFumetto<VoidCallback>(
      tasto,
      sopra: dovSta(tasto),
      builder: (fumetto) => Sospeso(
        raggio: Raggio.gruppo,
        padding: const EdgeInsets.symmetric(vertical: Spazio.s2),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final v in voci) _Voce(voce: v, onTap: () => Navigator.pop(fumetto, v.$3))],
          ),
        ),
      ),
    );
    if (scelta == null) return;
    HapticFeedback.selectionClick();
    scelta();
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (tasto) => BottoneIcona(Icons.more_vert_rounded, etichetta: 'Altre opzioni', misura: Misura.tondo, onTap: () => _apri(tasto)),
  );
}

class _Voce extends StatelessWidget {
  const _Voce({required this.voce, required this.onTap});

  final VoceMenu voce;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Misura.tocco),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s6, Spazio.s2),
        child: Row(
          spacing: Spazio.s3,
          children: [
            Icon(voce.$1, size: Misura.iconaMedia, color: context.col.testoSecondario),
            Flexible(child: Text(voce.$2, style: Testo.testo.copyWith(color: context.col.testo))),
          ],
        ),
      ),
    ),
  );
}
