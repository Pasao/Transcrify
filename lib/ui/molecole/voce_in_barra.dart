import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';
import 'comandi_voce.dart';

/// La parte sinistra della barra in fondo alla trascrizione aperta (B6 «BarraTrascrizione»), l'area della voce.
/// A riposo il bottone tenue «Detta qui» col microfono (Figma D2, riga 2b: niente Transcri qui; il testo dettato
/// entra dove sta il cursore); mentre detta qui, i ComandiVoce piccoli (gli stessi del Floater) col tempo accanto.
/// Toccando «Detta qui» si registra subito; intanto la pillola sul bordo sparisce (la nasconde il nativo, `Dettatura.kt`:
/// sono due cose diverse) e torna a fine dettatura. Se il foglio si chiude a metà, torna subito (`Core.lasciaDettatura`).
/// Cresce e si taglia: le icone a destra della barra non si spostano.
class VoceInBarra extends StatefulWidget {
  const VoceInBarra({super.key, required this.at, required this.prepara, required this.punto});

  /// La trascrizione aperta: la voce si aggiunge qui solo se Transcri sta dettando per lei.
  final DateTime at;

  /// Prima di dettare: salva, chiede i permessi, chiude la tastiera. False = non si parte.
  final Future<bool> Function() prepara;

  /// Dove entrerà la voce nel testo (-1 = in fondo).
  final int Function() punto;

  /// Transcri sta dettando (o trascrivendo) per la trascrizione [at].
  static bool dettaIn(Live live, DateTime at) => live.appendTo == at.millisecondsSinceEpoch && (live.listening || live.phase == 'PROCESSING');

  /// Da quanto ascolta, «01:05». Lo usa anche la prova dell'introduzione.
  static String tempo(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  State<VoceInBarra> createState() => _VoceInBarraState();
}

class _VoceInBarraState extends State<VoceInBarra> {
  DateTime get at => widget.at;

  @override
  void dispose() {
    // Il foglio si chiude mentre detta qui: la pillola torna sul bordo, coi suoi comandi.
    if (VoceInBarra.dettaIn(Core.live.value, at)) Core.lasciaDettatura();
    super.dispose();
  }

  /// Il tocco su «Detta qui»: la registrazione parte subito (i comandi stanno nella barra, niente pannello del Floater).
  Future<void> _detta() async {
    if (!await widget.prepara() || !mounted) return;
    HapticFeedback.heavyImpact();
    Core.listen(appendTo: at, cursor: widget.punto());
  }

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
        if (VoceInBarra.dettaIn(live, at)) {
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
                      testo(fase == FaseVoce.pausa ? 'in pausa' : VoceInBarra.tempo(live.seconds), Testo.orario),
                      const OndaVoce(larga: Spazio.s8, alta: Spazio.s3),
                    ],
                  ),
                ),
            ],
          );
        }
        // Mentre detta altrove aspetta: Transcri fa una cosa alla volta.
        final occupato = live.listening || live.phase == 'PROCESSING';
        return Align(
          alignment: Alignment.centerLeft,
          child: Bottone('Detta qui', icona: Icons.mic_rounded, tipo: TipoBottone.tenue, alto: false, onPressed: occupato ? null : _detta),
        );
      },
    );
  }
}
