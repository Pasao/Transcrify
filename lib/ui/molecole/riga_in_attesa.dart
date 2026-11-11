import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Le due parti di quello che c'è da sistemare (10 nov): le registrazioni in attesa di rete e le proposte di colore.
/// Toccando il loro segno si apre la pagina «Da sistemare» sulla sua parte.
enum DaSistemare { attesa, proposte }

/// Il segno di una parte: l'orologio giallo per le registrazioni in attesa; per le proposte di colore la scintilla di
/// «Colora da sola» (la stessa delle Impostazioni e di [SegnoAuto]).
Widget _segno(BuildContext context, DaSistemare parte) => switch (parte) {
  DaSistemare.attesa => Icon(Icons.schedule_rounded, size: Misura.iconaPiccola, color: context.col.attenzione),
  DaSistemare.proposte => Icon(Icons.auto_awesome_rounded, size: Misura.iconaPiccola, color: context.col.testoSecondario),
};

/// Le parti che hanno qualcosa, nell'ordine della pagina.
List<(DaSistemare, int)> _parti(int quante, int proposte) => [
  if (quante > 0) (DaSistemare.attesa, quante),
  if (proposte > 0) (DaSistemare.proposte, proposte),
];

/// Sotto il titolo, quando c'è qualcosa da sistemare: le registrazioni che aspettano la rete (con «Riprova» accanto;
/// mentre riprova, al posto del bottone gira un cerchio) e, dal 10 nov, le proposte di colore di «Colora da sola»
/// ([proposte]). Ognuna col suo segno e la sua frase, una accanto all'altra; toccata apre la pagina sulla sua parte
/// ([onApri]).
class RigaInAttesa extends StatelessWidget {
  const RigaInAttesa({
    super.key,
    required this.quante,
    required this.riprovando,
    required this.onRiprova,
    required this.onApri,
    this.proposte = 0,
  });

  final int quante, proposte;
  final bool riprovando;
  final VoidCallback onRiprova;
  final ValueChanged<DaSistemare> onApri;

  static String _frase(DaSistemare parte, int n) => switch (parte) {
    DaSistemare.attesa => n == 1 ? '1 registrazione in attesa di rete' : '$n registrazioni in attesa di rete',
    DaSistemare.proposte => n == 1 ? '1 proposta di colore' : '$n proposte di colore',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Row(
      spacing: Spazio.s3,
      children: [
        for (final (parte, n) in _parti(quante, proposte))
          Flexible(
            child: InkWell(
              borderRadius: BorderRadius.circular(Raggio.piccolo),
              onTap: () => onApri(parte),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Misura.bottoneBasso),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Spazio.s1,
                  children: [
                    _segno(context, parte),
                    Flexible(
                      child: Text(_frase(parte, n), maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.etichetta.copyWith(color: c.testoSecondario)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Spacer(),
        if (quante > 0)
          SizedBox(
            height: Misura.bottoneBasso,
            child: Center(
              child: riprovando
                  ? SizedBox.square(
                      dimension: Misura.iconaMedia,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.azione),
                    )
                  : Bottone('Riprova', tipo: TipoBottone.testo, alto: false, onPressed: onRiprova),
            ),
          ),
      ],
    );
  }
}

/// Con l'intestazione ridotta, accanto al titolo: «⏱ 2» e la scintilla delle proposte col loro numero, ognuno solo se
/// c'è. Toccato, apre la pagina sulla sua parte ([onApri]).
class InAttesaCorto extends StatelessWidget {
  const InAttesaCorto({super.key, required this.quante, this.proposte = 0, this.onApri});

  final int quante, proposte;
  final ValueChanged<DaSistemare>? onApri;

  @override
  Widget build(BuildContext context) {
    final (attenzione, tenue) = (context.col.attenzione, context.col.testoSecondario);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Spazio.s2,
      children: [
        for (final (parte, n) in _parti(quante, proposte))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onApri == null ? null : () => onApri!(parte),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Spazio.s1,
              children: [
                _segno(context, parte),
                Text('$n', style: Testo.orario.copyWith(color: parte == DaSistemare.attesa ? attenzione : tenue)),
              ],
            ),
          ),
      ],
    );
  }
}
