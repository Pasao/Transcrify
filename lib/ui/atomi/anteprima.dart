import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../ds.dart';
import 'formattato.dart';

/// L'inizio di un testo su una scheda: al massimo [righe] righe, poi «…», formattato ([Formattato]: i segni
/// spariscono, i collegamenti si toccano se [collegamenti]), nelle lettere per leggere ([Testo.letturaScheda]).
/// A Flutter arriva solo l'inizio del testo, quanto basta a riempire le righe: un testo lungo
/// (una dettatura di dieci minuti) non si misura tutto a ogni scheda che compare scorrendo.
class Anteprima extends StatefulWidget {
  const Anteprima(this.testo, {super.key, required this.righe, this.stile, this.collegamenti = true});

  final String testo;
  final int righe;

  /// Da qui si prende solo il colore: le lettere sono sempre quelle per leggere.
  final TextStyle? stile;

  /// Spento mentre scegli le schede: lì un tocco sceglie, non apre il collegamento.
  final bool collegamenti;

  /// Più lettere di quante ne stiano in una riga, anche su una scheda larga: il taglio non si vede mai.
  static const _perRiga = 120;

  /// L'inizio di [testo] che basta per [righe] righe (senza spezzare un'emoji a metà).
  static String inizio(String testo, int righe) {
    var fine = righe * _perRiga;
    if (testo.length <= fine) return testo;
    if (_meta(testo.codeUnitAt(fine - 1))) fine--;
    return testo.substring(0, fine);
  }

  /// La prima metà di un carattere fatto di due (le emoji): non si taglia lì.
  static bool _meta(int c) => c >= 0xD800 && c <= 0xDBFF;

  @override
  State<Anteprima> createState() => _AnteprimaState();
}

class _AnteprimaState extends State<Anteprima> {
  /// I riconoscitori dei tocchi sui collegamenti: rifatti a ogni disegno, buttati quelli vecchi.
  final _tocchi = <TapGestureRecognizer>[];

  void _butta() {
    for (final r in _tocchi) {
      r.dispose();
    }
    _tocchi.clear();
  }

  GestureRecognizer _tocco(Uri uri) {
    final r = TapGestureRecognizer()..onTap = () => Formattato.apri(uri);
    _tocchi.add(r);
    return r;
  }

  @override
  void dispose() {
    _butta();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _butta();
    final span = Formattato.span(
      context,
      Anteprima.inizio(widget.testo, widget.righe),
      stile: Testo.letturaScheda(context).copyWith(color: widget.stile?.color),
      tocco: widget.collegamenti ? _tocco : null,
    );
    return Text.rich(span, maxLines: widget.righe, overflow: TextOverflow.ellipsis);
  }
}
