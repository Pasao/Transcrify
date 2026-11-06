import 'package:flutter/services.dart';

import 'formato.dart';

/// I ritocchi della barra delle note sul testo che scrivi: grassetto, corsivo, elenco, link. Ognuno prende il testo
/// con la selezione com'è e lo restituisce cambiato; toccato di nuovo dove c'è già, lo toglie. Il testo resta quello
/// scritto, coi segni di [Formato]: quello che si salva è quello che vedi in un altro posto qualsiasi.
abstract final class Scrittura {
  static const pallino = '• ';

  /// `**` (grassetto) o `*` (corsivo) attorno alla selezione. Il cursore dentro un pezzo così, o la selezione che lo
  /// copre: i segni vanno via. Il cursore fermo: i due segni, e lui in mezzo per scriverci dentro.
  static TextEditingValue segna(TextEditingValue v, TipoPezzo tipo) {
    final segno = tipo == TipoPezzo.grassetto ? '**' : '*';
    final sel = _sel(v);
    for (final p in Formato.leggi(v.text)) {
      if (p.tipo == tipo && p.dentroInizio <= sel.start && sel.end <= p.dentroFine) return _togli(v, p, sel);
    }
    if (sel.isCollapsed) return _metti(v, sel, segno, segno, '');
    // Gli spazi ai bordi restano fuori: «** ciao **» non è grassetto.
    final dentro = sel.textInside(v.text);
    final a = sel.start + (dentro.length - dentro.trimLeft().length), b = sel.end - (dentro.length - dentro.trimRight().length);
    if (a >= b) return v;
    return _metti(v, TextSelection(baseOffset: a, extentOffset: b), segno, segno, v.text.substring(a, b));
  }

  /// Le parole scelte diventano un link a [url] (`[parole](url)`); senza parole scelte, l'indirizzo così com'è.
  /// Senza indirizzo, le parentesi pronte e il cursore dentro, per incollarlo. Il cursore su un link fatto così:
  /// torna solo parole.
  static TextEditingValue collega(TextEditingValue v, Uri? url) {
    final sel = _sel(v);
    for (final p in Formato.leggi(v.text)) {
      if (p.tipo == TipoPezzo.collegamento && p.dentroInizio > p.inizio && p.tocca(sel.start, sel.end)) return _togli(v, p, sel);
    }
    final dentro = sel.textInside(v.text).trim();
    if (dentro.isEmpty) return url == null ? v : _metti(v, sel, '', '', '$url', cursoreInFondo: true);
    if (url == null) return _metti(v, sel, '[', ']()', dentro, cursoreInFondo: true, indietro: 1);
    return _metti(v, sel, '[', ']($url)', dentro, cursoreInFondo: true);
  }

  /// Il pallino all'inizio delle righe scelte (o di quella dove sei): se ce l'hanno già tutte, va via da tutte.
  static TextEditingValue elenco(TextEditingValue v) {
    final t = v.text, sel = _sel(v);
    final inizi = <int>[];
    for (var i = inizioRiga(t, sel.start); i <= sel.end; i = t.indexOf('\n', i) + 1) {
      inizi.add(i);
      if (t.indexOf('\n', i) < 0) break;
    }
    final togli = inizi.every((i) => t.startsWith(pallino, i));
    var nuovo = t;
    var base = sel.baseOffset, fine = sel.extentOffset;
    // Dal fondo, così le posizioni prima non si spostano.
    for (final i in inizi.reversed) {
      if (togli) {
        nuovo = nuovo.replaceRange(i, i + pallino.length, '');
      } else if (!nuovo.startsWith(pallino, i)) {
        nuovo = nuovo.replaceRange(i, i, pallino);
      } else {
        continue;
      }
      final d = togli ? -pallino.length : pallino.length;
      if (base >= i) base = (base + d).clamp(i, nuovo.length);
      if (fine >= i) fine = (fine + d).clamp(i, nuovo.length);
    }
    return TextEditingValue(text: nuovo, selection: TextSelection(baseOffset: base, extentOffset: fine));
  }

  /// Andando a capo dentro un elenco il pallino continua; su una riga vuota col pallino, l'elenco finisce.
  /// [prima] è il testo di un attimo fa; null se non c'è niente da fare.
  static TextEditingValue? continua(String prima, TextEditingValue v) {
    final now = v.text;
    if (now.length != prima.length + 1) return null;
    final c = v.selection.baseOffset;
    if (c < 1 || now[c - 1] != '\n') return null;
    final start = inizioRiga(now, c - 1);
    final riga = now.substring(start, c - 1);
    if (!riga.startsWith(pallino)) return null;
    if (riga == pallino) return TextEditingValue(text: now.replaceRange(start, c, ''), selection: TextSelection.collapsed(offset: start));
    return TextEditingValue(text: now.replaceRange(c, c, pallino), selection: TextSelection.collapsed(offset: c + pallino.length));
  }

  static int inizioRiga(String text, int at) => at <= 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;

  static TextSelection _sel(TextEditingValue v) => v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);

  /// [prima] e [dopo] attorno a [dentro], al posto della selezione [sel]. Poi scelto [dentro] (o il cursore in mezzo,
  /// se è vuoto; o in fondo, [indietro] lettere prima della fine).
  static TextEditingValue _metti(TextEditingValue v, TextSelection sel, String prima, String dopo, String dentro, {bool cursoreInFondo = false, int indietro = 0}) {
    final testo = v.text.replaceRange(sel.start, sel.end, '$prima$dentro$dopo');
    final a = sel.start + prima.length, fine = a + dentro.length + dopo.length - indietro;
    return TextEditingValue(
      text: testo,
      selection: cursoreInFondo ? TextSelection.collapsed(offset: fine) : TextSelection(baseOffset: a, extentOffset: a + dentro.length),
    );
  }

  /// Toglie i segni del pezzo [p]: resta scelto quello che c'era dentro.
  static TextEditingValue _togli(TextEditingValue v, Pezzo p, TextSelection sel) {
    final dentro = v.text.substring(p.dentroInizio, p.dentroFine);
    final testo = v.text.replaceRange(p.inizio, p.fine, dentro);
    final d = p.dentroInizio - p.inizio;
    int sposta(int x) => (x - d).clamp(p.inizio, p.inizio + dentro.length);
    return TextEditingValue(text: testo, selection: TextSelection(baseOffset: sposta(sel.start), extentOffset: sposta(sel.end)));
  }
}
