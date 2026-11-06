import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';
import 'isola.dart';

/// In cima alla pagina, come il Dock in fondo (6 nov, sua richiesta: «come WhatsApp e Samsung»).
/// Ferma in cima è una barra: il titolo grande, accanto il [segno] («Dati finti»), sotto, se c'è, una riga
/// ([sotto]: le registrazioni in attesa). Quando la pagina ([child]) scorre la barra si ritira e restano due pillole
/// che galleggiano sopra di lei, le stesse isole del Dock: a sinistra il titolo (col segno e [accanto]), a destra le
/// [azioni]. La pagina scorre sotto di loro; tornata in cima (o cambiata [pagina]) torna la barra.
///
/// Con [indietro] a sinistra del titolo c'è ‹, nella barra e nella pillola: lo stesso tasto.
///
/// Con [filtri] (Trascrivi: i filtri accesi, 6 nov, giro 7) la loro fila sta sotto il titolo, nella barra; il tasto
/// «Filtri» che li sceglie è una delle [azioni], allo stesso posto nella barra e nelle pillole.
///
/// Le azioni sono tondi [BottoneIcona] di misura [Misura.tondo] e restano sempre allo stesso posto: ferme sono
/// nude sulla barra, scorrendo il loro fondo diventa un'isola. Tutto si muove con [Durata.normale].
class Intestazione extends StatefulWidget {
  const Intestazione({
    super.key,
    required this.titolo,
    required this.child,
    this.pagina,
    this.azioni = const [],
    this.segno,
    this.sotto,
    this.accanto,
    this.indietro,
    this.filtri,
  });

  /// Fin dove arrivano le pillole, dall'alto della pagina: quello che galleggia sopra la pagina sta più giù.
  static const altaPillole = Spazio.s2 + Misura.isola;

  /// Dove comincia quello che sta sotto le pillole, col suo respiro: la data che resta in cima, e lo spazio che le
  /// liste lasciano in cima perché, arrivate in fondo scorrendo, le pillole non coprano il primo titolo.
  static const sottoPillole = altaPillole + Spazio.s2;

  /// Quanto deve scorrere la pagina perché la barra diventi pillole; per tornare barra deve arrivare quasi in cima
  /// ([_cima]): in mezzo non cambia niente, così il bordo non sfarfalla.
  static const soglia = Spazio.s6, _cima = Spazio.s1;

  final String titolo;
  final Widget child;

  /// Quale pagina c'è sotto (cambiando potere, o pagina nel Dock): una pagina nuova comincia con la barra.
  final Object? pagina;
  final List<Widget> azioni;
  final Widget? segno, sotto, accanto;

  /// ‹ a sinistra del titolo: torna indietro (null: non c'è).
  final VoidCallback? indietro;

  /// La fila dei filtri accesi, sotto il titolo (null: la pagina non ne ha).
  final Widget? filtri;

  @override
  State<Intestazione> createState() => _IntestazioneState();
}

class _IntestazioneState extends State<Intestazione> {
  bool ridotta = false;

  Widget? get _indietro =>
      widget.indietro == null ? null : BottoneIcona(Icons.arrow_back_rounded, etichetta: 'Indietro', misura: Misura.tondo, onTap: widget.indietro);

  @override
  void didUpdateWidget(covariant Intestazione prima) {
    super.didUpdateWidget(prima);
    if (prima.pagina != widget.pagina) ridotta = false;
  }

  /// Solo la lista principale della pagina, in verticale (le file di lato non contano).
  bool _scorre(Notification n) {
    final (metrica, profonda) = switch (n) {
      ScrollNotification n => (n.metrics, n.depth),
      ScrollMetricsNotification n => (n.metrics, n.depth),
      _ => (null, 1),
    };
    if (metrica == null || profonda != 0 || metrica.axis != Axis.vertical) return false;
    final r = metrica.pixels > Intestazione.soglia || (ridotta && metrica.pixels > Intestazione._cima);
    if (r != ridotta) setState(() => ridotta = r);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final larghe = widget.azioni.length * Misura.tondo + 2 * Isola.margine;
    final azioni = widget.azioni.isEmpty
        ? null
        : Isola(
            fondo: ridotta,
            child: Row(mainAxisSize: MainAxisSize.min, children: widget.azioni),
          );
    return Stack(
      children: [
        Column(
          children: [
            // La barra si ritira verso l'alto (e sfuma): la pagina sale al suo posto.
            ClipRect(
              child: AnimatedAlign(
                duration: Durata.normale,
                curve: Curva.standard,
                alignment: Alignment.topCenter,
                heightFactor: ridotta ? 0 : 1,
                child: AnimatedOpacity(
                  duration: Durata.veloce,
                  opacity: ridotta ? 0 : 1,
                  child: IgnorePointer(ignoring: ridotta, child: _barra(larghe)),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<Notification>(onNotification: _scorre, child: widget.child),
            ),
          ],
        ),
        Positioned(
          top: Spazio.s2,
          left: Spazio.s3,
          right: Spazio.s3,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: Durata.normale,
                    transitionBuilder: (w, a) => Spunta(animazione: a, da: Alignment.centerLeft, child: w),
                    child: ridotta ? _PillolaTitolo(titolo: widget.titolo, segno: widget.segno, accanto: widget.accanto, indietro: _indietro) : const SizedBox.shrink(),
                  ),
                ),
              ),
              if (azioni != null) ...[
                const SizedBox(width: Spazio.s2),
                azioni,
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// La barra, ferma in cima: il titolo (a sinistra delle azioni, che le stanno sopra) e la riga sotto.
  Widget _barra(double larghe) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(widget.indietro == null ? Spazio.s5 : Spazio.s3 + Isola.margine, Spazio.s2, Spazio.s3 + larghe + Spazio.s2, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Misura.isola),
          child: Row(
            children: [
              ?_indietro,
              Flexible(
                flex: 2,
                child: AnimatedSwitcher(
                  duration: Durata.normale,
                  layoutBuilder: (attuale, prima) => Stack(alignment: Alignment.centerLeft, children: [...prima, ?attuale]),
                  child: Text(
                    widget.titolo,
                    key: ValueKey(widget.titolo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testo.titoloPagina.copyWith(color: context.col.testo),
                  ),
                ),
              ),
              if (widget.segno != null) Flexible(child: Padding(padding: const EdgeInsets.only(left: Spazio.s2), child: _stretto(widget.segno!))),
            ],
          ),
        ),
      ),
      AnimatedSize(
        duration: Durata.normale,
        curve: Curva.standard,
        alignment: Alignment.topLeft,
        child: widget.sotto == null
            ? const SizedBox(width: double.infinity)
            : Padding(padding: const EdgeInsets.fromLTRB(Spazio.s5, 0, Spazio.s3, 0), child: widget.sotto),
      ),
      // I filtri accesi, sotto il titolo (con la barra, se ne vanno anche loro). Nessuno: niente spazio.
      AnimatedSize(
        duration: Durata.normale,
        curve: Curva.standard,
        alignment: Alignment.topLeft,
        child: widget.filtri == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: Spazio.s2), child: widget.filtri),
      ),
    ],
  );
}

/// Il titolo come pillola, quando la pagina scorre: il nome della pagina e, accanto, i segni che restano (i dati finti,
/// le registrazioni in attesa).
class _PillolaTitolo extends StatelessWidget {
  const _PillolaTitolo({required this.titolo, this.segno, this.accanto, this.indietro});

  final String titolo;
  final Widget? segno, accanto, indietro;

  @override
  Widget build(BuildContext context) => Isola(
    padding: Isola.bordo(tondoPrima: indietro != null),
    child: SizedBox(
      height: Misura.tondo,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Spazio.s2,
        children: [
          ?indietro,
          Flexible(
            flex: 2,
            child: Text(titolo, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.titoloPillola.copyWith(color: context.col.testo)),
          ),
          for (final s in [?segno, ?accanto]) Flexible(child: _stretto(s)),
        ],
      ),
    ),
  );
}

/// I segni accanto al titolo (i dati finti, le registrazioni in attesa): su un telefono stretto col testo grande si
/// rimpiccioliscono invece di sbordare; il titolo ha la precedenza.
Widget _stretto(Widget segno) => FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: segno);
