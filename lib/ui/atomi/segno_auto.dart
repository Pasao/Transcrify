import 'package:flutter/material.dart';

import '../ds.dart';

/// Il colore l'ha messo l'app da sola, con una regola dell'etichetta (7 nov, sua richiesta): una scintilla piccola
/// accanto all'ora, finché non tocchi tu il colore (allora il nativo toglie `Entry.coloreAuto`).
class SegnoAuto extends StatelessWidget {
  const SegnoAuto({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Colorata da sola',
    child: Icon(Icons.auto_awesome_rounded, size: Misura.iconaPiccola, color: context.col.testoSecondario),
  );
}
