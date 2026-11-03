import 'package:flutter/material.dart';

import '../ds.dart';

/// Il foglio su cui stanno una nota o una trascrizione. «Scelta» = fondo tenue e contorno:
/// l'unico contorno dell'app.
class Scheda extends StatelessWidget {
  const Scheda({
    super.key,
    required this.child,
    this.scelta = false,
    this.padding = const EdgeInsets.fromLTRB(
      Spazio.s4,
      Spazio.s3,
      Spazio.s4,
      Spazio.s3,
    ),
  });

  final Widget child;
  final bool scelta;
  final EdgeInsetsGeometry padding;

  static Color fondo(Colori c, {bool scelta = false}) =>
      scelta ? c.azioneTenue : c.scheda;

  static BorderSide _bordo(Colori c, bool scelta) =>
      BorderSide(color: scelta ? c.azione : Colors.transparent, width: 1.5);

  /// Per un Material (con l'onda del tocco): fondo con [fondo], forma con questa.
  static RoundedRectangleBorder forma(Colori c, {bool scelta = false}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raggio.scheda),
        side: _bordo(c, scelta),
      );

  static Decoration decorazione(Colori c, {bool scelta = false}) =>
      ShapeDecoration(
        color: fondo(c, scelta: scelta),
        shape: forma(c, scelta: scelta),
      );

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Durata.veloce,
    padding: padding,
    decoration: decorazione(context.col, scelta: scelta),
    child: child,
  );
}
