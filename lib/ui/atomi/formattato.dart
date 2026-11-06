import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formato.dart';
import '../ds.dart';

/// Come si vede un testo formattato ([Formato]): un posto solo per le schede, la trascrizione aperta e le note.
abstract final class Formattato {
  /// Lo span di [testo] con **grassetto**, *corsivo* e i collegamenti nel colore delle azioni. Una riga vuota tra due
  /// paragrafi è alta [Testo.spazioParagrafo], non una riga intera (dove l'altezza delle righe è libera: vedi [Testo.rigaVuota]).
  /// [cursore]: dove scrivi (null altrove) i segni restano nel testo, perché sono testo, ma non si vedono
  /// ([Testo.segnoNascosto]); tornano, spenti ([Velo.segni]), solo sul pezzo dove sta il cursore, per poterli toccare.
  /// Altrove spariscono del tutto. [tocco]: chi riconosce il tocco su un collegamento (null: non si tocca).
  static TextSpan span(BuildContext context, String testo, {TextStyle? stile, TextSelection? cursore, GestureRecognizer Function(Uri uri)? tocco}) {
    final col = context.col;
    final spento = TextStyle(color: (stile?.color ?? col.testo).withValues(alpha: Velo.segni));
    final segni = cursore != null;
    final figli = <InlineSpan>[];
    var at = 0;
    for (final p in Formato.leggi(testo)) {
      _semplice(figli, testo, at, p.inizio);
      final dentro = testo.substring(p.dentroInizio, p.dentroFine);
      final stilePezzo = switch (p.tipo) {
        TipoPezzo.grassetto => const TextStyle(fontWeight: FontWeight.w700),
        TipoPezzo.corsivo => const TextStyle(fontStyle: FontStyle.italic),
        TipoPezzo.collegamento => TextStyle(color: col.azione, decoration: TextDecoration.underline, decorationColor: col.azione),
      };
      final segno = segni && cursore.isValid && p.tocca(cursore.start, cursore.end) ? spento : Testo.segnoNascosto;
      if (segni && p.dentroInizio > p.inizio) figli.add(TextSpan(text: testo.substring(p.inizio, p.dentroInizio), style: segno));
      figli.add(TextSpan(text: dentro, style: stilePezzo, recognizer: p.uri == null ? null : tocco?.call(p.uri!)));
      if (segni && p.fine > p.dentroFine) figli.add(TextSpan(text: testo.substring(p.dentroFine, p.fine), style: segno));
      at = p.fine;
    }
    _semplice(figli, testo, at, testo.length);
    return TextSpan(style: stile, children: figli);
  }

  /// Il testo semplice tra [da] e [a]: gli «a capo» che fanno una riga vuota (quelli subito dopo un altro) diventano
  /// lo spazio tra due paragrafi. Gli stessi caratteri, solo più bassi: le posizioni nel testo non cambiano.
  static void _semplice(List<InlineSpan> figli, String testo, int da, int a) {
    var at = da;
    for (var i = da; i < a; i++) {
      if (i == 0 || testo.codeUnitAt(i) != _aCapo || testo.codeUnitAt(i - 1) != _aCapo) continue;
      if (i > at) figli.add(TextSpan(text: testo.substring(at, i)));
      figli.add(const TextSpan(text: _rigaVuota, style: Testo.rigaVuota));
      at = i + 1;
    }
    if (a > at) figli.add(TextSpan(text: testo.substring(at, a)));
  }

  static const _aCapo = 0x0A, _rigaVuota = '\n';

  /// Apre un collegamento con l'app giusta (il browser, la posta, il telefono).
  static Future<void> apri(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}
