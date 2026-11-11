import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/regole_colori.dart';
import '../atomi.dart';
import '../ds.dart';
import 'conferma.dart';
import 'dialogo.dart';

/// «Proponi etichette» (10 nov, sua richiesta): l'anteprima di quelle proposte da Groq, ognuna col colore libero della
/// rosa che prenderà, il nome e la regola; tutte scelte, le togli con la spunta. Torna quelle da aggiungere (null o
/// vuota: nessuna). La stessa anteprima per «Proponi regole» ([titolo] «Regole proposte», [azione] «Applica»): le
/// etichette che hai, ognuna con la regola nuova.
Future<List<(PropostaEtichetta, Colore)>?> apriProposte(
  BuildContext context,
  List<(PropostaEtichetta, Colore)> proposte, {
  String titolo = 'Etichette proposte',
  String azione = 'Aggiungi',
}) => showDialog<List<(PropostaEtichetta, Colore)>>(context: context, builder: (_) => _Proposte(proposte, titolo, azione));

class _Proposte extends StatefulWidget {
  const _Proposte(this.proposte, this.titolo, this.azione);

  final List<(PropostaEtichetta, Colore)> proposte;
  final String titolo, azione;

  @override
  State<_Proposte> createState() => _ProposteState();
}

class _ProposteState extends State<_Proposte> {
  late final _scelte = {for (var i = 0; i < widget.proposte.length; i++) i};

  @override
  Widget build(BuildContext context) {
    final c = context.col, n = _scelte.length;
    return Dialogo(
      titolo: widget.titolo,
      conferma: Conferma(
        principale: '${widget.azione} $n',
        onPrincipale: n == 0 ? null : () => Navigator.pop(context, [for (final i in _scelte.toList()..sort()) widget.proposte[i]]),
        onAnnulla: () => Navigator.pop(context),
      ),
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final (i, (proposta, colore)) in widget.proposte.indexed)
                  CheckboxListTile(
                    value: _scelte.contains(i),
                    onChanged: (v) => setState(() => v == true ? _scelte.add(i) : _scelte.remove(i)),
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.circle, size: Misura.iconaPiccola, color: PuntoColore.di(context, colore)),
                    title: Text(proposta.nome, style: Testo.titoloScheda.copyWith(color: c.testo)),
                    subtitle: Text(proposta.regola, style: Testo.piccolo.copyWith(color: c.testoSecondario)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
