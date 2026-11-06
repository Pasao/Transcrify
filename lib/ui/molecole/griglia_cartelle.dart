import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../ds.dart';
import 'cartella.dart';

/// Una cartella da mostrare: il colore, il nome (tuo o della tinta) e le sue trascrizioni, dalla più nuova.
typedef DatiCartella = ({Colore colore, String nome, List<Entry> voci});

/// Le cartelle disegnate, due per riga (6 nov, sua scelta: «solo cartelle che si aprono»), più alte che larghe.
/// Toccarne una la apre ([onApri]); tenerla premuta la sceglie ([onScegli]). Mentre se ne scelgono ([scelte] non vuoto)
/// il tocco sceglie o toglie.
///
/// Quella [aperta] (6 nov, giro 6) si apre lì dov'era: al posto della sua riga la fascia ([fascia], larga quanto la
/// pagina, che parte dal suo riquadro: sinistra e larghezza in frazioni), le altre di quella riga e le seguenti sotto.
class GrigliaCartelle extends StatelessWidget {
  const GrigliaCartelle({
    super.key,
    required this.cartelle,
    required this.scelte,
    required this.onApri,
    required this.onScegli,
    this.aperta,
    this.fascia,
  });

  final List<DatiCartella> cartelle;

  /// Le cartelle scelte; vuoto: non se ne stanno scegliendo.
  final Set<Colore> scelte;

  final ValueChanged<DatiCartella> onApri;
  final ValueChanged<Colore> onScegli;

  /// La cartella aperta (null: nessuna) e la sua fascia, da dove parte.
  final Colore? aperta;
  final Widget Function(DatiCartella cartella, (double, double) da)? fascia;

  static const _perRiga = 2;
  static const _tra = Spazio.s3, _lato = Spazio.s5, _traRighe = Spazio.s5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final larga = (box.maxWidth - 2 * _lato - _tra * (_perRiga - 1)) / _perRiga;
      final i = cartelle.indexWhere((k) => k.colore == aperta);
      if (i < 0 || fascia == null) return _righe(cartelle, larga);
      final riga = i - i % _perRiga;
      final prima = cartelle.sublist(0, riga);
      final dopo = [...cartelle.sublist(riga)]..removeAt(i - riga);
      final da = ((_lato + (i % _perRiga) * (larga + _tra)) / box.maxWidth, larga / box.maxWidth);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prima.isNotEmpty) ...[_righe(prima, larga), const SizedBox(height: _traRighe)],
          fascia!(cartelle[i], da),
          if (dopo.isNotEmpty) ...[const SizedBox(height: _traRighe), _righe(dopo, larga)],
        ],
      );
    },
  );

  Widget _righe(List<DatiCartella> quali, double larga) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _lato),
    child: Wrap(
      spacing: _tra,
      runSpacing: _traRighe,
      children: [
        for (final k in quali)
          SizedBox(
            width: larga,
            child: Cartella(
              key: ValueKey(k.colore),
              colore: k.colore,
              nome: k.nome,
              voci: k.voci,
              scelta: scelte.isEmpty ? null : scelte.contains(k.colore),
              onTocco: () => onApri(k),
              onScegli: () => onScegli(k.colore),
            ),
          ),
      ],
    ),
  );
}
