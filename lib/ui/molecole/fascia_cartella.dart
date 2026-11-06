import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';
import 'fila_schede.dart';
import 'titolo_modificabile.dart';

/// Una cartella aperta lì dov'era (6 nov, giro 6, sua scelta in Figma D5: «un mix tra "si allarga in orizzontale" e
/// "fascia del suo colore"»): una fascia larga quanto la pagina, nel colore del dorso della cartella, con il nome (toccato
/// si rinomina lì), quante sono, la X che la richiude e le sue trascrizioni in una fila che scorre di lato, schede normali.
///
/// Si apre dalla cartella toccata: il colore parte dal suo riquadro ([da], in frazioni della larghezza: sinistra e
/// larghezza) e si allarga fino ai bordi mentre cresce in altezza; poi arriva il contenuto. La X fa la strada al
/// contrario e solo alla fine lo dice a chi la mostra ([onChiudi]).
class FasciaCartella extends StatefulWidget {
  const FasciaCartella({
    super.key,
    required this.colore,
    required this.nome,
    required this.voci,
    required this.scheda,
    required this.onChiudi,
    required this.onRinomina,
    this.da = (0.0, 1.0),
  });

  final Colore colore;
  final String nome;

  /// Le sue trascrizioni, dalla più nuova; [scheda] fa la scheda di ognuna (gli stessi gesti di Trascrivi).
  final List<Entry> voci;
  final Widget Function(Entry) scheda;

  final VoidCallback onChiudi;

  /// Il nome nuovo (vuoto: torna quello della tinta).
  final ValueChanged<String> onRinomina;

  /// Dove stava la cartella, in frazioni della larghezza della pagina: (sinistra, larghezza).
  final (double, double) da;

  /// Quanto è alta, all'inizio, rispetto a quando è aperta: la cartella è poco più bassa della fascia.
  static const _altaDa = 0.6;

  /// Il contenuto arriva quando il colore è già quasi largo.
  static const _contenuto = Interval(0.35, 1, curve: Curva.standard);

  @override
  State<FasciaCartella> createState() => _FasciaCartellaState();
}

class _FasciaCartellaState extends State<FasciaCartella> with SingleTickerProviderStateMixin {
  late final _apre = AnimationController(vsync: this, duration: Durata.lenta, reverseDuration: Durata.normale)..forward();

  @override
  void dispose() {
    _apre.dispose();
    super.dispose();
  }

  Future<void> _chiudi() async {
    await _apre.reverse();
    if (mounted) widget.onChiudi();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final n = widget.voci.length;
    final quante = n == 1 ? '1 trascrizione' : '$n trascrizioni';
    final fondo = Tinte.dorso(widget.colore.tinta, Theme.of(context).brightness);
    final contenuto = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spazio.s5, Spazio.s3, Spazio.s2, Spazio.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TitoloModificabile(
                      titolo: widget.nome,
                      suggerimento: Tinte.nome(widget.colore.tinta, widget.colore.luce),
                      stile: Testo.titoloSezione,
                      righe: 1,
                      onFatto: widget.onRinomina,
                    ),
                    Text(quante, style: Testo.piccolo.copyWith(color: c.testoSecondario), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              BottoneIcona(Icons.close_rounded, etichetta: 'Chiudi la cartella', onTap: _chiudi),
            ],
          ),
        ),
        FilaSchede(chiave: 'cartella ${widget.colore.chiave}', voci: widget.voci, scheda: widget.scheda),
        const SizedBox(height: Spazio.s5),
      ],
    );
    return Semantics(
      container: true,
      label: 'Cartella ${widget.nome} aperta, $quante',
      child: AnimatedBuilder(
        animation: _apre,
        child: contenuto,
        builder: (context, contenuto) {
          final t = Curva.standard.transform(_apre.value);
          final (sinistra, larga) = widget.da;
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: lerpDouble(FasciaCartella._altaDa, 1, t),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  return Stack(
                    children: [
                      // Il colore: dal riquadro della cartella fino ai bordi, perdendo gli angoli tondi.
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: lerpDouble(sinistra * w, 0, t),
                        width: lerpDouble(larga * w, w, t),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Raggio.scheda * (1 - t))),
                        ),
                      ),
                      Opacity(
                        opacity: FasciaCartella._contenuto.transform(_apre.value),
                        child: IgnorePointer(ignoring: _apre.value < 1, child: contenuto),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
