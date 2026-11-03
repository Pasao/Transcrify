import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';
import 'comandi_voce.dart';

/// La parte sinistra della barra in fondo alla trascrizione aperta (B6 «BarraTrascrizione»).
/// A riposo il microfono e «Aggiungi a voce» (il testo dettato entra dove sta il cursore); mentre detta qui, i ComandiVoce piccoli (gli stessi
/// del Floater) col tempo accanto. Cresce e si taglia: le icone a destra della barra non si spostano.
class VoceInBarra extends StatelessWidget {
  const VoceInBarra({super.key, required this.at, required this.onStart});

  /// La trascrizione aperta: la voce si aggiunge qui solo se Transcri sta dettando per lei.
  final DateTime at;
  final VoidCallback onStart;

  static String _tempo(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    Widget testo(String t, TextStyle s) => Flexible(
      child: Text(
        t,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: s.copyWith(color: c.testoSecondario),
      ),
    );
    return ValueListenableBuilder<Live>(
      valueListenable: Core.live,
      builder: (context, live, _) {
        final mio = live.appendTo == at.millisecondsSinceEpoch;
        if (mio && (live.listening || live.phase == 'PROCESSING')) {
          final fase = live.phase == 'PROCESSING' ? FaseVoce.lavora : (live.paused ? FaseVoce.pausa : FaseVoce.ascolta);
          return Row(
            spacing: Spazio.s2,
            children: [
              ComandiVoce(fase: fase, onButta: Core.discardListening, onFerma: Core.stopListening, onPausa: Core.togglePause),
              // Il tempo sopra e l'onda sotto, piccoli (sua richiesta): si vede che sta registrando. Lavorando, lo dice il blob.
              if (fase != FaseVoce.lavora)
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Spazio.s1,
                    children: [
                      testo(fase == FaseVoce.pausa ? 'in pausa' : _tempo(live.seconds), Testo.orario),
                      const OndaVoce(larga: Spazio.s8, alta: Spazio.s3),
                    ],
                  ),
                ),
            ],
          );
        }
        // Mentre detta altrove aspetta: Transcri fa una cosa alla volta.
        final occupato = live.listening || live.phase == 'PROCESSING';
        return Opacity(
          opacity: occupato ? 0.5 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(Raggio.pillola),
            onTap: occupato ? null : onStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spazio.s1, horizontal: Spazio.s1),
              child: Row(
                spacing: Spazio.s2,
                children: [
                  // Il microfono (sua scelta, 2 nov: non Transcri piccolo).
                  Icon(Icons.mic_none_rounded, size: Misura.iconaGrande, color: c.azione),
                  testo('Aggiungi a voce', Testo.etichetta),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
