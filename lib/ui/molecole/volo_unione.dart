import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atomi.dart';
import '../ds.dart';

/// Unendo (5 nov: «le ho unite così in fretta che mi è sembrato strano»): le schede scelte volano una dopo
/// l'altra, nell'ordine, sulla prima e ci spariscono sotto; poi la scheda unita arriva al suo posto e fa un
/// battito. Sopra la pagina (le schede vere intanto sono nascoste da chi chiama). [schede]: dove sta ognuna
/// e la sua copia, la prima è quella su cui volano. [arrivo]: dove sta la scheda unita e la sua copia, quando
/// il nativo ha finito e la pagina l'ha ridisegnata (null: niente battito). Finisce quando il volo è finito.
Future<void> voloUnione(BuildContext context, {required List<(Rect, Widget)> schede, required Future<(Rect, Widget)?> arrivo}) =>
    _vola(context, (fine) => _Volo(schede: schede, unita: arrivo, onFinito: fine));

/// «Annulla» dopo un'unione: lo stesso volo al contrario. La scheda [unita] (dove sta e la sua copia) torna al
/// posto della prima, batte, e da lei escono le altre, ognuna fino al suo posto. [schede]: dove stanno le schede
/// rimesse com'erano, quando la pagina le ha ridisegnate (nascoste da chi chiama), nell'ordine dell'unione.
Future<void> voloSeparazione(BuildContext context, {required (Rect, Widget) unita, required Future<List<(Rect, Widget)>> schede}) =>
    _vola(context, (fine) => _Volo(schede: schede, unita: unita, indietro: true, onFinito: fine));

Future<void> _vola(BuildContext context, Widget Function(VoidCallback fine) volo) {
  final finito = Completer<void>();
  late final OverlayEntry sopra;
  sopra = OverlayEntry(
    builder: (_) => volo(() {
      sopra.remove();
      finito.complete();
    }),
  );
  Overlay.of(context, rootOverlay: true).insert(sopra);
  return finito.future;
}

class _Volo extends StatefulWidget {
  const _Volo({required this.schede, required this.unita, required this.onFinito, this.indietro = false});

  /// Le schede: subito (unendo) o quando la pagina le ha rimesse (separando).
  final FutureOr<List<(Rect, Widget)>> schede;

  /// La scheda unita: quando arriva (unendo) o subito (separando).
  final FutureOr<(Rect, Widget)?> unita;
  final VoidCallback onFinito;

  /// Al contrario: la scheda unita si divide e le altre tornano ai loro posti.
  final bool indietro;

  @override
  State<_Volo> createState() => _VoloState();
}

class _VoloState extends State<_Volo> with TickerProviderStateMixin {
  late final _vola = AnimationController(vsync: this, duration: Durata.voloUnione);
  late final _batte = AnimationController(vsync: this, duration: Durata.battito);

  List<(Rect, Widget)>? _schede;

  /// La scheda unita e dove sta, quando c'è.
  (Rect, Widget)? _unita;

  @override
  void initState() {
    super.initState();
    if (widget.schede case final List<(Rect, Widget)> s) _schede = s;
    if (widget.unita case final (Rect, Widget) u) _unita = u;
    widget.indietro ? _separa() : _unisci();
  }

  Future<void> _unisci() async {
    await _vola.forward();
    HapticFeedback.mediumImpact();
    final unita = await widget.unita;
    if (!mounted) return;
    if (unita != null) {
      setState(() => _unita = unita);
      await _batte.forward();
    }
    widget.onFinito();
  }

  /// Al contrario: si parte da dove si arriva unendo (tutte sotto la prima, la scheda unita al suo posto).
  Future<void> _separa() async {
    _vola.value = 1;
    _batte.value = 1;
    final schede = await widget.schede;
    if (!mounted) return;
    if (schede.isNotEmpty) {
      setState(() => _schede = schede);
      await _batte.reverse();
      HapticFeedback.mediumImpact();
      await _vola.reverse();
    }
    widget.onFinito();
  }

  @override
  void dispose() {
    _vola.dispose();
    _batte.dispose();
    super.dispose();
  }

  /// A che punto è il volo della scheda [i] (dalla seconda): partono una dopo l'altra, ognuna vola per
  /// `Durata.normale`, l'ultima arriva alla fine.
  double _t(int i) {
    final n = _schede!.length - 1;
    final volo = Durata.normale.inMilliseconds, tutto = Durata.voloUnione.inMilliseconds;
    final parte = n <= 1 ? 0 : (tutto - volo) * (i - 1) / (n - 1);
    return ((_vola.value * tutto - parte) / volo).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final schede = _schede;
    final unita = _unita;
    // Separando, finché la pagina non ha rimesso le schede: solo la scheda unita, ferma al suo posto.
    if (schede == null || schede.isEmpty) return unita == null ? const SizedBox.shrink() : IgnorePointer(child: Stack(children: [_scheda(context, unita.$1, unita.$2, 1)]));
    final (prima, copia) = schede.first;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_vola, _batte]),
        builder: (context, _) {
          // Le altre volano sotto la prima, stringendosi e svanendo all'arrivo (separando, il contrario).
          final volanti = [
            for (var i = schede.length - 1; i >= 1; i--)
              if (_t(i) < 1)
                Positioned.fromRect(
                  rect: Rect.lerp(schede[i].$1, prima, Curva.standard.transform(_t(i)))!,
                  child: Opacity(
                    opacity: 1 - Curva.uscita.transform(_t(i)),
                    child: Transform.scale(scale: 1 - (1 - Scala.scelta) * _t(i), child: schede[i].$2),
                  ),
                ),
          ];
          // La prima: ferma mentre arrivano; poi diventa la scheda unita, va al suo posto e batte.
          // Separando, la scheda unita torna qui e, ferma, ridiventa la prima.
          final b = _batte.value;
          final dentro = unita == null || (widget.indietro && b == 0) ? copia : unita.$2;
          return Stack(
            children: [
              ...volanti,
              _scheda(context, unita == null ? prima : Rect.lerp(prima, unita.$1, Curva.standard.transform(b))!, dentro, 1 + (Scala.battito - 1) * math.sin(b * math.pi)),
            ],
          );
        },
      ),
    );
  }

  /// Una scheda in volo, con l'ombra di ciò che sta sopra tutto.
  Widget _scheda(BuildContext context, Rect dove, Widget copia, double scala) => Positioned.fromRect(
    rect: dove,
    child: Transform.scale(
      scale: scala,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: Scheda.forma(context.col).copyWith(side: BorderSide.none), shadows: Ombra.sospeso),
        child: copia,
      ),
    ),
  );
}
