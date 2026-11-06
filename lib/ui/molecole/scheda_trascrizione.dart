import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../../core/titoli.dart';
import '../common.dart';
import '../theme.dart';

/// Una trascrizione nel carosello del giorno (Trascrivi e le cartelle).
/// Tenendola premuta si sceglie (5 nov: un gesto solo, come nella Galleria). Tenendo premuto il cestino la scheda
/// si fa rossa, trema e sparisce. Col colore, il fondo è la sua tinta.
/// Tutte hanno la stessa forma e la stessa altezza (6 nov, giro 6, sua idea): in alto il testo, in fondo una fascia di
/// una riga: l'ora e le iconcine (da dove arriva, se l'ha ripassata l'AI), senza parole, col cestino a destra. Con
/// «Titoli automatici» (prove, giro 7) sopra l'ora c'è il titolo (`Titoli.di`). Privata, la fascia resta: le macchie
/// col lucchetto coprono solo il testo, e si fermano mentre la tieni premuta.
/// Mentre se ne scelgono: la scelta resta a colori, si stringe appena, col contorno, l'ombra e la spunta; le altre
/// si spengono e perdono il colore, col tondo vuoto. Si vede su ogni tinta, nel chiaro e nello scuro.
class SchedaTrascrizione extends StatefulWidget {
  const SchedaTrascrizione({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    this.onTieni,
    this.selected = false,
    this.selecting = false,
    this.nascosta = false,
    this.width = larga,
  });

  /// La larghezza nel carosello del giorno, e l'altezza di ogni scheda.
  static const larga = Misura.schedaLarga, alta = 176.0;

  final Entry entry;
  final double width;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  /// Tenuta premuta: la sceglie (e, se non si stava scegliendo, si comincia).
  final VoidCallback? onTieni;

  /// È tra quelle scelte; [selecting]: se ne stanno scegliendo, il cestino si fa da parte.
  final bool selected, selecting;

  /// Non si vede, ma tiene il suo posto: una sua copia sta sopra (il volo dell'unione e del suo «Annulla»).
  final bool nascosta;

  /// Il fondo di una scheda: la sua tinta, se ne ha una; scelta e senza colore, il fondo tenue.
  static Color fondo(BuildContext context, Entry e, {bool scelta = false}) {
    final c = e.colore;
    return c == null ? Scheda.fondo(context.col, scelta: scelta) : Tinte.fondo(c.tinta, Theme.of(context).brightness);
  }

  /// La copertura della privata: una luce più scura della sua tinta e le sue macchie; senza colore, neutre.
  static CoperturaPrivata copertura(BuildContext context, Entry e, {bool ferma = false}) {
    final c = e.colore, col = context.col, luce = Theme.of(context).brightness;
    return c == null
        ? CoperturaPrivata(fondo: col.linea, macchie: [col.scheda, col.pagina, col.testoSecondario.withValues(alpha: 0.3)], ferma: ferma)
        : CoperturaPrivata(fondo: Tinte.fondoGiu(c.tinta, luce), macchie: Tinte.macchie(c.tinta, luce), ferma: ferma);
  }

  /// I modi in cui l'AI ha ripassato il testo: sulla scheda la loro iconcina; il testo fedele non ne ha.
  static const ripassata = {'pulita', 'riassunto'};

  @override
  State<SchedaTrascrizione> createState() => _SchedaTrascrizioneState();
}

class _SchedaTrascrizioneState extends State<SchedaTrascrizione> with SingleTickerProviderStateMixin {
  // Il cestino tenuto premuto: la scheda trema fino alla soglia, poi sparisce. Tempi suoi.
  static const _tutto = Duration(milliseconds: 1100); // ds:eccezione: la scheda che trema e sparisce
  static const _finoAllaSoglia = Duration(milliseconds: 700); // ds:eccezione: come sopra

  late final _gone = AnimationController(vsync: this, duration: _tutto);

  /// Il dito è sopra la scheda: le macchie della privata si fermano.
  bool _premuta = false;

  @override
  void initState() {
    super.initState();
    // Senza titolo, se ne propone uno in fondo (solo per le schede che si vedono).
    Titoli.proponi(widget.entry);
  }

  @override
  void didUpdateWidget(covariant SchedaTrascrizione prima) {
    super.didUpdateWidget(prima);
    if (prima.entry != widget.entry) Titoli.proponi(widget.entry);
  }

  @override
  void dispose() {
    _gone.dispose();
    super.dispose();
  }

  // Fino a questo punto lasciare annulla; dopo, la scheda è andata.
  static const _commit = 0.6;
  bool _committed = false;

  void _holdStart() {
    _committed = false;
    HapticFeedback.selectionClick();
    _gone.animateTo(_commit, duration: _finoAllaSoglia, curve: Curves.linear).then((_) {
      if (!mounted || _gone.value < _commit) return;
      _committed = true;
      HapticFeedback.heavyImpact();
      _gone.animateTo(1, duration: Durata.lenta, curve: Curves.easeIn).then((_) {
        if (mounted) widget.onDelete();
      });
    });
  }

  void _holdEnd() {
    if (_committed) return;
    // Ripensamento: torna com'era.
    _gone.animateBack(0, duration: Durata.normale, curve: Curves.easeOut);
  }

  void _tieni() {
    HapticFeedback.mediumImpact();
    widget.onTieni?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scelta = widget.selected;
    final scheda = AnimatedBuilder(
      animation: _gone,
      builder: (context, child) {
        final v = _gone.value;
        // Fino alla soglia: si arrossa e trema sempre di più. Dopo: smette di tremare e svanisce.
        final hold = (v / _commit).clamp(0.0, 1.0);
        final shake = v < _commit ? math.sin(v * 140) * 5 * hold : 0.0;
        final out = Curves.easeIn.transform(((v - _commit) / (1 - _commit)).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Opacity(
            opacity: 1 - out,
            child: Transform.scale(
              scale: 1 - out * 0.25,
              // Il rosso sopra la scheda, con la sua forma (la scheda è piena: come colorarla).
              // Non un filtro di colore: quello costa un livello in più a ogni scheda, anche ferma.
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: hold == 0
                    ? const BoxDecoration()
                    : ShapeDecoration(
                        color: context.col.errore.withValues(alpha: hold * 0.55),
                        shape: Scheda.forma(context.col).copyWith(side: BorderSide.none),
                      ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _scheda(context),
    );
    return Opacity(
      opacity: widget.nascosta ? 0 : 1,
      child: AspettoScelta(scegliendo: widget.selecting, scelta: scelta, child: scheda),
    );
  }

  Widget _scheda(BuildContext context) {
    final entry = widget.entry;
    final scelta = widget.selected;
    return SizedBox(
      width: widget.width,
      height: SchedaTrascrizione.alta,
      child: Stack(
        children: [
          Positioned.fill(
            // La Scheda del design system: «scelta» = contorno (e fondo tenue, se non ha un colore suo) e l'ombra
            // «appoggiato» (calda, come tutte) che la stacca dalla pagina. Fondo, contorno e ombra cambiano insieme e
            // piano (`Durata.scelta`): il contorno sta davanti, sopra anche la copertura della privata.
            child: AnimatedContainer(
              duration: Durata.scelta,
              curve: Curva.standard,
              decoration: ShapeDecoration(
                color: SchedaTrascrizione.fondo(context, entry, scelta: scelta),
                shape: Scheda.forma(context.col).copyWith(side: BorderSide.none),
                shadows: scelta ? Ombra.appoggiato : const [],
              ),
              foregroundDecoration: ShapeDecoration(shape: Scheda.forma(context.col, scelta: scelta)),
              child: Material(
                type: MaterialType.transparency,
                shape: Scheda.forma(context.col).copyWith(side: BorderSide.none),
                // La copertura della privata arriva fino ai bordi: la forma della scheda la taglia.
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onOpen,
                  onLongPress: widget.onTieni == null ? null : _tieni,
                  onHighlightChanged: entry.privata ? (si) => setState(() => _premuta = si) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Il testo, o la copertura col lucchetto: lo stesso posto su ogni scheda.
                      Expanded(
                        child: entry.privata
                            ? SchedaTrascrizione.copertura(context, entry, ferma: _premuta)
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s3, Spazio.s4, 0),
                                child: _anteprima(entry),
                              ),
                      ),
                      // La fascia in fondo, alta uguale su ogni scheda. Il cestino non sta attaccato all'angolo:
                      // lo stesso respiro del testo a sinistra.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s2, Spazio.s2),
                        child: ValueListenableBuilder(valueListenable: Titoli.automatici, builder: (context, titoli, _) => _fascia(entry, titoli)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.selecting)
            Positioned(
              top: Spazio.s2,
              right: Spazio.s2,
              child: SpuntaScelta(scelta: scelta),
            ),
        ],
      ),
    );
  }

  /// L'inizio del testo: le righe intere che ci stanno (col testo grande la fascia cresce e ne restano meno).
  Widget _anteprima(Entry entry) {
    final stile = Testo.letturaScheda(context).copyWith(color: context.col.testo);
    final riga = MediaQuery.textScalerOf(context).scale(stile.fontSize!) * stile.height!;
    return LayoutBuilder(
      builder: (context, box) => Anteprima(
        entry.text,
        righe: (box.maxHeight / riga).floor().clamp(1, 4),
        stile: stile,
        collegamenti: !widget.selecting,
      ),
    );
  }

  /// La fascia: l'ora con le iconcine (si stringono loro se la scheda è stretta) e, con [titoli], sopra il titolo; a
  /// destra il cestino. Tutto centrato in altezza.
  Widget _fascia(Entry entry, bool titoli) {
    final c = context.col;
    final modo = entry.mode;
    final ora = Row(
      spacing: Spazio.s2,
      children: [
        Flexible(
          child: Text(hm(entry.at), style: orarioStyle(context), maxLines: 1, overflow: TextOverflow.clip),
        ),
        if (entry.source != null) SourceIcon(entry.source),
        if (SchedaTrascrizione.ripassata.contains(modo)) EtichettaModo(modo!),
      ],
    );
    return Row(
      children: [
        Expanded(
          child: !titoli
              ? ora
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Titoli.di(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.etichetta.copyWith(color: c.testo)),
                    ora,
                  ],
                ),
        ),
        if (widget.selecting)
          const SizedBox(height: Misura.bottoneBasso)
        else
          DeleteButton(onDelete: widget.onDelete, onHoldStart: _holdStart, onHoldEnd: _holdEnd),
      ],
    );
  }
}
