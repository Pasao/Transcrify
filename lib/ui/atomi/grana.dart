import 'package:flutter/material.dart';

import '../ds.dart';

/// La grana degli argomenti di una nota: spenta, poi dal largo al fine. Un posto solo per i nomi e per il giro del tocco.
/// (6 nov: da quattro grane a tre, tolta «Argomenti specifici».)
abstract final class Grana {
  static const spenta = 0, argomenti = 1, frasi = 2, parole = 3;

  /// La più fine.
  static const ultima = parole;

  /// Come si chiamano: quello che leggi tenendo il tasto, e per un attimo in alto quando cambia.
  static const nomi = ['Spento', 'Argomenti', 'Frasi', 'Parole chiave'];

  /// Il tocco: la grana dopo; dopo l'ultima si spegne.
  static int dopo(int livello) => livello >= ultima ? spenta : livello + 1;
}

/// La grana in un'icona: tre barre una sotto l'altra, dalla più lunga in alto (dal largo al fine).
/// Si accendono una dopo l'altra: Argomenti la prima, Frasi le prime due, Parole chiave tutte e tre; spenta, tutte leggere.
/// La luce arriva piano ([Durata.veloce]), non scatta.
class BarreGrana extends StatelessWidget {
  const BarreGrana({super.key, required this.livello, this.misura = Misura.iconaGrande, this.acceso, this.spento});

  final int livello;
  final double misura;

  /// Di base l'azione e il testo secondario; su un fondo scuro si passa il colore del Floater a tutti e due.
  final Color? acceso, spento;

  /// Quanto è lunga ogni barra, in proporzione al lato dell'icona: dalla prima (in alto) all'ultima.
  static const _lunghezze = [0.84, 0.6, 0.36];

  /// Lo spessore di una barra e lo spazio tra due, in proporzione al lato.
  static const _spessore = 0.13, _stacco = 0.15;

  /// Se la barra [i] (da 0, in alto) è accesa a questa grana.
  static bool accesa(int i, int livello) => i < livello;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final luce = acceso ?? c.azione;
    final base = spento ?? c.testoSecondario;
    final leggera = base.withValues(alpha: base.a * Velo.nonScelta);
    return SizedBox.square(
      dimension: misura,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: misura * _stacco,
        children: [
          for (final (i, l) in _lunghezze.indexed)
            AnimatedContainer(
              key: ValueKey('barra$i'),
              duration: Durata.veloce,
              curve: Curva.standard,
              width: misura * l,
              height: misura * _spessore,
              decoration: BoxDecoration(color: accesa(i, livello) ? luce : leggera, borderRadius: BorderRadius.circular(Raggio.pillola)),
            ),
        ],
      ),
    );
  }
}
