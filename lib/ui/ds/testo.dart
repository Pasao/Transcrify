import 'package:flutter/material.dart';

/// Gli undici stili di testo (i dieci di Figma «Transcrify/…» e il titolo nella pillola), più i due per leggere ([lettura],
/// [letturaScheda]). Il colore lo mette chi li usa (di base: testo).
abstract final class Testo {
  /// I due caratteri: titoli e testo. Gli orari e i conteggi sono nel carattere del testo, con le cifre tabellari
  /// (6 nov: gli zeri di DM Mono non gli piacevano; tolto).
  static const fontTitoli = 'Bricolage Grotesque', fontTesto = 'Inter';

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

  /// 24 · i titoli grandi dentro una pagina (un album, la prova dell'introduzione). Il titolo della pagina in cima ha
  /// la misura di [titoloPillola], ferma e scorrendo (10 nov; prima 24 ferma, e prima ancora 28).
  static final titoloPagina = _titolo(24, 1.05, -0.04);

  /// 18 · lo stesso titolo dentro la sua pillola, scorrendo: in proporzione alle isole del Dock, alte uguali
  /// (6 nov: «la pillola in alto sembra troppo grande rispetto a quelle in basso»; prima 22).
  static final titoloPillola = _titolo(18, 1.1, -0.03);

  /// 22 · il giorno («Oggi»), i fogli dal basso, le sottopagine.
  static final titoloSezione = _titolo(22, 1.1, -0.03);

  /// 15 · il titolo di una nota, di una riga delle impostazioni.
  static const titoloScheda = TextStyle(fontFamily: fontTesto, fontSize: 15, height: 1.3, fontWeight: FontWeight.w600);

  /// 16 · le frasi grandi dell'interfaccia (una pagina vuota, l'introduzione). Il testo da leggere è [lettura].
  static const testoGrande = TextStyle(fontFamily: fontTesto, fontSize: 16, height: 1.45);

  // --- Leggere: le trascrizioni e le note, il testo vero (6 nov: «15 su 24»; giro 7: Onest, Literata tolto) ---

  /// Il carattere per leggere (6 nov, giro 7: «preferisco Onest»). L'interfaccia resta in Inter.
  static const fontLettura = 'Onest';

  /// Lo spazio tra due paragrafi, cioè al posto di una riga vuota: 8 invece di una riga intera da 24.
  /// Solo dove il testo si legge e basta (le schede, il riassunto): nei campi dove scrivi la riga vuota resta intera,
  /// perché lì l'altezza delle righe è fissa (il «montante» del campo) e il cursore non deve saltare.
  static const spazioParagrafo = 8.0;

  /// La riga vuota tra due paragrafi, alta [spazioParagrafo] ([Formattato] la dà ai «a capo» che fanno una riga vuota).
  static const rigaVuota = TextStyle(fontSize: spazioParagrafo, height: 1);

  /// Un segno della formattazione (`**`, `*`) dove scrivi, lontano dal cursore: c'è ma non occupa posto né si vede.
  static const segnoNascosto = TextStyle(fontSize: 0.01, color: Color(0x00000000), letterSpacing: 0);

  static const _lettura = TextStyle(fontFamily: fontLettura, fontSize: 15, height: 1.6);
  static const _letturaScheda = TextStyle(fontFamily: fontLettura, fontSize: 14, height: 1.5);

  /// 15/24 · leggere: una trascrizione aperta, una nota mentre la scrivi, il riassunto. (Il [BuildContext] è rimasto
  /// da quando il carattere si sceglieva nelle prove: così chi lo chiama non cambia.)
  static TextStyle lettura(BuildContext context) => _lettura;

  /// 14/21 · l'inizio di una trascrizione o di una nota sulla sua scheda: lo stesso carattere, un passo più piccolo.
  static TextStyle letturaScheda(BuildContext context) => _letturaScheda;

  /// 14 · il testo delle schede e dei paragrafi.
  static const testo = TextStyle(fontFamily: fontTesto, fontSize: 14, height: 1.45);

  /// 13 · bottoni piccoli, chip, voci dei menu.
  static const etichetta = TextStyle(fontFamily: fontTesto, fontSize: 13, height: 1.2, fontWeight: FontWeight.w600);

  /// 12 · sottotitoli, spiegazioni sotto una riga.
  static const piccolo = TextStyle(fontFamily: fontTesto, fontSize: 12, height: 1.4);

  /// 11 · orari, date corte, conteggi, codici, il tempo che scorre: le cifre tutte larghe uguali (tabellari), così
  /// quando cambiano non ballano.
  static const orario = TextStyle(fontFamily: fontTesto, fontSize: 11, height: 1.3, fontFeatures: [FontFeature.tabularFigures()]);

  /// 11 maiuscolo · l'etichetta sopra un gruppo (il testo va passato già in maiuscolo).
  static const gruppo = TextStyle(fontFamily: fontTesto, fontSize: 11, height: 1.2, letterSpacing: 1.4, fontWeight: FontWeight.w600);
}
