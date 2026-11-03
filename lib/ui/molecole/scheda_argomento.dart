import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../ds.dart';

/// Un grande concetto (Lavoro, Relazioni, Salute…) col suo colore: il nome, quanti pezzi,
/// e dentro il mosaico dei sotto-argomenti — il più parlato grande, gli altri piccoli (B6 «SchedaArgomento»).
class SchedaArgomento extends StatelessWidget {
  const SchedaArgomento({super.key, required this.nome, required this.colore, required this.album, required this.onApri});

  final String nome;
  final Color colore;

  /// I sotto-argomenti, dal più grande.
  final List<Album> album;
  final ValueChanged<Album> onApri;

  static String pezzi(int n) => n == 1 ? '1 pezzo' : '$n pezzi';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final totale = album.fold<int>(0, (s, a) => s + a.pieces.length);
    final [primo, ...altri] = album;
    return Container(
      padding: const EdgeInsets.all(Spazio.s3),
      decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(Raggio.gruppo)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spazio.s2,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spazio.s1, Spazio.s1, Spazio.s1, 0),
            child: Row(
              children: [
                Expanded(child: Text(nome, style: Testo.titoloSezione.copyWith(color: c.testo), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(pezzi(totale), style: Testo.orario.copyWith(color: c.testoSecondario)),
              ],
            ),
          ),
          _Tessera(album: primo, grande: true, onTap: () => onApri(primo)),
          if (altri.isNotEmpty)
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - Spazio.s2) / 2;
                return Wrap(
                  spacing: Spazio.s2,
                  runSpacing: Spazio.s2,
                  children: [for (final a in altri) SizedBox(width: w, child: _Tessera(album: a, grande: false, onTap: () => onApri(a)))],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Un sotto-argomento nel mosaico: il nome e quanti pezzi.
class _Tessera extends StatelessWidget {
  const _Tessera({required this.album, required this.grande, required this.onTap});

  final Album album;
  final bool grande;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Material(
      color: c.isola,
      borderRadius: BorderRadius.circular(Raggio.campo),
      child: InkWell(
        borderRadius: BorderRadius.circular(Raggio.campo),
        onTap: onTap,
        // Un'altezza minima, non fissa: col testo grande la tessera cresce invece di sbordare.
        child: Container(
          constraints: BoxConstraints(minHeight: grande ? 88 : Misura.isola),
          padding: const EdgeInsets.all(Spazio.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: Spazio.s2,
            children: [
              Text(album.name, style: (grande ? Testo.titoloScheda : Testo.etichetta).copyWith(color: c.testo), maxLines: grande ? 2 : 1, overflow: TextOverflow.ellipsis),
              Text(SchedaArgomento.pezzi(album.pieces.length), style: Testo.orario.copyWith(color: c.testoSecondario)),
            ],
          ),
        ),
      ),
    );
  }
}
