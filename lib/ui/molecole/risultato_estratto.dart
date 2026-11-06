import 'package:flutter/material.dart';

import '../../core/estratto.dart';
import '../atomi.dart';
import '../ds.dart';
import 'testo_evidenziato.dart';

/// Il riassunto estrattivo di un testo, per la prova: quanto ci ha messo, le frasi scelte (pulite) e sotto
/// il testo originale con quelle frasi illuminate. Toccando una frase, il testo scorre fin lì.
class RisultatoEstratto extends StatefulWidget {
  const RisultatoEstratto({super.key, required this.estratto, required this.testo});

  final Estratto estratto;

  /// Il testo originale, quello su cui il motore ha lavorato.
  final String testo;

  @override
  State<RisultatoEstratto> createState() => _RisultatoEstrattoState();
}

class _RisultatoEstrattoState extends State<RisultatoEstratto> {
  final _testo = GlobalKey<TestoEvidenziatoState>();
  int? _attiva;

  void _mostra(int i) {
    setState(() => _attiva = i);
    _testo.currentState?.mostra(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final e = widget.estratto;
    final quante = e.frasi.length == 1 ? '1 frase' : '${e.frasi.length} frasi';
    final tempo = '${e.ms} ms${e.freddo ? ' (col caricamento del modello)' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spazio.s3,
      children: [
        Text('$quante · $tempo · modello ${e.modello}', style: Testo.orario.copyWith(color: c.testoSecondario)),
        if (e.frasi.isEmpty) Text('Niente da scegliere: il testo è troppo corto.', style: Testo.testo.copyWith(color: c.testo)),
        for (final (i, f) in e.frasi.indexed)
          Material(
            color: Scheda.fondo(c, scelta: i == _attiva),
            shape: Scheda.forma(c, scelta: i == _attiva),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _mostra(i),
              child: Padding(
                padding: const EdgeInsets.all(Spazio.s4),
                child: Text(f.testo, style: Testo.testo.copyWith(color: c.testo)),
              ),
            ),
          ),
        const SizedBox(height: Spazio.s3),
        const EtichettaGruppo('Il testo'),
        TestoEvidenziato(key: _testo, testo: widget.testo, pezzi: [for (final f in e.frasi) f.dove], attivo: _attiva),
      ],
    );
  }
}
