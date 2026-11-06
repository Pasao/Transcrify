import 'dart:async';

import 'package:flutter/foundation.dart';

import 'estratto.dart';
import 'native.dart';

/// I titoli delle trascrizioni (6 nov, sua idea: sulla scheda, in fondo, il titolo). Si salvano nel nativo con la
/// trascrizione (`Entry.titolo`); le trascrizioni di prima non ne hanno.
///
/// Senza titolo l'app ne propone uno da sola, quando la scheda si vede ([proponi]): il riassunto estrattivo sul
/// telefono (`Estratto`) sceglie le frasi che contano, e il titolo è la più corta, tagliata a [parole] parole. Si fa una
/// alla volta, in fondo, e si salva: la prossima volta c'è già. Senza modello resta l'inizio del testo ([di]).
abstract final class Titoli {
  /// I titoli si vedono e si propongono da soli solo dalle prove («Titoli automatici», 6 nov, giro 7: «così sono
  /// inutili»; finché non decide se farli con l'AI o toglierli). Spento: la scheda ha una riga sola, la trascrizione
  /// aperta niente titolo. Il titolo salvato resta. Vive finché l'app è aperta, come le altre prove.
  static final automatici = ValueNotifier<bool>(false);

  /// Quante parole al massimo in un titolo proposto (e nell'inizio del testo che ne fa le veci).
  static const parole = 5;

  /// Quello che si vede: il suo titolo; senza, l'inizio del testo. Una privata senza titolo dice solo «Privata»: il suo
  /// testo non si legge, nemmeno l'inizio.
  static String di(Entry e) => e.titolo ?? (e.privata ? 'Privata' : taglia(e.text));

  /// Le prime [parole] parole di [testo], su una riga: senza i segni della formattazione né la punteggiatura in fondo.
  static String taglia(String testo) {
    final tutte = testo.replaceAll('*', '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return tutte.take(parole).join(' ').replaceFirst(RegExp(r'[\s.,;:!?…\-–—]+$'), '');
  }

  /// Il titolo dalle frasi scelte dal riassunto: la più corta, tagliata, con la maiuscola. Null se non ce n'è nessuna.
  static String? daFrasi(Iterable<String> frasi) {
    final buone = [
      for (final f in frasi)
        if (taglia(f) case final t when t.isNotEmpty) (frase: f.trim(), titolo: t),
    ]..sort((a, b) => a.frase.length.compareTo(b.frase.length));
    if (buone.isEmpty) return null;
    final t = buone.first.titolo;
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Le trascrizioni per cui si è già provato (in questa sessione): una volta sola ciascuna.
  static final _provate = <DateTime>{};

  /// Il riassunto ha detto che non c'è un modello: fino al prossimo avvio non si chiede più.
  static bool _senzaModello = false;

  /// Una alla volta: la prossima parte quando la prima ha finito.
  static Future<void> _coda = Future.value();
  static int _inCoda = 0, _scritti = 0;

  /// Se [e] non ha un titolo, ne propone uno in fondo, e lo salva. Le private no: il titolo si vede sulla scheda.
  /// Finita la fila, chi mostra le trascrizioni rilegge una volta sola.
  static void proponi(Entry e) {
    if (!automatici.value || e.titolo != null || e.privata || _senzaModello || Core.preview.value || !_provate.add(e.at)) return;
    _inCoda++;
    _coda = _coda.then((_) => _proponi(e)).whenComplete(() {
      if (--_inCoda > 0 || _scritti == 0) return;
      _scritti = 0;
      Core.refresh();
    });
  }

  static Future<void> _proponi(Entry e) async {
    if (_senzaModello) return;
    try {
      final r = await Estratto.di(e.text);
      if (r.stato == 'senzaModello') {
        _senzaModello = true;
        return;
      }
      final t = daFrasi([for (final f in r.frasi) f.testo]);
      if (t == null) return;
      await Segni.intitola(e.at, t);
      _scritti++;
    } catch (_) {
      // Il riassunto non è riuscito: resta l'inizio del testo, si riproverà al prossimo avvio.
    }
  }

  /// Per le prove: si ricomincia da capo.
  @visibleForTesting
  static void dimentica() {
    _provate.clear();
    _senzaModello = false;
  }
}
