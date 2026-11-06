import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';

/// Quello che c'è dentro una cartella: le trascrizioni più nuove (fino a tre) come fogli che sporgono dall'alto,
/// un po' sparsi, col loro inizio scritto piccolo. La più nuova sta davanti, a destra. Le private sono fogli bianchi:
/// il testo non si vede. Solo un disegno: per chi legge lo schermo conta il nome della cartella.
class FogliCartella extends StatelessWidget {
  const FogliCartella(this.voci, {super.key});

  /// Dalla più nuova; se ne disegnano al massimo [quanti].
  final List<Entry> voci;

  static const quanti = 3;

  /// Quanto è largo un foglio rispetto alla cartella, e come sta storto (radianti), dal più in fondo.
  static const _largo = 0.52;
  static const _storti = [-0.07, 0.03, -0.02];

  @override
  Widget build(BuildContext context) {
    final fogli = voci.take(quanti).toList().reversed.toList();
    if (fogli.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final largo = box.maxWidth * _largo;
          final corsa = box.maxWidth - Spazio.s3 * 2 - largo;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (i, e) in fogli.indexed)
                Positioned(
                  // Uno solo sta al centro; di più si spargono da sinistra a destra.
                  left: Spazio.s3 + (fogli.length == 1 ? corsa / 2 : corsa * i / (fogli.length - 1)),
                  top: Spazio.s1 * (fogli.length - 1 - i),
                  width: largo,
                  bottom: 0,
                  child: Transform.rotate(angle: _storti[(quanti - fogli.length + i) % quanti], child: _Foglio(e)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Foglio extends StatelessWidget {
  const _Foglio(this.voce);

  static const _righe = 2;

  final Entry voce;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.all(Spazio.s2),
      decoration: BoxDecoration(color: c.isola, borderRadius: BorderRadius.circular(Raggio.piccolo)),
      child: voce.privata
          ? null
          : Text(
              // Solo l'inizio: una dettatura lunga non si misura tutta.
              Anteprima.inizio(voce.text, _righe),
              maxLines: _righe,
              overflow: TextOverflow.clip,
              // Un disegno minuscolo dentro la cartella: non cresce col testo grande (il nome sì).
              textScaler: TextScaler.noScaling,
              style: Testo.orario.copyWith(color: c.testoSecondario),
            ),
    );
  }
}
