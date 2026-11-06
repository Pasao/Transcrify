import 'package:flutter/material.dart';

import '../ds.dart';

/// Un pezzo che sta sopra la pagina (la scelta del colore, i colori dell'unione): il fondo
/// delle isole, l'ombra «sospeso», gli angoli che tagliano quello che c'è dentro (anche le onde dei tocchi).
class Sospeso extends StatelessWidget {
  const Sospeso({super.key, required this.child, this.raggio = Raggio.campo, this.padding = EdgeInsets.zero});

  final Widget child;
  final double raggio;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(raggio);
    return DecoratedBox(
      decoration: BoxDecoration(color: context.col.isola, borderRadius: forma, boxShadow: Ombra.sospeso),
      child: ClipRRect(
        borderRadius: forma,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
