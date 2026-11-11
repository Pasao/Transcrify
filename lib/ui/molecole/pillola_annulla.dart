import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';
import 'barra_scelte.dart';

/// Chiude l'«Annulla» in corso: ce n'è uno solo alla volta.
void Function()? _chiudi;

/// Una cosa appena eliminata (o unita, o tolta): «Annulla» per qualche secondo, col cerchio che si consuma. Sta sopra
/// il Dock, senza coprirlo. Restituisce true se l'hai ripresa; altrimenti si può cancellare davvero. Una pillola sola
/// per tutti gli «Annulla» dell'app. [durata]: quanto resta (di base [Durata.annulla]; l'unione ha il suo, più lungo).
Future<bool> undoable(BuildContext context, String label, {Duration durata = Durata.annulla}) {
  HapticFeedback.mediumImpact();
  _chiudi?.call();
  final fatto = Completer<bool>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => PillolaAnnulla(
      testo: label,
      durata: durata,
      onFine: (ripresa) {
        entry.remove();
        if (ripresa) HapticFeedback.selectionClick();
        fatto.complete(ripresa);
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return fatto.future;
}

/// La pillola di «Annulla» (6 nov: «un po' più piccola»): alta quanto un bottone basso, sul fondo scuro di quello che
/// sta sospeso. Trascinata via con il dito (abbastanza lontano, o con uno scatto) se ne va, e l'eliminazione resta.
class PillolaAnnulla extends StatefulWidget {
  const PillolaAnnulla({super.key, required this.testo, required this.durata, required this.onFine});

  /// Quanto la porti col dito, o quanto veloce, perché se ne vada.
  static const via = Spazio.s8, scatto = 400.0;

  final String testo;
  final Duration durata;

  /// Se n'è andata: true se l'hai ripresa con «Annulla».
  final ValueChanged<bool> onFine;

  @override
  State<PillolaAnnulla> createState() => _PillolaAnnullaState();
}

class _PillolaAnnullaState extends State<PillolaAnnulla> with SingleTickerProviderStateMixin {
  late final _mostra = AnimationController(vsync: this, duration: Durata.veloce)..forward();
  late final _tempo = Timer(widget.durata, () => _vai(false));
  bool _andando = false;

  /// Dove l'hai portata col dito.
  Offset _trascina = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tempo;
    _chiudi = () => _vai(false);
  }

  void _lascia(DragEndDetails d) {
    if (_trascina.distance > PillolaAnnulla.via || d.velocity.pixelsPerSecond.distance > PillolaAnnulla.scatto) {
      _vai(false);
    } else {
      setState(() => _trascina = Offset.zero);
    }
  }

  Future<void> _vai(bool ripresa) async {
    if (_andando) return;
    _andando = true;
    _tempo.cancel();
    _chiudi = null;
    await _mostra.reverse();
    widget.onFine(ripresa);
  }

  @override
  void dispose() {
    _tempo.cancel();
    _mostra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sopra il Dock (alto un'isola, col suo margine) e uno stacco.
    final sopra = Misura.isola + Spazio.s3 + MediaQuery.viewPaddingOf(context).bottom + Spazio.s2;
    final s = Colori.sospesi;
    // Mentre si sceglie la barra prende il posto del Dock, ed è più alta: «Annulla» sale sopra di lei.
    return ValueListenableBuilder<bool>(
      valueListenable: Scelta.attiva,
      builder: (context, scegli, child) => AnimatedPositioned(
        duration: Durata.normale,
        curve: Curva.standard,
        left: Spazio.s4,
        right: Spazio.s4,
        bottom: sopra + ConSelezione.spazio(scegli),
        // Nell'Overlay non c'è una pagina sopra: senza un Material il testo prende lo stile di debug (la doppia
        // sottolineatura gialla). Trasparente: dà solo lo stile del testo.
        child: Material(type: MaterialType.transparency, child: child),
      ),
      child: Center(
        child: FadeTransition(
          opacity: _mostra,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _trascina += d.delta),
            onPanEnd: _lascia,
            child: Transform.translate(
              offset: _trascina,
              child: Container(
                height: Misura.bottoneBasso,
                padding: const EdgeInsets.only(left: Spazio.s3, right: Spazio.s1),
                decoration: BoxDecoration(color: context.col.floater, borderRadius: BorderRadius.circular(Raggio.pillola), boxShadow: Ombra.sospeso),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Spazio.s2,
                  children: [
                    _Consuma(widget.durata, colore: s.azione),
                    Flexible(
                      child: Text(widget.testo, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.etichetta.copyWith(color: context.col.suFloater)),
                    ),
                    TextButton(
                      // Sul fondo scuro l'azione del tema scuro: col telefono chiaro quella chiara non si leggeva.
                      style: TextButton.styleFrom(
                        foregroundColor: s.azione,
                        textStyle: Testo.etichetta,
                        minimumSize: const Size(0, Misura.bottoneBasso),
                        padding: const EdgeInsets.symmetric(horizontal: Spazio.s3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _vai(true),
                      child: const Text('Annulla'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quanto manca prima che la cosa se ne vada davvero: un cerchio che si consuma.
class _Consuma extends StatelessWidget {
  const _Consuma(this.durata, {required this.colore});

  /// Lo spessore del cerchio: sottile, come quello degli indicatori.
  static const _tratto = 2.0;

  final Duration durata;
  final Color colore;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: durata,
    builder: (context, resta, _) => SizedBox.square(
      dimension: Misura.iconaPiccola,
      child: CircularProgressIndicator(value: resta, strokeWidth: _tratto, color: colore, backgroundColor: Colori.sospesi.azioneTenue),
    ),
  );
}
