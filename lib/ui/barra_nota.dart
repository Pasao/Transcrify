import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'theme.dart';

/// La barra sotto la nota, sopra la tastiera (7 nov, il disegno scelto da lui): a sinistra si scrive (annulla e
/// ripeti, grassetto, corsivo, elenco, link), una linea in piedi, a destra l'intelligenza (gli argomenti che
/// colorano la nota, il riassunto). Quando hai appena dettato qualcosa con Transcri, in fondo il tasto per incollarlo.
/// Stretta, la parte per scrivere scorre di lato: quella dell'intelligenza resta sempre intera.
class BarraNota extends StatelessWidget {
  const BarraNota({
    super.key,
    required this.undo,
    required this.onGrassetto,
    required this.onCorsivo,
    required this.onElenco,
    required this.onLink,
    required this.dictation,
    required this.onPaste,
    required this.topics,
    required this.onTopics,
    required this.onSlideStart,
    required this.onSlide,
    required this.onSlideEnd,
    required this.onSummarize,
    this.summarizing = false,
    this.summaryOn = false,
  });

  final UndoHistoryController undo;
  final VoidCallback onGrassetto, onCorsivo, onElenco, onLink;
  final Entry? dictation;
  final VoidCallback onPaste;

  /// La grana degli argomenti ([Grana]). Il tasto c'è sempre: se non sono pronti, toccandolo dice perché.
  final int topics;
  final VoidCallback onTopics;

  /// Tenendo il tasto (o tirandolo su) compare la scala con i nomi delle grane: [onSlide] riceve dov'è il dito sullo schermo.
  final VoidCallback onSlideStart, onSlideEnd;
  final ValueChanged<Offset> onSlide;

  /// Passa dal testo al riassunto e ritorno.
  final VoidCallback onSummarize;
  final bool summarizing;

  /// Si sta leggendo il riassunto: il tasto è acceso e riporta al testo intero.
  final bool summaryOn;

  static Widget _tasto(IconData icona, String etichetta, VoidCallback? onTap, {TipoIcona tipo = TipoIcona.trasparente, Widget? figlio}) =>
      BottoneIcona(icona, etichetta: etichetta, onTap: onTap, tipo: tipo, misura: Misura.bottoneBasso, figlio: figlio);

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final scrivi = ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: undo,
      builder: (context, v, _) => Row(
        children: [
          _tasto(Icons.undo_rounded, 'Annulla', v.canUndo ? undo.undo : null),
          _tasto(Icons.redo_rounded, 'Ripeti', v.canRedo ? undo.redo : null),
          _tasto(Icons.format_bold_rounded, 'Grassetto', onGrassetto),
          _tasto(Icons.format_italic_rounded, 'Corsivo', onCorsivo),
          _tasto(Icons.format_list_bulleted_rounded, 'Elenco', onElenco),
          _tasto(Icons.link_rounded, 'Link', onLink),
        ],
      ),
    );
    final pensa = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gli argomenti: lo stesso del pizzico, per chi non lo conosce. Acceso = colorato.
        Tooltip(
          message: 'Tocca, tira su o pizzica la nota',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTopics,
            onVerticalDragStart: (_) => onSlideStart(),
            onVerticalDragUpdate: (d) => onSlide(d.globalPosition),
            onVerticalDragEnd: (_) => onSlideEnd(),
            onVerticalDragCancel: onSlideEnd,
            onLongPressStart: (_) => onSlideStart(),
            onLongPressMoveUpdate: (d) => onSlide(d.globalPosition),
            onLongPressEnd: (_) => onSlideEnd(),
            child: Padding(padding: const EdgeInsets.all(Spazio.s2), child: BarreGrana(key: const ValueKey('grana'), livello: topics)),
          ),
        ),
        _tasto(
          Icons.short_text_rounded,
          summaryOn ? 'Torna al testo intero' : 'Riassunto',
          onSummarize,
          tipo: summaryOn ? TipoIcona.acceso : TipoIcona.trasparente,
          figlio: summarizing ? const VoiceCircle(phase: 'PROCESSING', size: Misura.iconaGrande) : null,
        ),
      ],
    );
    return BarraInFondo(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spazio.s2, Spazio.s1, Spazio.s2, Spazio.s2),
          child: SizedBox(
            height: Misura.bottoneAlto,
            child: Row(
              children: [
                Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: scrivi)),
                VerticalDivider(width: Spazio.s4, indent: Spazio.s3, endIndent: Spazio.s3, color: c.linea),
                pensa,
                AnimatedSwitcher(
                  duration: Durata.normale,
                  transitionBuilder: (w, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: w)),
                  child: dictation == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(dictation!.at),
                          padding: const EdgeInsets.only(left: Spazio.s1),
                          child: Tooltip(
                            message: 'Incolla la dettatura',
                            child: Bottone('Incolla', tipo: TipoBottone.pieno, alto: false, icona: Icons.mic_rounded, onPressed: onPaste),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
