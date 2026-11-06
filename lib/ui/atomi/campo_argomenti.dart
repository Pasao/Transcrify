import 'package:flutter/widgets.dart';

import '../../core/native.dart';
import '../ds.dart';
import 'campo_formattato.dart';
import 'grana.dart';

/// Il testo della nota con gli argomenti illuminati dietro le lettere, alla grana scelta ([Grana]).
/// Il colore di un pezzo è il suo gruppo di senso ([NoteTopics.gruppo]): i pezzi che dicono cose simili, anche lontani
/// nella nota, hanno lo stesso colore; e lo tengono a ogni grana (le frasi e le parole prendono quello del loro pezzo).
/// Solo finché il testo è quello per cui sono stati fatti: appena scrivi, si spengono e tornano
/// al prossimo salvataggio.
class TopicTextController extends CampoFormattato {
  TopicTextController({super.text});

  NoteTopics? topics;

  /// Il testo per cui [topics] vale.
  String? topicsFor;

  /// La grana: [Grana.spenta], [Grana.argomenti], [Grana.frasi], [Grana.parole].
  int get level => _level;
  int _level = 0;

  /// Cambia la grana e ridisegna il testo coi nuovi colori.
  set level(int l) {
    if (l == _level) return;
    _level = l;
    notifyListeners();
  }

  bool get usable => topics != null && text == topicsFor;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Spenti gli argomenti, o mentre la tastiera compone una parola: il testo formattato del campo (CampoFormattato).
    final componendo = withComposing && value.composing.isValid && !value.composing.isCollapsed;
    if (level == Grana.spenta || !usable || componendo) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final s = CampoFormattato.stile(context, style);
    return switch (level) {
      Grana.frasi => _accents(s, topics!.keyRanges, bold: false),
      Grana.parole => _accents(s, _pairs(topics!.keywords), bold: true),
      _ => _pieces(s, topics!.pieces),
    };
  }

  static List<TextRange> _pairs(List<int> k) => [for (var i = 0; i + 1 < k.length; i += 2) TextRange(start: k[i], end: k[i + 1])];

  /// Il colore del pezzo [i]: quello del suo gruppo di senso.
  Color _color(int i) {
    final tinte = Colori.adesso.argomenti;
    return tinte[topics!.gruppo(i) % tinte.length];
  }

  TextSpan _pieces(TextStyle? style, List<TextRange> pieces) {
    final children = <TextSpan>[];
    var at = 0;
    for (var i = 0; i < pieces.length; i++) {
      final r = pieces[i];
      if (r.start > at) children.add(TextSpan(text: text.substring(at, r.start)));
      children.add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(backgroundColor: _color(i).withValues(alpha: 0.24)),
        ),
      );
      at = r.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }

  /// Frasi e parole chiave: il testo si fa leggero e restano accesi solo dei pezzi (le frasi chiave,
  /// o le parole chiave), ognuno col colore del suo argomento. Si legge l'essenziale in un colpo d'occhio.
  TextSpan _accents(TextStyle? style, List<TextRange> lit, {required bool bold}) {
    final faded = TextStyle(color: (style?.color ?? Colori.adesso.testo).withValues(alpha: 0.28));
    final pieces = topics!.pieces;
    int pieceOf(int at) {
      for (var i = 0; i < pieces.length; i++) {
        if (at < pieces[i].end) return i;
      }
      return pieces.length - 1;
    }

    final children = <TextSpan>[];
    var at = 0;
    for (final r in lit) {
      if (r.start < at) continue;
      if (r.start > at) children.add(TextSpan(text: text.substring(at, r.start), style: faded));
      children.add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(fontWeight: bold ? FontWeight.w600 : null, backgroundColor: _color(pieceOf(r.start)).withValues(alpha: 0.3)),
        ),
      );
      at = r.end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at), style: faded));
    return TextSpan(style: style, children: children);
  }
}
