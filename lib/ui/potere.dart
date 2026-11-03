import 'package:flutter/material.dart';

/// I poteri di Transcri. Per ora due: Trascrivi (quello che detti per gli altri) e Pensieri (le tue note).
enum Power {
  // Il microfono è il tasto per dettare, accanto a Transcri: il potere ha il suo segno, l'onda della voce.
  trascrivi('Trascrivi', Icons.graphic_eq_rounded),
  pensieri('Note', Icons.cloud_rounded);

  const Power(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Quello dopo (o prima), in giro: un tocco sul medaglione passa al prossimo.
  Power step(int by) => values[(index + by) % values.length];
}
