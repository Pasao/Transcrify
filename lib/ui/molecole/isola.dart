import 'package:flutter/material.dart';

import '../ds.dart';

/// Un'isola: un pezzo che galleggia sopra la pagina (le isole del Dock, le pillole dell'intestazione), col fondo
/// «isola», a pillola, con l'ombra «appoggiato».
/// Senza [fondo] resta solo il contenuto, allo stesso posto: l'intestazione ferma in cima è una barra, e scorrendo
/// le sue azioni diventano un'isola (fondo e ombra arrivano piano, col movimento di tutto il resto).
class Isola extends StatelessWidget {
  const Isola({super.key, required this.child, this.padding = const EdgeInsets.all(margine), this.raggio, this.fondo = true});

  /// Lo spazio tra il bordo dell'isola e i tondi che ha dentro.
  static const margine = (Misura.isola - Misura.tondo) / 2;

  /// Lo spazio dal bordo quando dentro ci sono parole (un titolo, il campo della ricerca) invece di un tondo.
  static const lato = Spazio.s4;

  /// Il bordo di un'isola con parole: [lato] ai fianchi con le parole, [margine] dove c'è un tondo ([tondoPrima]:
  /// a sinistra, es. ‹; [tondoDopo]: a destra, es. la X), [margine] sopra e sotto. Le isole del Dock e quelle in
  /// cima hanno così la stessa altezza ([Misura.isola]), lo stesso raggio e gli stessi bordi.
  static EdgeInsets bordo({bool tondoPrima = false, bool tondoDopo = false}) =>
      EdgeInsets.fromLTRB(tondoPrima ? margine : lato, margine, tondoDopo ? margine : lato, margine);

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Di base una pillola; la pillola delle pagine ha l'angolo piccolo dal lato del medaglione.
  final BorderRadius? raggio;
  final bool fondo;

  @override
  Widget build(BuildContext context) {
    final colore = context.col.isola;
    return AnimatedContainer(
      duration: Durata.normale,
      curve: Curva.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: fondo ? colore : colore.withValues(alpha: 0),
        borderRadius: raggio ?? BorderRadius.circular(Raggio.pillola),
        boxShadow: fondo ? Ombra.appoggiato : const [],
      ),
      child: child,
    );
  }
}
