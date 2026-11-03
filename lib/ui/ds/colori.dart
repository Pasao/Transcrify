import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

/// Il design system di Transcrify, lo stesso di Figma (B2 «I token scelti», B3 «Caratteri, spazi, raggi…»).
///
/// I colori vengono dal colore scelto nel telefono, con lo stile «Fidelity» di Android (tiene il colore com'è).
/// La FONTE UNICA è nel Kotlin (Token.kt): la usano anche la pillola e il widget; l'app la riceve da lì.
/// La faccia (caratteri, forme, spazi, movimento) è nostra. Ogni nome qui è un token di Figma, con lo stesso nome.
class Colori extends ThemeExtension<Colori> {
  const Colori({
    required this.pagina,
    required this.scheda,
    required this.isola,
    required this.testo,
    required this.testoSecondario,
    required this.linea,
    required this.azione,
    required this.suAzione,
    required this.azioneTenue,
    required this.suAzioneTenue,
    required this.successo,
    required this.successoTenue,
    required this.attenzione,
    required this.attenzioneTenue,
    required this.errore,
    required this.erroreTenue,
    required this.argomenti,
    required this.transcriA,
    required this.transcriB,
    required this.floater,
    required this.suFloater,
  });

  /// fondi/: la pagina, le schede sopra la pagina, le isole (Dock, gruppi) che stanno sopra tutto.
  final Color pagina, scheda, isola;

  /// testo/: il testo, quello secondario (anche i suggerimenti nei campi), la linea che separa.
  final Color testo, testoSecondario, linea;

  /// azione/: il colore del telefono, pieno e tenue, e cosa ci va sopra.
  final Color azione, suAzione, azioneTenue, suAzioneTenue;

  /// stati/: avvicinati al telefono, ma fuori dalla striscia dell'arancione di Transcri.
  final Color successo, successoTenue, attenzione, attenzioneTenue, errore, erroreTenue;

  /// argomenti/: sei tinte per gli argomenti (l'arancione è escluso: è di Transcri).
  final List<Color> argomenti;

  /// transcri/: i due toni di Transcri, e il fondo scuro di tutto ciò che sta sospeso (Floater, barre, Annulla).
  final Color transcriA, transcriB, floater, suFloater;

  /// Il gradiente di Transcri, dall'alto in basso.
  LinearGradient get gradienteTranscri => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [transcriA, transcriB]);

  static const _nomi = [
    'pagina',
    'scheda',
    'isola',
    'testo',
    'testoSecondario',
    'linea',
    'azione',
    'suAzione',
    'azioneTenue',
    'suAzioneTenue',
    'successo',
    'successoTenue',
    'attenzione',
    'attenzioneTenue',
    'errore',
    'erroreTenue',
    'transcriA',
    'transcriB',
    'floater',
    'suFloater',
  ];

  /// I token che arrivano dal Kotlin (Token.mappa): nome → colore.
  factory Colori.daMappa(Map m) {
    Color c(String k) => Color(m[k] as int);
    assert(_nomi.every(m.containsKey));
    return Colori(
      pagina: c('pagina'),
      scheda: c('scheda'),
      isola: c('isola'),
      testo: c('testo'),
      testoSecondario: c('testoSecondario'),
      linea: c('linea'),
      azione: c('azione'),
      suAzione: c('suAzione'),
      azioneTenue: c('azioneTenue'),
      suAzioneTenue: c('suAzioneTenue'),
      successo: c('successo'),
      successoTenue: c('successoTenue'),
      attenzione: c('attenzione'),
      attenzioneTenue: c('attenzioneTenue'),
      errore: c('errore'),
      erroreTenue: c('erroreTenue'),
      transcriA: c('transcriA'),
      transcriB: c('transcriB'),
      floater: c('floater'),
      suFloater: c('suFloater'),
      argomenti: [for (final a in m['argomenti'] as List) Color(a as int)],
    );
  }

  /// Finché il telefono non risponde (il primo istante): i valori del salmone su cui è nato il design system,
  /// copiati dal Kotlin. Non si calcolano qui: la fonte è una sola.
  static const _salmoneChiaro = Colori(
    pagina: Color(0xFFFFF8F6),
    scheda: Color(0xFFFBEAE7),
    isola: Color(0xFFFFFFFF),
    testo: Color(0xFF221A18),
    testoSecondario: Color(0xFF54433F),
    linea: Color(0xFFDAC1BC),
    azione: Color(0xFF954739),
    suAzione: Color(0xFFFFFFFF),
    azioneTenue: Color(0xFFF1917F),
    suAzioneTenue: Color(0xFF6D291D),
    successo: Color(0xFF256C14),
    successoTenue: Color(0xFFA8F68D),
    attenzione: Color(0xFF8A5100),
    attenzioneTenue: Color(0xFFFFDCBD),
    errore: Color(0xFFB7220C),
    erroreTenue: Color(0xFFFFDAD4),
    transcriA: Color(0xFFFFA582),
    transcriB: Color(0xFFE87545),
    floater: Color(0xFF221A18),
    suFloater: Color(0xFFEFDFDC),
    argomenti: [Color(0xFFFFDADA), Color(0xFFF2DAFF), Color(0xFFBBF1A9), Color(0xFFD7E2FF), Color(0xFFFFDDB7), Color(0xFFA0F2D9)],
  );
  static const _salmoneScuro = Colori(
    pagina: Color(0xFF191210),
    scheda: Color(0xFF261E1C),
    isola: Color(0xFF3C3331),
    testo: Color(0xFFEFDFDC),
    testoSecondario: Color(0xFFDAC1BC),
    linea: Color(0xFF54433F),
    azione: Color(0xFFFFB4A6),
    suAzione: Color(0xFF5A1B10),
    azioneTenue: Color(0xFFF1917F),
    suAzioneTenue: Color(0xFF6D291D),
    successo: Color(0xFF8DD974),
    successoTenue: Color(0xFF0E5300),
    attenzione: Color(0xFFFFB86E),
    attenzioneTenue: Color(0xFF693C00),
    errore: Color(0xFFFFB4A6),
    erroreTenue: Color(0xFF900E00),
    transcriA: Color(0xFFFFA582),
    transcriB: Color(0xFFE87545),
    floater: Color(0xFF221A18),
    suFloater: Color(0xFFEFDFDC),
    argomenti: [Color(0xFF7D2A33), Color(0xFF5A3776), Color(0xFF23501B), Color(0xFF224680), Color(0xFF653E00), Color(0xFF005141)],
  );

  static Colori chiaro = _salmoneChiaro;
  static Colori scuro = _salmoneScuro;

  /// Cambia quando cambiano i colori del telefono: l'app si ridisegna (vedi main.dart).
  static final versione = ValueNotifier<int>(0);

  static void usa(Map tokenChiaro, Map tokenScuro) {
    final c = Colori.daMappa(tokenChiaro), s = Colori.daMappa(tokenScuro);
    if (c.azione == chiaro.azione && c.pagina == chiaro.pagina && s.azione == scuro.azione) return;
    chiaro = c;
    scuro = s;
    versione.value++;
  }

  /// I colori di adesso, per chi non ha un BuildContext (o finché un pezzo non è passato a [ColoriDi]).
  static Colori get adesso => PlatformDispatcher.instance.platformBrightness == Brightness.dark ? scuro : chiaro;

  @override
  Colori copyWith() => this;

  @override
  Colori lerp(Colori? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension ColoriDi on BuildContext {
  /// I token di colore: `context.col.azione`.
  Colori get col => Theme.of(this).extension<Colori>()!;
}
