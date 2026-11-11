import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../../core/titoli.dart';
import '../common.dart';
import '../theme.dart';
import 'corpo_scheda.dart';

/// Una trascrizione nel carosello del giorno (Trascrivi e le cartelle).
/// Tenendola premuta si sceglie (5 nov: un gesto solo, come nella Galleria). Tenendo premuto il cestino la scheda
/// si fa rossa, trema e sparisce. Col colore, il fondo è la sua tinta.
/// Tutte hanno la stessa forma e la stessa altezza (6 nov, giro 6, sua idea): in alto il testo, in fondo una fascia di
/// due righe (7 nov): sopra il titolo (`Titoli.di`; senza, l'inizio del testo più tenue), sotto l'ora, le iconcine e
/// il cestino a destra. Offuscata, il titolo resta e la fascia pure: le macchie coprono solo il testo, e si fermano
/// mentre la tieni premuta.
/// Mentre se ne scelgono: la scelta resta a colori, si stringe appena, col contorno, l'ombra e la spunta; le altre
/// si spengono e perdono il colore, col tondo vuoto. Si vede su ogni tinta, nel chiaro e nello scuro.
class SchedaTrascrizione extends StatefulWidget {
  const SchedaTrascrizione({
    super.key,
    required this.entry,
    required this.onOpen,
    this.onDelete,
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
  /// Il cestino; null: non c'è (la prima trascrizione nella prova dell'introduzione: solo «Entra»).
  final VoidCallback? onDelete;

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

  /// La copertura dell'offuscata: una luce più scura della sua tinta e le sue macchie; senza colore, neutre.
  static CoperturaPrivata copertura(BuildContext context, Entry e, {bool ferma = false}) {
    final c = e.colore, luce = Theme.of(context).brightness;
    return c == null
        ? CoperturaPrivata.neutra(context, ferma: ferma)
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
        if (mounted) widget.onDelete?.call();
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
                  // Il testo, o la copertura col lucchetto: lo stesso posto su ogni scheda (`CorpoScheda`, come le note).
                  // Quando cambia (resa privata dalla trascrizione aperta, che si chiude) la copertura arriva sul testo.
                  child: CorpoScheda(
                    riempie: true,
                    coperta: entry.privata,
                    copertura: SchedaTrascrizione.copertura(context, entry, ferma: _premuta),
                    testo: _anteprima(entry),
                    titolo: Padding(padding: const EdgeInsets.only(right: Spazio.s2), child: _titolo(entry)),
                    info: _fascia(entry),
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

  /// La fascia (7 nov, sua richiesta: il cestino sotto il titolo): sopra solo il titolo, sotto l'ora con le iconcine
  /// (da dove arriva, se l'ha ripassata l'AI, se il colore l'ha messo l'app) e il cestino a destra. L'ora e le
  /// iconcine si stringono loro se la scheda è stretta.
  /// Il titolo (`Titoli.di`; senza, l'inizio del testo più tenue).
  Widget _titolo(Entry entry) => Text(
    Titoli.di(entry),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Testo.etichetta.copyWith(color: Titoli.provvisorio(entry) ? context.col.testoSecondario : context.col.testo),
  );

  /// Sotto il titolo: l'ora, le iconcine e il cestino.
  Widget _fascia(Entry entry) {
    final modo = entry.mode;
    // 10 nov, «il cestino è tutto spostato»: l'ora (Flexible) e uno Spacer si dividevano lo spazio a metà, e quello
    // che l'ora non usava restava in fondo: il cestino non stava a destra, e si spostava con l'ora. Ora l'ora e le
    // iconcine stanno nel loro spazio a sinistra, il cestino sempre a destra, tutti centrati in altezza.
    return Row(
      children: [
        Expanded(
          child: Row(
            spacing: Spazio.s2,
            children: [
              Flexible(
                child: Text(hm(entry.at), style: orarioStyle(context), maxLines: 1, overflow: TextOverflow.clip),
              ),
              if (entry.source != null) SourceIcon(entry.source),
              if (SchedaTrascrizione.ripassata.contains(modo)) EtichettaModo(modo!),
              if (entry.coloreAuto && entry.colore != null) const SegnoAuto(),
            ],
          ),
        ),
        if (widget.onDelete case final via? when !widget.selecting)
          DeleteButton(onDelete: via, onHoldStart: _holdStart, onHoldEnd: _holdEnd)
        else
          const SizedBox(height: Misura.bottoneBasso),
      ],
    );
  }
}
