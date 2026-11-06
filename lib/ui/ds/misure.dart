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
  /// Le isole (il Dock e le pillole dell'intestazione) e i tondi dentro di loro. 6 nov: «il Dock è troppo grande, più
  /// piccolo lascia più spazio» → 56 e 48 (prima 64 e 52); il tondo resta grande quanto un dito ([tocco]).
  static const isola = 56.0, tondo = tocco;
  static const bottoneAlto = 48.0, bottoneBasso = 40.0;

  /// Il cursore della voce: dove entrerà il dettato in una trascrizione aperta (Figma D2, riga 2).
  static const cursoreVoce = 3.0;

  /// Il contorno di una scheda scelta: spesso, nel colore del testo, si vede su ogni tinta e in tutti e due i temi.
  static const bordoScelta = 2.5;

  /// Il puntino della fila dei colori e della tavolozza (più piccolo di un'icona media).
  static const puntoPiccolo = 18.0;

  /// Il cerchio del colore in cima alla trascrizione aperta (6 nov, giro 6): il tondo, e l'anello sottile attorno
  /// (staccato di [anelloStacco]) che dice «si tocca, si cambia». Senza colore, lo stesso tondo tratteggiato col «+».
  static const cerchioColore = iconaGrande, anello = 1.5, anelloStacco = 3.0;

  /// Quanto è larga una scheda nel carosello del giorno; la fila dei colori è larga uguale (5 nov: «bello che sia
  /// grande quanto la card»).
  static const schedaLarga = 240.0;

  /// Quanto è larga, al massimo, la tavolozza che spunta sopra un controllo.
  static const tavolozza = 320.0;

  /// La rosa dei colori: quanto stanno lontani dal centro i due anelli di puntini. Sedici puntini fuori e otto dentro,
  /// ognuno col suo tocco ([bottoneBasso]) senza toccare il vicino.
  static const rosaDentro = 56.0, rosaFuori = 104.0;

  /// Il puntino della rosa sotto il dito che scorre (7 nov): più grande, si vede quale prendi lasciando; fermo, com'è.
  static const rosaSotto = 1.4, rosaFerma = 1.0;
}


/// scala/: di quanto si ingrandisce o rimpicciolisce una cosa per dire in che stato è.
abstract final class Scala {
  /// Una scheda scelta si stringe un poco (con la spunta e il contorno): si capisce anche tra tante.
  static const scelta = 0.95;

  /// La scheda unita, all'arrivo: un battito e torna com'era.
  static const battito = 1.05;

  /// Da dove parte un fumetto (la scelta del colore, i colori dell'unione) quando spunta.
  static const spunta = 0.85;
}

/// velo/: quanto si spengono le cose dietro (o accanto) a quella che conta.
abstract final class Velo {
  /// Le schede non scelte mentre se ne scelgono alcune: si spengono e perdono il colore ([spento]), così la scelta si
  /// stacca anche quando sono tutte dello stesso marrone (5 nov).
  static const nonScelta = 0.45;

  /// I segni della formattazione (`**`, `*`) mentre scrivi: restano, perché sono testo, ma si vedono appena (6 nov).
  static const segni = 0.35;

  /// Il colore che se ne va (grigio, con i pesi della luminosità): le schede non scelte. [quanto] da 0 (a colori) a 1
  /// (grigio): così il grigio arriva piano, insieme al velo, invece di scattare.
  static ColorFilter spento(double quanto) {
    const grigio = [0.2126, 0.7152, 0.0722];
    return ColorFilter.matrix(<double>[
      for (var riga = 0; riga < 3; riga++) ...[
        for (var col = 0; col < 3; col++) (col == riga ? 1 - quanto : 0) + grigio[col] * quanto,
        0,
        0,
      ],
      0, 0, 0, 1, 0, //
    ]);
  }
}

/// durata/ e curva/: il movimento dell'app (quello di Transcri è a parte, suo).
abstract final class Durata {
  static const veloce = Duration(milliseconds: 150);
  static const normale = Duration(milliseconds: 250);
  static const lenta = Duration(milliseconds: 400);

  /// La rosa dei colori che si apre (e si chiude): i due anelli arrivano insieme (vedi [Curva.rosaFuoriApre]).
  static const rosa = lenta;

  /// Tutto quello che cambia scegliendo (6 nov: «si devono muovere uguali»): il velo e il grigio delle altre, la scelta
  /// che si stringe, il contorno, l'ombra, la spunta, la barra che prende il posto del Dock. Con `Curva.standard`.
  static const scelta = normale;

  /// Quanto resta un'etichetta sospesa (il nome del potere appena cambiato, la grana scelta).
  static const etichetta = Duration(milliseconds: 1200);

  /// Quanto resta la conferma di un gesto (la ✓ di «Copiato»).
  static const conferma = Duration(milliseconds: 1400);

  /// Quanto resta armato il cestino dopo il primo tocco.
  static const armato = Duration(milliseconds: 2200);

  /// Quanto resta «Annulla»: 2 secondi (sua scelta, 2 nov: prima erano 3).
  static const annulla = Duration(milliseconds: 2000);

  /// «Annulla» dopo un'unione: di più, perché l'unione cambia più cose di un'eliminazione e si capisce
  /// solo guardando il risultato (5 nov: «non ho fatto in tempo ad annullare»).
  static const annullaUnione = Duration(milliseconds: 4000);

  /// Unendo: le schede volano sulla prima, una dopo l'altra (in tutto), poi la scheda unita fa un battito.
  /// «Annulla» lo stesso al contrario: la scheda unita torna al posto della prima e le altre ne escono.
  static const voloUnione = Duration(milliseconds: 520);
  static const battito = Duration(milliseconds: 360);

  /// Un giro del blob al lavoro: Transcri che ondeggia piano.
  static const giroBlob = Duration(milliseconds: 2400);

  /// Un giro delle macchie sfocate sulla copertura di una privata (6 nov, giro 6): lentissimo, si vede appena.
  static const giroPrivata = Duration(milliseconds: 7000);
}

abstract final class Curva {
  /// Parte svelta, arriva morbida: quasi tutto.
  static const standard = Curves.easeOutCubic;

  /// Arriva, supera appena e torna: le cose che «atterrano».
  static const rimbalzo = Curves.easeOutBack;

  /// Le cose che se ne vanno.
  static const uscita = Curves.easeIn;

  /// Le cose che passano da un posto all'altro restando in vista (il fondo della pagina scelta nel Dock, un pezzo che
  /// esce e rientra): parte piano e arriva piano.
  static const scambio = Curves.easeInOutCubic;

  /// La rosa dei colori (6 nov, sua idea): due strati che si muovono insieme. Aprendo, l'anello di dentro esce per
  /// primo e va piano ([standard] su tutto il tempo); quello di fuori parte da sotto di lui un poco dopo
  /// ([rosaRitardo] del tempo) e va più svelto: arrivano alle loro distanze nello stesso momento. Chiudendo al
  /// contrario: quello di fuori aspetta, poi rientra più svelto, e arrivano al centro insieme.
  static const rosaRitardo = 0.3;
  static const rosaFuoriApre = Interval(rosaRitardo, 1, curve: standard);
  static const rosaFuoriChiude = Interval(0, 1 - rosaRitardo, curve: uscita);
}

/// Le due ombre: «appoggiato» (isole del Dock, gruppi, la scheda scelta) e «sospeso» (ciò che sta sopra tutto).
abstract final class Ombra {
  /// La tinta delle ombre, in un posto solo: un marrone scuro e caldo come la carta e il Floater, non il nero
  /// (5 nov: un'ombra nera sulle schede colorate sembra sporca). Le ombre ne cambiano solo la trasparenza.
  static const _tinta = 0x3A2418;

  static const appoggiato = [
    BoxShadow(color: Color(0x17000000 | _tinta), offset: Offset(0, 4), blurRadius: 18),
    BoxShadow(color: Color(0x14000000 | _tinta), blurRadius: 1.5, spreadRadius: 0.5),
  ];
  static const sospeso = [
    BoxShadow(color: Color(0x2E000000 | _tinta), offset: Offset(0, 8), blurRadius: 24),
    BoxShadow(color: Color(0x14000000 | _tinta), blurRadius: 1.5, spreadRadius: 0.5),
  ];

  /// L'incavo: il nido vuoto quando Transcri è fuori (6 nov, giro 7: «lo spazio vuoto non si vede, anche coi colori
  /// scuri»). Un pozzetto più scuro dell'isola su cui sta, più fondo in alto (dove la luce non arriva) che verso il
  /// basso; di notte, in fondo, un filo di luce sul bordo di sotto, come lo spigolo che la prende. Niente contorno. Nero,
  /// non la tinta: è un vuoto, non un'ombra appoggiata. `lettura_grana_test` misura che stacchi dall'isola.
  static LinearGradient incavo(Brightness luce) => luce == Brightness.dark ? _incavoScuro : _incavoChiaro;

  static const _incavoChiaro = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x29000000), Color(0x14000000), Color(0x0A000000)],
    stops: [0, 0.6, 1],
  );
  static const _incavoScuro = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x80000000), Color(0x59000000), Color(0x1FFFFFFF)],
    stops: [0, 0.8, 1],
  );
}
