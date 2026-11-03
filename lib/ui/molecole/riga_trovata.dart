import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Una cosa trovata cercando: la frase che c'entra (le parole cercate in evidenza) e, sotto,
/// da dove viene: una nota o una trascrizione, col suo nome o il giorno. Toccandola si apre.
class RigaTrovata extends StatelessWidget {
  const RigaTrovata({super.key, required this.frase, required this.cercato, required this.nota, required this.daDove, required this.onApri});

  final String frase;
  final String cercato;

  /// Una nota (true) o una trascrizione (false): cambia solo l'icona.
  final bool nota;
  final String daDove;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Material(
      color: Scheda.fondo(c),
      shape: Scheda.forma(c),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onApri,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s3, Spazio.s4, Spazio.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Spazio.s2,
            children: [
              Text.rich(
                TextSpan(children: evidenzia(frase, cercato, Testo.testo.copyWith(color: c.testo), Testo.testo.copyWith(color: c.testo, fontWeight: FontWeight.w700))),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                spacing: Spazio.s2,
                children: [
                  Icon(nota ? Icons.sticky_note_2_outlined : Icons.graphic_eq_rounded, size: Misura.iconaPiccola, color: c.testoSecondario),
                  Expanded(child: Text(daDove, style: Testo.orario.copyWith(color: c.testoSecondario), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Il testo a pezzi: le parole cercate (senza badare alle maiuscole) con [forte], il resto con [base].
  static List<TextSpan> evidenzia(String testo, String cercato, TextStyle base, TextStyle forte) {
    final parole = cercato.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).map(RegExp.escape).toList();
    if (parole.isEmpty) return [TextSpan(text: testo, style: base)];
    final out = <TextSpan>[];
    var da = 0;
    for (final m in RegExp(parole.join('|'), caseSensitive: false).allMatches(testo)) {
      if (m.start > da) out.add(TextSpan(text: testo.substring(da, m.start), style: base));
      out.add(TextSpan(text: m.group(0), style: forte));
      da = m.end;
    }
    if (da < testo.length) out.add(TextSpan(text: testo.substring(da), style: base));
    return out;
  }
}
