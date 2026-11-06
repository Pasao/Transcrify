import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atomi.dart';
import '../ds.dart';
import 'intestazione.dart';

/// Scorrere tra i giorni di Trascrivi, come nella Galleria. Mentre scorri:
/// - in cima, al centro sotto le pillole, la data del giorno che stai guardando (6 nov: «come Samsung Gallery»);
///   compare scorrendo e se ne va poco dopo che ti sei fermato;
/// - sul bordo destro lo slider veloce: se lo prendi corri da un capo all'altro, e la data sta accanto al dito
///   (allora quella in cima si fa da parte). Tutte e due sono la stessa [EtichettaSospesa].
class ScorriGiorni extends StatefulWidget {
  const ScorriGiorni({super.key, required this.controller, required this.bottom, required this.giornoA, required this.child});

  /// Il controller della lista ([child]), al contrario: 0 pixel vuol dire oggi, in fondo.
  final ScrollController controller;

  /// Lo spazio in fondo coperto dal Dock: lo slider si ferma prima.
  final double bottom;

  /// Il giorno che si vede a questa altezza dello schermo (l'ultimo che comincia sopra quel punto).
  final String? Function(double y) giornoA;
  final Widget child;

  @override
  State<ScorriGiorni> createState() => _ScorriGiorniState();
}

class _ScorriGiorniState extends State<ScorriGiorni> {
  /// Quanto è alta la barretta da prendere, e quanto è larga la zona per il dito attorno a lei.
  static const _barretta = Misura.isola, _presa = Misura.tocco - Spazio.s3;

  bool _visibile = false, _trascini = false;

  /// Il giorno accanto al dito (trascinando lo slider) e quello in cima.
  String? _giorno, _inCima;
  Timer? _via;

  @override
  void dispose() {
    _via?.cancel();
    super.dispose();
  }

  void _mostra() {
    _via?.cancel();
    if (!_visibile) setState(() => _visibile = true);
    _leggiCima();
    if (!_trascini) {
      _via = Timer(Durata.conferma, () {
        if (mounted) setState(() => _visibile = false);
      });
    }
  }

  bool get _usabile => widget.controller.hasClients && widget.controller.position.maxScrollExtent > 0;

  /// Da 0 (in alto, le più vecchie) a 1 (in fondo, oggi): la pagina è al contrario, 0 pixel vuol dire oggi.
  double get _at => _usabile ? 1 - (widget.controller.offset / widget.controller.position.maxScrollExtent).clamp(0.0, 1.0) : 1;

  void _trascina(double dy, double binario) {
    final max = widget.controller.position.maxScrollExtent;
    final to = (_at + dy / binario).clamp(0.0, 1.0);
    widget.controller.jumpTo(max * (1 - to));
    _leggiGiorno();
  }

  RenderBox? get _box => context.findRenderObject() as RenderBox?;

  /// Il giorno al centro, accanto al dito.
  void _leggiGiorno() {
    final box = _box;
    if (box == null) return;
    final giorno = widget.giornoA(box.localToGlobal(Offset.zero).dy + box.size.height / 2);
    if (giorno != _giorno) {
      if (_giorno != null) HapticFeedback.selectionClick();
      setState(() => _giorno = giorno);
    }
  }

  /// Il giorno in cima, appena sotto le pillole dell'intestazione.
  void _leggiCima() {
    final box = _box;
    if (box == null || !box.hasSize) return;
    final giorno = widget.giornoA(box.localToGlobal(Offset.zero).dy + Intestazione.sottoPillole);
    if (giorno != _inCima) setState(() => _inCima = giorno);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Le schede del giorno scorrono di lato: quelle non contano.
        if (n.metrics.axis == Axis.vertical && n is ScrollUpdateNotification) _mostra();
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          // La data in cima, al centro.
          Positioned(
            top: Intestazione.sottoPillole,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _visibile && !_trascini && _inCima != null ? 1 : 0,
                  duration: Durata.normale,
                  curve: Curva.standard,
                  child: _inCima == null ? const SizedBox.shrink() : EtichettaSospesa(_inCima!),
                ),
              ),
            ),
          ),
          Positioned(
            top: Spazio.s1,
            right: 0,
            bottom: widget.bottom + Spazio.s1,
            left: 0,
            child: LayoutBuilder(
              builder: (context, box) {
                final binario = box.maxHeight - _barretta;
                return AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    if (!_usabile) return const SizedBox.shrink();
                    return IgnorePointer(
                      ignoring: !_visibile,
                      child: AnimatedOpacity(
                        opacity: _visibile ? 1 : 0,
                        duration: Durata.veloce,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              top: _at * binario,
                              height: _barretta,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) {
                                  HapticFeedback.selectionClick();
                                  _via?.cancel();
                                  setState(() => _trascini = true);
                                  _leggiGiorno();
                                },
                                onVerticalDragUpdate: (d) => _trascina(d.delta.dy, binario),
                                onVerticalDragEnd: (_) => _lascia(),
                                onVerticalDragCancel: _lascia,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_trascini && _giorno != null)
                                      Padding(padding: const EdgeInsets.only(right: Spazio.s2), child: EtichettaSospesa(_giorno!)),
                                    // Una zona larga per il dito, attorno a una barretta sottile.
                                    SizedBox(
                                      width: _presa,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: AnimatedContainer(
                                          duration: Durata.veloce,
                                          width: _trascini ? Spazio.s2 : Spazio.s1 + 1,
                                          height: _barretta,
                                          margin: const EdgeInsets.only(right: Spazio.s1 - 1),
                                          decoration: BoxDecoration(
                                            color: _trascini ? c.azione : c.testoSecondario,
                                            borderRadius: BorderRadius.circular(Raggio.piccolo),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _lascia() {
    setState(() => _trascini = false);
    _mostra();
  }
}
