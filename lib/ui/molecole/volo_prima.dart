import 'dart:async';

import 'package:flutter/material.dart';

import '../ds.dart';

/// La prima trascrizione (10 nov, sua idea): toccando «Entra» alla fine della prova, la scheda al centro
/// dell'introduzione si trasforma in quella vera, al suo posto nella lista di Trascrivi. Il volo sta sopra tutto
/// (l'introduzione intanto se ne va): parte da dov'è la scheda ([parti]) e aspetta che la lista dica dove sta la
/// sua ([arriva]); poi va lì cambiando forma, e la copia diventa la scheda vera. Se la lista non arriva in tempo
/// ([Durata.attesaVoloPrima]), la copia svanisce dov'è.
abstract final class VoloPrima {
  static Completer<(Rect, Widget)?>? _arrivo;
  static Completer<void>? _atterrata;

  /// C'è una prima trascrizione in volo che aspetta il suo posto nella lista.
  static bool get aspetta => _arrivo?.isCompleted == false;

  /// Parte da [da] (sullo schermo) con la sua [copia].
  static void parti(BuildContext context, {required Rect da, required Widget copia}) {
    final arrivo = _arrivo = Completer(), atterrata = _atterrata = Completer<void>();
    late final OverlayEntry sopra;
    sopra = OverlayEntry(
      builder: (_) => _Viaggio(
        da: da,
        copia: copia,
        arrivo: arrivo.future.timeout(Durata.attesaVoloPrima, onTimeout: () => null),
        onFinito: () {
          sopra.remove();
          if (!arrivo.isCompleted) arrivo.complete(null);
          atterrata.complete();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(sopra);
  }

  /// La lista mostra la scheda vera: dove sta e la sua copia (null: non c'è). Finisce quando il volo è atterrato.
  static Future<void> arriva((Rect, Widget)? a) {
    final arrivo = _arrivo, atterrata = _atterrata;
    if (arrivo == null || arrivo.isCompleted || atterrata == null) return Future.value();
    arrivo.complete(a);
    return atterrata.future;
  }
}

class _Viaggio extends StatefulWidget {
  const _Viaggio({required this.da, required this.copia, required this.arrivo, required this.onFinito});

  final Rect da;
  final Widget copia;
  final Future<(Rect, Widget)?> arrivo;
  final VoidCallback onFinito;

  @override
  State<_Viaggio> createState() => _ViaggioState();
}

class _ViaggioState extends State<_Viaggio> with SingleTickerProviderStateMixin {
  late final _vola = AnimationController(vsync: this, duration: Durata.voloPrima);
  late final _t = CurvedAnimation(parent: _vola, curve: Curva.scambio);

  /// Dove va e la scheda vera; null finché la lista non c'è (o se non arriva: allora svanisce).
  (Rect, Widget)? _a;

  @override
  void initState() {
    super.initState();
    widget.arrivo.then((a) async {
      if (!mounted) return;
      setState(() => _a = a);
      await _vola.forward();
      widget.onFinito();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    _vola.dispose();
    super.dispose();
  }

  /// [copia] larga e alta come [misura], stirata nel posto del volo.
  static Widget _stesa(Size misura, Widget copia) => FittedBox(fit: BoxFit.fill, child: SizedBox.fromSize(size: misura, child: copia));

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = _t.value, a = _a;
          return Stack(
            children: [
              Positioned.fromRect(
                rect: a == null ? widget.da : Rect.lerp(widget.da, a.$1, t)!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(opacity: 1 - t, child: _stesa(widget.da.size, widget.copia)),
                    if (a != null) Opacity(opacity: t, child: _stesa(a.$1.size, a.$2)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
