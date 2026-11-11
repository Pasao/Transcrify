import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../ds.dart';
import 'bottone_icona.dart';

/// La parte di sopra di una scheda offuscata: copre il testo da bordo a bordo, con l'occhio chiuso al centro.
/// Finisce con un taglio dritto sopra la fascia in fondo, che resta visibile (Figma D2, «la privata»).
///
/// Sopra il fondo, macchie molto sfocate dei colori della scheda ([macchie]) che girano lentissime (6 nov, giro 6,
/// Figma D5 «macchie sfocate»: un giro in [Durata.giroPrivata], si vede appena). Restano dentro la copertura: la fascia
/// in fondo non le vede (6 nov, giro 7: «si vede il gradiente muoversi dietro»). Stanno ferme con «riduci le
/// animazioni», mentre la tocchi ([ferma]), quando sopra c'è un'altra pagina (la trascrizione aperta) e con l'app in
/// sottofondo.
class CoperturaPrivata extends StatefulWidget {
  const CoperturaPrivata({super.key, required this.fondo, this.macchie = const [], this.ferma = false, this.comparsa = 1});

  /// Quanto è arrivata (0..1, dal movimento di [Offuscabile]): le macchie si condensano dal grande e chiaro al loro posto.
  final double comparsa;

  /// La stessa copertura, arrivata di [quanto].
  CoperturaPrivata arrivata(double quanto) => CoperturaPrivata(fondo: fondo, macchie: macchie, ferma: ferma, comparsa: quanto);

  /// Senza un colore suo (le note, le trascrizioni senza colore): i grigi della pagina.
  factory CoperturaPrivata.neutra(BuildContext context, {bool ferma = false}) {
    final col = context.col;
    return CoperturaPrivata(fondo: col.linea, macchie: [col.scheda, col.pagina, col.testoSecondario.withValues(alpha: 0.3)], ferma: ferma);
  }

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
    label: Offusca.offuscata,
    // Le macchie sono più grandi della copertura: il taglio le tiene dentro, sopra la fascia.
    child: ClipRect(
      child: ColoredBox(
        color: widget.fondo,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.macchie.isNotEmpty) RepaintBoundary(child: CustomPaint(painter: _Macchie(widget.macchie, _moto, widget.comparsa))),
            Center(
              child: Icon(Offusca.icona, size: Misura.iconaGrande, color: context.col.testo),
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
  _Macchie(this.colori, this.giro, this.comparsa) : super(repaint: giro);

  final List<Color> colori;
  final Animation<double> giro;

  /// Quanto è arrivata la copertura: ogni macchia arriva un poco dopo la prima ([Velo.macchieDopo]).
  final double comparsa;

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
      final arrivo = Curva.standard.transform(((comparsa - i * Velo.macchieDopo) / (1 - (colori.length - 1) * Velo.macchieDopo)).clamp(0.0, 1.0));
      final raggio = lato * r * (Velo.macchieDa + (1 - Velo.macchieDa) * arrivo);
      final colore = colori[i];
      final c = colore.withValues(alpha: colore.a * (Velo.macchieChiare + (1 - Velo.macchieChiare) * arrivo));
      final sfuma = RadialGradient(colors: [c, c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: centro, radius: raggio));
      canvas.drawCircle(centro, raggio, Paint()..shader = sfuma);
    }
  }

  @override
  bool shouldRepaint(_Macchie prima) => !identical(prima.colori, colori) || prima.comparsa != comparsa;
}

/// Il testo di una scheda e la sua copertura (11 nov, suo: «troppo semplice»), lo stesso per le trascrizioni e per
/// le note. Offuscando il testo si sfoca piano piano (fino a [Velo.sfocatura]) e sbiadisce, mentre la copertura arriva
/// e le sue macchie si condensano al loro posto, una dopo l'altra; rimettendo in vista il contrario: le macchie si
/// sciolgono verso fuori, la sfocatura cala e il testo torna netto. In [durata] ([Durata.copre]), con [Curva.scambio].
/// La sfocatura c'è solo durante il movimento; il testo non si ridisegna a ogni fotogramma (è il figlio fisso).
/// [riempie]: la copertura e il testo prendono tutto lo spazio (le schede delle trascrizioni); se no il testo dà
/// l'altezza e la copertura la prende (le note).
class Offuscabile extends StatefulWidget {
  const Offuscabile({super.key, required this.coperta, required this.testo, required this.copertura, this.riempie = false, this.durata = Durata.copre});

  final bool coperta, riempie;
  final Widget testo;
  final CoperturaPrivata copertura;
  final Duration durata;

  @override
  State<Offuscabile> createState() => _OffuscabileState();
}

class _OffuscabileState extends State<Offuscabile> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: widget.durata, value: widget.coperta ? 1 : 0);

  @override
  void didUpdateWidget(covariant Offuscabile prima) {
    super.didUpdateWidget(prima);
    if (prima.coperta != widget.coperta) _t.animateTo(widget.coperta ? 1 : 0, curve: Curva.scambio);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.testo,
    builder: (context, testo) {
      final t = _t.value;
      // Il testo: netto, poi sfocato e sempre più tenue. Coperto del tutto non c'è più (con [riempie]); se dà lui
      // l'altezza (le note) tiene il posto, ma non si vede né si legge.
      final sotto = switch (t) {
        0 => testo!,
        1 when widget.riempie => const SizedBox.expand(),
        1 => ExcludeSemantics(child: Visibility.maintain(visible: false, child: testo!)),
        _ => ExcludeSemantics(
          excluding: widget.coperta,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: Velo.sfocatura * t, sigmaY: Velo.sfocatura * t),
            child: Opacity(opacity: 1 - t, child: testo),
          ),
        ),
      };
      // La copertura arriva un poco dopo che il testo ha cominciato a sfocarsi.
      final arrivo = ((t - Velo.macchieDopo) / (1 - Velo.macchieDopo)).clamp(0.0, 1.0);
      return Stack(
        fit: widget.riempie ? StackFit.expand : StackFit.loose,
        children: [
          sotto,
          if (t > 0) Positioned.fill(child: Opacity(opacity: Curva.standard.transform(arrivo), child: widget.copertura.arrivata(arrivo))),
        ],
      );
    },
  );
}

/// «Offusca» (7 nov, sua richiesta: non chiude niente a chiave, per ora copre soltanto, e si chiama così): i nomi e le
/// icone dell'azione, uguali sulle trascrizioni e sulle note, nel menu, nelle barre e nella scelta. Dentro il codice
/// il segno si chiama ancora `privata`.
abstract final class Offusca {
  static const icona = Icons.visibility_off_rounded, iconaMostra = Icons.visibility_rounded;

  /// Com'è una scheda coperta (per chi legge lo schermo).
  static const offuscata = 'Offuscata';

  /// L'azione che serve adesso: coperta → «Mostra», se no «Offusca».
  static (IconData, String) azione({required bool coperta}) => coperta ? (iconaMostra, 'Mostra') : (icona, 'Offusca');
}

/// Il tasto «Offusca» / «Mostra» nelle barre in fondo (trascrizione aperta, nota): l'icona di quello che fa adesso.
class BottoneOffusca extends StatelessWidget {
  const BottoneOffusca({super.key, required this.coperta, required this.onTap});

  final bool coperta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icona, nome) = Offusca.azione(coperta: coperta);
    return BottoneIcona(icona, etichetta: nome, onTap: onTap, misura: Misura.bottoneBasso);
  }
}
