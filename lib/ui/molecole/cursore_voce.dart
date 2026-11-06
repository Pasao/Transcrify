import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi/punto_nel_campo.dart';
import '../ds.dart';
import 'voce_in_barra.dart';

/// Mentre detti in una trascrizione aperta (Figma D2, riga 2): un cursore arancione (azione, 3 px) nel testo, dove
/// entrerà la voce. Senza tastiera il campo non ha il suo cursore, quindi si disegna sopra, nel punto [punto] del
/// testo (-1 = in fondo), misurato dal campo stesso: segue il testo che arriva e che va a capo.
/// Intanto il testo non si tocca: un tocco sposterebbe il punto mentre la voce entra in quello di prima.
class CursoreVoce extends StatefulWidget {
  const CursoreVoce({super.key, required this.at, required this.testo, required this.punto, required this.child});

  /// La trascrizione aperta: il cursore c'è solo se Transcri sta dettando per lei.
  final DateTime at;
  final TextEditingController testo;
  final int Function() punto;

  /// Il campo del testo.
  final Widget child;

  @override
  State<CursoreVoce> createState() => _CursoreVoceState();
}

class _CursoreVoceState extends State<CursoreVoce> {
  final _campo = GlobalKey();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Live>(
    valueListenable: Core.live,
    builder: (context, live, campo) {
      final acceso = VoceInBarra.dettaIn(live, widget.at);
      // Il campo resta sempre il primo figlio: comparendo il cursore non si ricostruisce (né perde il testo).
      return Stack(
        children: [
          IgnorePointer(key: _campo, ignoring: acceso, child: campo),
          if (acceso)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Cursore(campo: _campo, testo: widget.testo, punto: widget.punto, colore: context.col.azione),
                ),
              ),
            ),
        ],
      );
    },
    child: widget.child,
  );
}

class _Cursore extends CustomPainter {
  _Cursore({required this.campo, required this.testo, required this.punto, required this.colore}) : super(repaint: testo);

  final GlobalKey campo;
  final TextEditingController testo;
  final int Function() punto;
  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final dove = PuntoNelCampo.cursore(campo, punto());
    if (dove == null) return;
    final tratto = Rect.fromLTWH(dove.left, dove.top, Misura.cursoreVoce, dove.height);
    canvas.drawRRect(RRect.fromRectAndRadius(tratto, const Radius.circular(Misura.cursoreVoce / 2)), Paint()..color = colore);
  }

  @override
  bool shouldRepaint(_Cursore old) => old.colore != colore || old.testo != testo;
}
