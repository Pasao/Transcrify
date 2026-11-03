import 'package:flutter/material.dart';

import '../ds.dart';

/// Un'isola: un pezzo che galleggia sopra la pagina (le isole del Dock), col fondo «isola»,
/// a pillola, con l'ombra «appoggiato».
class Isola extends StatelessWidget {
  const Isola({super.key, required this.child, this.padding = const EdgeInsets.all((Misura.isola - Misura.tondo) / 2), this.raggio});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Di base una pillola; la pillola delle pagine ha l'angolo piccolo dal lato del medaglione.
  final BorderRadius? raggio;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: context.col.isola, borderRadius: raggio ?? BorderRadius.circular(Raggio.pillola), boxShadow: Ombra.appoggiato),
    child: child,
  );
}
