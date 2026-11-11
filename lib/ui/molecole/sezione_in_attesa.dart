import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../common.dart';
import '../ds.dart';

/// Le registrazioni in attesa di rete, nella pagina «Da sistemare» (10 nov; prima stavano in un foglio): una per riga
/// (giorno, ora, durata; non hanno ancora parole, non sono trascritte), ognuna col suo cestino, e in fondo «Riprova
/// tutte». Senza registrazioni in attesa non c'è.
class SezioneInAttesa extends StatelessWidget {
  const SezioneInAttesa({super.key, required this.attesa, required this.onRiprova});

  final List<Waiting> attesa;
  final VoidCallback onRiprova;

  static String _durata(int s) => s < 60 ? '$s s' : '${s ~/ 60} min${s % 60 > 0 ? ' ${s % 60} s' : ''}';

  @override
  Widget build(BuildContext context) {
    if (attesa.isEmpty) return const SizedBox.shrink();
    final c = context.col;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spazio.s3,
      children: [
        Text('In attesa di rete', style: Testo.titoloSezione.copyWith(color: c.testo)),
        Text('Sono salvate: partono quando torna la rete, o adesso con «Riprova tutte».', style: Testo.testo.copyWith(color: c.testoSecondario)),
        for (final w in attesa)
          Row(
            spacing: Spazio.s3,
            children: [
              Icon(Icons.graphic_eq_rounded, size: Misura.iconaMedia, color: c.testoSecondario),
              Expanded(
                child: Text('${dayLabel(w.at)}, ${hm(w.at)} · ${_durata(w.seconds)}', style: Testo.testo.copyWith(color: c.testo)),
              ),
              DeleteButton(
                onDelete: () async {
                  await Core.discardWaiting(w.id);
                  Core.refresh();
                },
              ),
            ],
          ),
        Bottone('Riprova tutte', onPressed: onRiprova),
      ],
    );
  }
}
