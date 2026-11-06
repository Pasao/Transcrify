import 'package:flutter/foundation.dart';

/// Che cosa è un pezzo di testo formattato.
enum TipoPezzo { grassetto, corsivo, collegamento }

/// Un pezzo formattato: [inizio]–[fine] con i segni (`**ciao**`), [dentroInizio]–[dentroFine] senza (`ciao`).
/// Un collegamento scritto così com'è non ha segni (le due coppie coincidono); uno fatto col tasto «Link» sì
/// (`[parola](https://…)`: si vede solo «parola»). [uri] dice dove porta.
@immutable
class Pezzo {
  const Pezzo(this.tipo, this.inizio, this.fine, {required this.dentroInizio, required this.dentroFine, this.uri});

  final TipoPezzo tipo;
  final int inizio, fine, dentroInizio, dentroFine;
  final Uri? uri;

  /// Il cursore (o la selezione [da]–[a]) è dentro questo pezzo o gli sta attaccato: lì i segni si vedono.
  bool tocca(int da, int a) => da <= fine && a >= inizio;

  @override
  String toString() => '$tipo[$inizio,$fine)';
}

/// La formattazione dei testi (trascrizioni e note), come nei messaggi: **grassetto**, *corsivo*, [parole](link), e i link,
/// le e-mail e i numeri di telefono che si toccano. Si legge soltanto: il testo salvato resta quello scritto,
/// segni compresi. Le righe con «- » o «• » restano elenchi come sono.
abstract final class Formato {
  /// Delle parole che portano a un link: `[parole](https://…)`, quello che fa il tasto «Link» delle note.
  static final _conNome = RegExp(r'\[([^\]\n]+)\]\(((?:https?://|www\.)[^\s()]+)\)');

  /// Un link, un'e-mail o un numero di telefono (in quest'ordine: dentro un link non si cerca altro).
  static final _collegamento = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)' // un indirizzo
    r'|([\w.+-]+@[\w-]+(?:\.[\w-]+)+)' // un'e-mail
    r'|((?<![\w+])(?:\+\d{1,3}[\s-]?|0|3)\d(?:[\s-]?\d){6,11}(?![\w]))', // un telefono (italiano: +…, 0…, 3…)
  );

  /// Grassetto prima del corsivo: `**` non è un corsivo vuoto. Dentro, niente spazi ai bordi e niente a capo.
  static final _grassetto = RegExp(r'\*\*(?=\S)([^\n]+?)(?<=\S)\*\*');
  static final _corsivo = RegExp(r'(?<![\w*])\*(?=[^\s*])([^\n*]+?)(?<=[^\s*])\*(?![\w*])');

  /// La punteggiatura che chiude una frase non fa parte del link («vai su www.x.it.»).
  static final _coda = RegExp(r'[.,;:!?)\]»"”’]+$');

  /// I pezzi formattati di [testo], in ordine e senza sovrapporsi.
  static List<Pezzo> leggi(String testo) {
    final pezzi = <Pezzo>[];
    bool libero(int a, int b) => pezzi.every((p) => b <= p.inizio || a >= p.fine);

    for (final m in _conNome.allMatches(testo)) {
      final uri = indirizzo(m.group(2)!);
      if (uri == null) continue;
      pezzi.add(Pezzo(TipoPezzo.collegamento, m.start, m.end, dentroInizio: m.start + 1, dentroFine: m.start + 1 + m.group(1)!.length, uri: uri));
    }
    for (final m in _collegamento.allMatches(testo)) {
      if (!libero(m.start, m.end)) continue;
      var t = m.group(0)!;
      t = t.replaceFirst(_coda, '');
      final uri = m.group(1) != null
          ? indirizzo(t)
          : m.group(2) != null
          ? Uri(scheme: 'mailto', path: t)
          : Uri(scheme: 'tel', path: t.replaceAll(RegExp(r'[\s-]'), ''));
      if (uri == null || t.isEmpty) continue;
      final fine = m.start + t.length;
      pezzi.add(Pezzo(TipoPezzo.collegamento, m.start, fine, dentroInizio: m.start, dentroFine: fine, uri: uri));
    }
    for (final (rx, tipo) in [(_grassetto, TipoPezzo.grassetto), (_corsivo, TipoPezzo.corsivo)]) {
      for (final m in rx.allMatches(testo)) {
        if (!libero(m.start, m.end)) continue;
        final segno = tipo == TipoPezzo.grassetto ? 2 : 1;
        pezzi.add(Pezzo(tipo, m.start, m.end, dentroInizio: m.start + segno, dentroFine: m.end - segno));
      }
    }
    return pezzi..sort((a, b) => a.inizio.compareTo(b.inizio));
  }

  /// Un indirizzo web (con o senza «https://» davanti), o null se non lo è.
  static Uri? indirizzo(String t) {
    final s = t.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://') && !s.startsWith('www.') || s.contains(RegExp(r'\s'))) return null;
    return Uri.tryParse(s.startsWith('www.') ? 'https://$s' : s);
  }

  /// Il collegamento dove sta il cursore [punto] (dentro o subito dopo l'ultima lettera), se c'è.
  static Pezzo? collegamentoIn(String testo, int punto) {
    for (final p in leggi(testo)) {
      if (p.tipo == TipoPezzo.collegamento && p.inizio <= punto && punto <= p.fine) return p;
    }
    return null;
  }
}
