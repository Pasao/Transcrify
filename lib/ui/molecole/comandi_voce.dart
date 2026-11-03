import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atomi.dart';
import '../ds.dart';

/// Cosa sta facendo Transcri, per i suoi tasti.
enum FaseVoce { ascolta, pausa, lavora }

/// I tasti di Transcri, gli stessi del Floater (B6 «ComandiVoce»), qui nella misura piccola:
/// a sinistra butta, in mezzo il tasto della fase (✓ ferma e trascrivi; mentre lavora i suoi colori),
/// a destra pausa o riprendi.
class ComandiVoce extends StatelessWidget {
  const ComandiVoce({super.key, required this.fase, required this.onButta, required this.onFerma, required this.onPausa});

  final FaseVoce fase;
  final VoidCallback onButta, onFerma, onPausa;

  static const _lato = 32.0, _centro = Misura.bottoneBasso;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final lavora = fase == FaseVoce.lavora;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Spazio.s2,
      children: [
        // Mentre lavora i lati restano posti vuoti: i tasti non si spostano.
        if (lavora)
          const SizedBox.square(dimension: _lato)
        else
          BottoneIcona(Icons.delete_outline_rounded, tipo: TipoIcona.tenue, misura: _lato, etichetta: 'Butta', onTap: onButta),
        if (lavora)
          const BlobLavoro(lato: _centro)
        else
          Container(
            width: _centro,
            height: _centro,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.errore),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onFerma();
                },
                child: Icon(Icons.check_rounded, size: Misura.iconaMedia, color: c.suAzione),
              ),
            ),
          ),
        if (lavora)
          const SizedBox.square(dimension: _lato)
        else
          BottoneIcona(
            fase == FaseVoce.pausa ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tipo: TipoIcona.tenue,
            misura: _lato,
            etichetta: fase == FaseVoce.pausa ? 'Riprendi' : 'Pausa',
            onTap: onPausa,
          ),
      ],
    );
  }
}
