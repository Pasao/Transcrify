import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ds.dart';

/// La parte di sopra di una scheda privata: copre il testo da bordo a bordo, col lucchetto al centro.
/// Finisce con un taglio dritto sopra la fascia in fondo, che resta visibile (Figma D2, «la privata»).
///
/// Sopra il fondo, macchie molto sfocate dei colori della scheda ([macchie]) che girano lentissime (6 nov, giro 6,
/// Figma D5 «macchie sfocate»: un giro in [Durata.giroPrivata], si vede appena). Restano dentro la copertura: la fascia
/// in fondo non le vede (6 nov, giro 7: «si vede il gradiente muoversi dietro»). Stanno ferme con «riduci le
/// animazioni», mentre la tocchi ([ferma]), quando sopra c'è un'altra pagina (la trascrizione aperta) e con l'app in
/// sottofondo.
class CoperturaPrivata extends StatefulWidget {
  const CoperturaPrivata({super.key, required this.fondo, this.macchie = const [], this.ferma = false});

  /// Ferme: la scheda è premuta.
  final bool ferma;

  /// Una luce più scura del fondo della scheda (o un fondo neutro, se la scheda non ha colore).
  final Color fondo;

  /// I colori delle macchie (di solito tre); vuoto: solo il fondo.
  final List<Color> macchie;

  @override
  State<CoperturaPrivata> createState() => _CoperturaPrivataState();
}

class _CoperturaPrivataState extends State<CoperturaPrivata> with SingleTickerProviderStateMixin {
  late final _moto = AnimationController(vsync: this, duration: Durata.giroPrivata);

  /// L'app in primo piano: in sottofondo non gira niente.
  late final _vita = AppLifecycleListener(onStateChange: (_) => _muovi());

  /// Girano solo se si vedono e nessuno le tocca; si fermano dove sono e da lì ripartono.
  void _muovi() {
    final vita = WidgetsBinding.instance.lifecycleState;
    final si =
        !widget.ferma &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (vita == null || vita == AppLifecycleState.resumed);
    if (!si) {
      _moto.stop();
    } else if (!_moto.isAnimating) {
      _moto.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _vita;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _muovi();
  }

  @override
  void didUpdateWidget(covariant CoperturaPrivata prima) {
    super.didUpdateWidget(prima);
    if (prima.ferma != widget.ferma) _muovi();
  }

  @override
  void dispose() {
    _vita.dispose();
    _moto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Privata',
    // Le macchie sono più grandi della copertura: il taglio le tiene dentro, sopra la fascia.
    child: ClipRect(
      child: ColoredBox(
        color: widget.fondo,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.macchie.isNotEmpty) RepaintBoundary(child: CustomPaint(painter: _Macchie(widget.macchie, _moto))),
            Center(
              child: Icon(Icons.lock_rounded, size: Misura.iconaGrande, color: context.col.testo),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Le macchie: cerchi sfumati fino a sparire (un gradiente, non un filtro di sfocatura: costa poco anche su tante
/// schede), ognuna su un suo piccolo giro. Frequenze intere: alla fine del giro tornano esattamente dove erano.
class _Macchie extends CustomPainter {
  _Macchie(this.colori, this.giro) : super(repaint: giro);

  final List<Color> colori;
  final Animation<double> giro;

  /// Dove sta ogni macchia (in frazioni della copertura), quanto è grande (del lato più lungo) e da dove parte nel giro.
  static const _posti = [(0.2, 0.3, 0.75, 0.0), (0.8, 0.7, 0.7, 2.1), (0.55, 0.15, 0.55, 4.2)];

  /// Quanto si sposta una macchia nel suo giro: poco, perché si deve sentire più che vedere.
  static const _passo = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final a = giro.value * 2 * math.pi;
    final lato = math.max(size.width, size.height);
    for (var i = 0; i < colori.length; i++) {
      final (x, y, r, fase) = _posti[i % _posti.length];
      final centro = Offset(size.width * (x + _passo * math.cos(a + fase)), size.height * (y + _passo * 2 * math.sin(2 * a + fase)));
      final raggio = lato * r;
      final c = colori[i];
      final sfuma = RadialGradient(colors: [c, c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: centro, radius: raggio));
      canvas.drawCircle(centro, raggio, Paint()..shader = sfuma);
    }
  }

  @override
  bool shouldRepaint(_Macchie prima) => !identical(prima.colori, colori);
}
