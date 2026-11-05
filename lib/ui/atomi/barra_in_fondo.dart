import 'package:flutter/material.dart';

/// Una barra in fondo allo schermo (il Dock, la barra delle cose scelte, quella sotto la nota o la
/// trascrizione): i suggerimenti dei suoi tasti, tenendoli premuti, escono sopra, non sotto il dito.
/// La regola sta solo qui: le barre in alto restano come vuole Flutter (sotto).
class BarraInFondo extends StatelessWidget {
  const BarraInFondo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TooltipTheme(
    data: TooltipTheme.of(context).copyWith(preferBelow: false),
    child: child,
  );
}
