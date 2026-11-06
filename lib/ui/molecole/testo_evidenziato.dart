import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ds.dart';

/// Un testo intero con alcuni pezzi illuminati (le frasi scelte dal riassunto estrattivo): quello [attivo]
/// più forte. [TestoEvidenziatoState.mostra] fa scorrere la pagina fino a un pezzo.
class TestoEvidenziato extends StatefulWidget {
  const TestoEvidenziato({super.key, required this.testo, required this.pezzi, this.attivo});

  final String testo;

  /// In ordine, senza sovrapporsi.
  final List<TextRange> pezzi;
  final int? attivo;

  @override
  State<TestoEvidenziato> createState() => TestoEvidenziatoState();
}

class TestoEvidenziatoState extends State<TestoEvidenziato> {
  final _paragrafo = GlobalKey();

  /// Scorre la pagina finché il pezzo [i] sta in alto, con un po' d'aria sopra.
  void mostra(int i) {
    final p = _paragrafo.currentContext?.findRenderObject();
    if (p is! RenderParagraph || i >= widget.pezzi.length) return;
    final y = p.getOffsetForCaret(TextPosition(offset: widget.pezzi[i].start), Rect.zero).dy;
    final pos = Scrollable.of(context).position;
    final arrivo = RenderAbstractViewport.of(p).getOffsetToReveal(p, 0, rect: Rect.fromLTWH(0, y, 1, 1)).offset - Spazio.s10;
    pos.animateTo(arrivo.clamp(pos.minScrollExtent, pos.maxScrollExtent), duration: Durata.lenta, curve: Curva.standard);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final base = Testo.lettura(context).copyWith(color: c.testo);
    final pezzo = base.copyWith(color: c.suAzioneTenue, backgroundColor: c.azioneTenue);
    final forte = base.copyWith(color: c.suAzione, backgroundColor: c.azione);
    final t = widget.testo;
    final spans = <TextSpan>[];
    var da = 0;
    for (final (i, r) in widget.pezzi.indexed) {
      if (r.start < da || r.end > t.length) continue;
      if (r.start > da) spans.add(TextSpan(text: t.substring(da, r.start)));
      spans.add(TextSpan(text: t.substring(r.start, r.end), style: i == widget.attivo ? forte : pezzo));
      da = r.end;
    }
    if (da < t.length) spans.add(TextSpan(text: t.substring(da)));
    return Text.rich(TextSpan(style: base, children: spans), key: _paragrafo);
  }
}
