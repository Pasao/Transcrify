import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Dove cade un punto del testo dentro un campo, sullo schermo del campo: lo usano il cursore della voce e il tasto
/// «Apri» di un collegamento. Lo sa il testo disegnato dentro il campo ([RenderEditable]).
abstract final class PuntoNelCampo {
  static RenderEditable? _editabile(RenderObject o) {
    if (o is RenderEditable) return o;
    RenderEditable? trovato;
    o.visitChildren((c) => trovato ??= _editabile(c));
    return trovato;
  }

  /// Il cursore nel punto [punto] (-1 o oltre la fine: in fondo), nelle misure del pezzo [campo] che contiene il campo.
  /// Null se il campo non è ancora disegnato.
  static Rect? cursore(GlobalKey campo, int punto) {
    final box = campo.currentContext?.findRenderObject();
    final testo = box == null ? null : _editabile(box);
    if (box == null || testo == null || !testo.hasSize) return null;
    final lunghezza = testo.plainText.length;
    final dove = testo.getLocalRectForCaret(TextPosition(offset: punto < 0 || punto > lunghezza ? lunghezza : punto));
    return MatrixUtils.transformRect(testo.getTransformTo(box), dove);
  }
}
