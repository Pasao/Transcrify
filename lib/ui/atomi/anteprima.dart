import 'package:flutter/widgets.dart';

/// L'inizio di un testo su una scheda: al massimo [righe] righe, poi «…».
/// A Flutter arriva solo l'inizio del testo, quanto basta a riempire le righe: un testo lungo
/// (una dettatura di dieci minuti) non si misura tutto a ogni scheda che compare scorrendo.
class Anteprima extends StatelessWidget {
  const Anteprima(this.testo, {super.key, required this.righe, this.stile});

  final String testo;
  final int righe;
  final TextStyle? stile;

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
  Widget build(BuildContext context) => Text(inizio(testo, righe), style: stile, maxLines: righe, overflow: TextOverflow.ellipsis);
}
