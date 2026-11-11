import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/proposte_colore.dart';
import '../../core/titoli.dart';
import '../atomi.dart';
import '../ds.dart';

/// Toccato il titolo di una proposta: si apre la sua trascrizione, per leggerla e decidere.
typedef ApriProposta = void Function(BuildContext context, Entry voce);

/// Le proposte di colore (10 nov), nel foglio che si apre dalla riga sotto il titolo, nel loro spazio sotto le
/// registrazioni in attesa: «Proposte di colore» con «Accetta tutte» e «Scarta tutte», poi ognuna col puntino del colore proposto e il
/// titolo della trascrizione (toccato la apre: la leggi e vedi se il colore va), ✓ per metterlo e ✕ per non vederla
/// più. Senza proposte non c'è.
class SezioneProposteColore extends StatelessWidget {
  const SezioneProposteColore({super.key, required this.voci, required this.onApri});

  /// Tutte le trascrizioni: il titolo di ognuna (una proposta di una che non c'è più non si mostra).
  final List<Entry> voci;
  final ApriProposta onApri;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: ProposteColore.tutte,
    builder: (context, _, _) {
      final proposte = ProposteColore.con(voci);
      if (proposte.isEmpty) return const SizedBox.shrink();
      final c = context.col;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Proposte di colore', style: Testo.titoloSezione.copyWith(color: c.testo)),
          // «Scarta tutte» (11 nov) accanto ad «Accetta tutte», lo stesso bottone; sotto il titolo, così ci stanno
          // anche su un telefono stretto.
          Padding(
            padding: const EdgeInsets.only(top: Spazio.s2),
            child: Wrap(
              spacing: Spazio.s2,
              runSpacing: Spazio.s2,
              children: [
                Bottone('Accetta tutte', tipo: TipoBottone.tenue, alto: false, onPressed: ProposteColore.accettaTutte),
                Bottone('Scarta tutte', tipo: TipoBottone.tenue, alto: false, onPressed: ProposteColore.rifiutaTutte),
              ],
            ),
          ),
          for (final (p, e) in proposte) _Proposta(proposta: p, voce: e, onApri: () => onApri(context, e)),
        ],
      );
    },
  );
}

/// Una proposta: il colore (col suo nome per chi non vede), il titolo che apre la trascrizione, ✓ e ✕.
class _Proposta extends StatelessWidget {
  const _Proposta({required this.proposta, required this.voce, required this.onApri});

  final PropostaColore proposta;
  final Entry voce;
  final VoidCallback onApri;

  @override
  Widget build(BuildContext context) {
    final colore = proposta.colore;
    final nome = Segni.nomi.value[colore.chiave] ?? Tinte.nome(colore.tinta, colore.luce);
    final titolo = Titoli.di(voce);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            excludeSemantics: true,
            label: 'Apri «$titolo», proposta «$nome»',
            onTap: onApri,
            child: InkWell(
              onTap: onApri,
              borderRadius: BorderRadius.circular(Raggio.campo),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Misura.tocco),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: Misura.iconaPiccola, color: PuntoColore.di(context, colore)),
                    const SizedBox(width: Spazio.s3),
                    Expanded(
                      child: Text(titolo, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.testo.copyWith(color: context.col.testo)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        BottoneIcona(Icons.check_rounded, etichetta: 'Metti «$nome»', onTap: () => ProposteColore.accetta(proposta.at)),
        BottoneIcona(Icons.close_rounded, etichetta: 'Non proporla più', onTap: () => ProposteColore.rifiuta(proposta.at)),
      ],
    );
  }
}
