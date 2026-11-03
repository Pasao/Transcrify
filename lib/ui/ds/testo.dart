import 'package:flutter/material.dart';

/// I dieci stili di testo di Figma («Transcrify/…»). Il colore lo mette chi li usa (di base: testo).
abstract final class Testo {
  /// I tre caratteri: titoli, testo, orari e codici.
  static const fontTitoli = 'Bricolage Grotesque', fontTesto = 'Inter', fontMono = 'DM Mono';

  static TextStyle _titolo(double size, double altezza, double spaziatura) => TextStyle(
    fontFamily: fontTitoli,
    fontSize: size,
    height: altezza,
    letterSpacing: spaziatura * size,
    fontWeight: FontWeight.w600,
    fontVariations: [const FontVariation('wght', 600), FontVariation('opsz', size)],
  );

  /// 40 · l'introduzione e le pagine vuote importanti.
  static final grande = _titolo(40, 1.05, -0.04);

  /// 28 · Trascrivi, Pensieri, Impostazioni… (grande in cima, si rimpicciolisce scorrendo).
  static final titoloPagina = _titolo(28, 1.05, -0.04);

  /// 22 · il giorno («Oggi»), i fogli dal basso, le sottopagine.
  static final titoloSezione = _titolo(22, 1.1, -0.03);

  /// 15 · il titolo di una nota, di una riga delle impostazioni.
  static const titoloScheda = TextStyle(fontFamily: fontTesto, fontSize: 15, height: 1.3, fontWeight: FontWeight.w600);

  /// 16 · leggere: una nota aperta, una trascrizione aperta.
  static const testoGrande = TextStyle(fontFamily: fontTesto, fontSize: 16, height: 1.45);

  /// 14 · il testo delle schede e dei paragrafi.
  static const testo = TextStyle(fontFamily: fontTesto, fontSize: 14, height: 1.45);

  /// 13 · bottoni piccoli, chip, voci dei menu.
  static const etichetta = TextStyle(fontFamily: fontTesto, fontSize: 13, height: 1.2, fontWeight: FontWeight.w600);

  /// 12 · sottotitoli, spiegazioni sotto una riga.
  static const piccolo = TextStyle(fontFamily: fontTesto, fontSize: 12, height: 1.4);

  /// 11 · orari, date corte, conteggi, codici.
  static const orario = TextStyle(fontFamily: fontMono, fontSize: 11, height: 1.3, letterSpacing: 0.2);

  /// 11 maiuscolo · l'etichetta sopra un gruppo (il testo va passato già in maiuscolo).
  static const gruppo = TextStyle(fontFamily: fontTesto, fontSize: 11, height: 1.2, letterSpacing: 1.4, fontWeight: FontWeight.w600);
}
