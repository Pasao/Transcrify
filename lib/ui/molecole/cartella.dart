import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';
import 'fogli_cartella.dart';

/// Una cartella: le trascrizioni di un colore (Figma D2, riga 3). Il dorso e la linguetta in una luce più scura,
/// la tasca davanti nella luce del fondo delle schede; tra i due sporgono le più nuove (FogliCartella).
/// Sulla tasca il nome (tuo, o quello della tinta) e quante sono.
///
/// Gli stessi gesti delle schede: premuta la tasca si piega appena e i fogli salgono; toccata si apre ([onTocco]:
/// la sua pagina); tenuta premuta si sceglie ([onScegli]). Mentre se ne scelgono ([scelta] non null) il
/// tocco la sceglie o la toglie, e sulla tasca c'è la spunta.
class Cartella extends StatefulWidget {
  const Cartella({
    super.key,
    required this.colore,
    required this.nome,
    required this.voci,
    required this.onTocco,
    required this.onScegli,
    this.scelta,
  });

  final Colore colore;
  final String nome;

  /// Le sue trascrizioni, dalla più nuova: quante sono, e le prime come fogli che sporgono.
  final List<Entry> voci;

  final VoidCallback onTocco, onScegli;

  /// null: non si stanno scegliendo cartelle; se no, se è tra le scelte.
  final bool? scelta;

  /// Quanto si apre premuta.
  static const _premuta = 0.35;

  @override
  State<Cartella> createState() => _CartellaState();
}

class _CartellaState extends State<Cartella> with SingleTickerProviderStateMixin {
  late final _apertura = AnimationController(vsync: this, duration: Durata.veloce);

  @override
  void dispose() {
    _apertura.dispose();
    super.dispose();
  }

  void _chiudi() => _apertura.animateBack(0, curve: Curva.standard);

  void _tocco() {
    if (widget.scelta != null) return _scegli();
    _chiudi();
    HapticFeedback.lightImpact();
    widget.onTocco();
  }

  void _scegli() {
    _chiudi();
    HapticFeedback.selectionClick();
    widget.onScegli();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final luce = Theme.of(context).brightness;
    final tinta = widget.colore.tinta;
    final n = widget.voci.length;
    final quante = n == 1 ? '1 trascrizione' : '$n trascrizioni';
    final scelta = widget.scelta ?? false;
    return Semantics(
      button: true,
      selected: widget.scelta,
      label: 'Cartella ${widget.nome}, $quante',
      onLongPressHint: 'Scegli la cartella',
      child: GestureDetector(
        onTapDown: (_) => _apertura.animateTo(Cartella._premuta, curve: Curva.standard),
        onTapCancel: _chiudi,
        onTap: _tocco,
        onLongPress: _scegli,
        child: AspettoScelta(
          scegliendo: widget.scelta != null,
          scelta: scelta,
          child: Stack(
            children: [
              SagomaCartella(
                dorso: Tinte.dorso(tinta, luce),
                davanti: Tinte.fondo(tinta, luce),
                apertura: _apertura,
                dentro: FogliCartella(widget.voci),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.nome, style: Testo.titoloScheda.copyWith(color: c.testo), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(quante, style: Testo.piccolo.copyWith(color: c.testoSecondario), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // La spunta sta sulla tasca, in alto a destra: sopra ci sono i fogli.
              if (widget.scelta != null)
                Positioned(
                  top: SagomaCartella.linguetta + SagomaCartella.bocca + Spazio.s2,
                  right: Spazio.s2,
                  child: SpuntaScelta(scelta: scelta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
