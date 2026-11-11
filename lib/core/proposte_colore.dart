import 'package:flutter/foundation.dart';

import 'native.dart';

/// Un colore proposto da «Colora da sola» per una trascrizione senza colore.
typedef PropostaColore = ({DateTime at, Colore colore});

/// «Colora da sola» propone, non cambia (10 nov, sua richiesta: «suggerimenti, non cambi silenziosi»). Le proposte le
/// calcola e le tiene il nativo (`proposteColore`, con la regola rigida delle etichette); qui si leggono e si decidono:
/// accettata prende il colore (e, se l'etichetta offusca sempre, diventa privata), rifiutata non torna più.
abstract final class ProposteColore {
  /// Le proposte di adesso, nell'ordine in cui le manda il nativo.
  static final tutte = ValueNotifier<List<PropostaColore>>(const []);

  /// Le proposte che riguardano trascrizioni che ci sono ancora (tra [voci]), con la loro trascrizione.
  static List<(PropostaColore, Entry)> con(List<Entry> voci) {
    final perAt = {for (final e in voci) e.at: e};
    return [
      for (final p in tutte.value)
        if (perAt[p.at] case final e?) (p, e),
    ];
  }

  /// Quelle finte (Impostazioni → Prove, 11 nov): per vedere la pagina «Da sistemare» piena. Solo coi dati finti, e
  /// non vanno mai al nativo (accettate o rifiutate escono e basta).
  static List<PropostaColore> _finte = const [];

  /// Tre proposte finte sulle prime trascrizioni senza colore (dei dati finti), o via.
  static Future<void> mostraFinte(bool on) async {
    final voci = on ? await Core.history() : const <Entry>[];
    const tinte = [2, 7, 11];
    _finte = [
      for (final (i, e) in voci.where((e) => e.colore == null && !e.privata).take(tinte.length).indexed) (at: e.at, colore: Colore(tinte[i], 4)),
    ];
    await leggi();
  }

  static Future<void> leggi() async {
    final l = await Core.chiedi('proposteColore');
    tutte.value = [
      if (l is List)
        for (final m in l)
          if (m is Map && m['at'] is num)
            if (Colore.da(m['colore'] as String?) case final c?) (at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt()), colore: c),
      ..._finte,
    ];
  }

  static Future<void> accetta(DateTime at) => _decidi('accettaProposta', at);

  static Future<void> rifiuta(DateTime at) => _decidi('rifiutaProposta', at);

  static Future<void> accettaTutte() => _decidi('accettaTutte', null);

  /// «Scarta tutte» (11 nov): come rifiutarle una per una, non tornano.
  static Future<void> rifiutaTutte() => _decidi('rifiutaTutte', null);

  /// Esce subito dalla lista (la scelta si vede al tocco), poi il nativo la applica e le schede si rileggono.
  static Future<void> _decidi(String metodo, DateTime? at) async {
    tutte.value = [
      if (at != null)
        for (final p in tutte.value)
          if (p.at != at) p,
    ];
    final finta = _finte.any((p) => p.at == at);
    _finte = [
      if (at != null)
        for (final p in _finte)
          if (p.at != at) p,
    ];
    if (finta) return;
    await Core.chiedi(metodo, {if (at != null) 'at': at.millisecondsSinceEpoch});
    Core.refresh();
  }
}
