import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../ds.dart';

/// La pillola sul bordo dello schermo, come quella del Floater: una capsula in piedi coi due toni di Transcri. Mentre
/// ascolta si allarga un poco con la voce ([Core.live]). La prova dell'introduzione la mostra quando Transcri va di
/// lato (10 nov: «diventa la pillola, non un Transcri piccolo»).
class PillolaBordo extends StatelessWidget {
  const PillolaBordo({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return ValueListenableBuilder<Live>(
      valueListenable: Core.live,
      builder: (context, live, _) => AnimatedContainer(
        duration: Durata.veloce,
        width: Misura.pillolaLarga + (live.listening ? live.level.clamp(0.0, 1.0) * Misura.pillolaVoce : 0),
        height: Misura.pillolaAlta,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Raggio.pillola),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.transcriA, c.transcriB]),
          boxShadow: Ombra.sospeso,
        ),
      ),
    );
  }
}
