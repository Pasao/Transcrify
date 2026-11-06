import 'package:flutter/widgets.dart';

import '../ds.dart';
import 'formattato.dart';

/// Il controller dei campi dove scrivi una trascrizione o una nota: il testo si vede formattato ([Formattato]).
/// I segni (`**`, `*`) restano nel testo, perché quello che si salva è esattamente quello che hai scritto, ma non si
/// vedono (7 nov: «strano che mi mostri ancora gli asterischi»): tornano, spenti, solo dove sta il cursore.
/// Le lettere sono sempre quelle per leggere ([Testo.lettura]): del campo si prende solo il colore.
class CampoFormattato extends TextEditingController {
  CampoFormattato({super.text});

  /// Lo stile del testo: quello per leggere, nel colore del campo.
  static TextStyle stile(BuildContext context, TextStyle? delCampo) => Testo.lettura(context).copyWith(color: delCampo?.color);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final s = stile(context, style);
    // Mentre la tastiera sta componendo una parola si lascia fare a Flutter (la sottolineatura della parola).
    if (withComposing && value.composing.isValid && !value.composing.isCollapsed) {
      return super.buildTextSpan(context: context, style: s, withComposing: withComposing);
    }
    return Formattato.span(context, text, stile: s, cursore: selection);
  }
}
