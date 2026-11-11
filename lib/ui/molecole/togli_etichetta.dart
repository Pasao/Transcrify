import 'package:flutter/material.dart';

import '../ds.dart';
import 'conferma.dart';
import 'dialogo.dart';

/// «Togli l'etichetta» (10 nov, sua richiesta): se ne vanno il nome, la regola e «Offusca sempre». Il colore resta
/// sulle sue [quante] trascrizioni, a meno di scegliere «Togli il colore dalle trascrizioni». Torna null se l'hai
/// lasciata, se no true quando va tolto anche il colore.
Future<bool?> apriTogliEtichetta(BuildContext context, {required String nome, required int quante}) =>
    showDialog<bool>(context: context, builder: (_) => _TogliEtichetta(nome: nome, quante: quante));

class _TogliEtichetta extends StatefulWidget {
  const _TogliEtichetta({required this.nome, required this.quante});

  final String nome;
  final int quante;

  @override
  State<_TogliEtichetta> createState() => _TogliEtichettaState();
}

class _TogliEtichettaState extends State<_TogliEtichetta> {
  bool _colore = false;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Dialogo(
      titolo: 'Togli «${widget.nome}»',
      conferma: Conferma(principale: 'Conferma', colore: c.errore, onPrincipale: () => Navigator.pop(context, _colore), onAnnulla: () => Navigator.pop(context)),
      children: [
        Text('Se ne vanno il nome, la regola e «Offusca sempre».', style: Testo.testo.copyWith(color: c.testoSecondario)),
        if (widget.quante > 0)
          CheckboxListTile(
            value: _colore,
            onChanged: (v) => setState(() => _colore = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Togli il colore dalle trascrizioni', style: Testo.testo.copyWith(color: c.testo)),
            subtitle: Text(widget.quante == 1 ? '1 trascrizione' : '${widget.quante} trascrizioni', style: Testo.piccolo.copyWith(color: c.testoSecondario)),
          ),
      ],
    );
  }
}
