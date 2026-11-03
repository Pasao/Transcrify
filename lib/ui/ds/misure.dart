import 'package:flutter/material.dart';

/// Spazi, raggi, misure fisse, movimento e ombre del design system (Figma B3), coi nomi di Figma.

/// spazio/: una griglia di 4. I numeri sono i nomi di Figma (spazio/1 = 4, spazio/10 = 40).
abstract final class Spazio {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s8 = 32.0, s10 = 40.0;
}

/// raggio/: sei raggi, uno per famiglia di cose.
abstract final class Raggio {
  static const piccolo = 4.0, campo = 12.0, scheda = 18.0, gruppo = 24.0, foglio = 28.0, pillola = 999.0;
}

/// icona/, tocco/, dock/, bottone/: le misure fisse.
abstract final class Misura {
  static const iconaPiccola = 16.0, iconaMedia = 20.0, iconaGrande = 24.0;
  static const tocco = 48.0;
  static const isola = 64.0, tondo = 52.0;
  static const bottoneAlto = 48.0, bottoneBasso = 40.0;
}

/// durata/ e curva/: il movimento dell'app (quello di Transcri è a parte, suo).
abstract final class Durata {
  static const veloce = Duration(milliseconds: 150);
  static const normale = Duration(milliseconds: 250);
  static const lenta = Duration(milliseconds: 400);

  /// Quanto resta un'etichetta sospesa (il nome del potere appena cambiato, la grana scelta).
  static const etichetta = Duration(milliseconds: 1200);

  /// Quanto resta la conferma di un gesto (la ✓ di «Copiato»).
  static const conferma = Duration(milliseconds: 1400);

  /// Quanto resta armato il cestino dopo il primo tocco.
  static const armato = Duration(milliseconds: 2200);

  /// Quanto resta «Annulla»: 2 secondi (sua scelta, 2 nov: prima erano 3).
  static const annulla = Duration(milliseconds: 2000);

  /// Un giro del blob al lavoro: Transcri che ondeggia piano.
  static const giroBlob = Duration(milliseconds: 2400);
}

abstract final class Curva {
  /// Parte svelta, arriva morbida: quasi tutto.
  static const standard = Curves.easeOutCubic;

  /// Arriva, supera appena e torna: le cose che «atterrano».
  static const rimbalzo = Curves.easeOutBack;

  /// Le cose che se ne vanno.
  static const uscita = Curves.easeIn;
}

/// Le due ombre: «appoggiato» (isole del Dock, gruppi) e «sospeso» (ciò che sta sopra tutto).
abstract final class Ombra {
  static const appoggiato = [
    BoxShadow(color: Color(0x17000000), offset: Offset(0, 4), blurRadius: 18),
    BoxShadow(color: Color(0x14000000), blurRadius: 1.5, spreadRadius: 0.5),
  ];
  static const sospeso = [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 8), blurRadius: 24),
    BoxShadow(color: Color(0x14000000), blurRadius: 1.5, spreadRadius: 0.5),
  ];
}
