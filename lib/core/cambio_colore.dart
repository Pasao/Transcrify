import 'package:flutter/foundation.dart';

import 'segni.dart';

/// Un giro nella rosa dei colori (7 nov, sua richiesta: «se premo Annulla, quello che ho cambiato resta cambiato: non
/// lo voglio»). Ogni colore provato si salva subito, così le schede lo mostrano dal vivo ([prova]); ma questo pezzo
/// ricorda com'era ogni trascrizione prima ([prima]) e i nomi dei colori, e [rimetti] torna esattamente lì: ognuna col
/// SUO colore di prima (anche scegliendone tante di colori diversi), e i nomi come erano. Lo usano «Annulla» nella rosa
/// e l'«Annulla» della pillola, dopo.
class CambioColore {
  CambioColore(Map<DateTime, Colore?> prima, {this.nomeSegue = false})
    : prima = Map.unmodifiable(prima),
      ora = Map.of(prima),
      nomiPrima = Segni.nomi.value;

  /// Il colore di ogni trascrizione prima del giro.
  final Map<DateTime, Colore?> prima;

  /// Il colore di ogni trascrizione adesso (con quello provato).
  final Map<DateTime, Colore?> ora;

  /// Una cartella che cambia colore si porta dietro il nome (se il colore nuovo non ne ha già uno): cambia colore, non
  /// nome. Succede quando il giro finisce tenendo ([tieni]).
  final bool nomeSegue;

  /// I nomi dei colori prima del giro (chi l'ha aperta vede quali etichette hanno preso il nome adesso).
  final Map<String, String> nomiPrima;

  /// Il colore che hanno tutte adesso; null se non ne hanno o se sono diversi (vedi [misti]).
  Colore? get comune => ora.values.toSet().length == 1 ? ora.values.first : null;

  /// Hanno colori diversi (tante scelte, non ancora colorate insieme).
  bool get misti => ora.values.toSet().length > 1;

  /// Qualcosa è cambiato (un colore o un nome): solo allora serve l'«Annulla» dopo.
  bool get cambiato => !mapEquals(ora, prima) || !mapEquals(Segni.nomi.value, nomiPrima);

  /// Il colore [c] (null: nessuno) a tutte, salvato subito: si vede sulle schede.
  Future<void> prova(Colore? c) async {
    ora.updateAll((_, _) => c);
    await Segni.colora(ora.keys, c);
  }

  /// Il giro finisce tenendo: se [nomeSegue], il nome del colore di prima passa a quello nuovo.
  Future<void> tieni() async {
    final da = prima.values.toSet(), a = comune;
    if (!nomeSegue || da.length != 1 || a == null) return;
    final vecchio = da.single, nome = vecchio == null ? null : Segni.nomi.value[vecchio.chiave];
    if (nome == null || a == vecchio || Segni.nomi.value.containsKey(a.chiave)) return;
    await Segni.nomina(a, nome);
    await Segni.nomina(vecchio!, '');
  }

  /// Tutto com'era: ogni trascrizione col suo colore di prima (una scrittura per colore), e i nomi cambiati.
  Future<void> rimetti() async {
    final gruppi = <Colore?, List<DateTime>>{};
    for (final MapEntry(key: at, value: c) in prima.entries) {
      (gruppi[c] ??= []).add(at);
    }
    for (final MapEntry(key: c, value: ats) in gruppi.entries) {
      await Segni.colora(ats, c);
    }
    ora.addAll(prima);
    final adesso = Segni.nomi.value;
    for (final chiave in {...adesso.keys, ...nomiPrima.keys}) {
      final colore = Colore.da(chiave);
      if (colore != null && adesso[chiave] != nomiPrima[chiave]) await Segni.nomina(colore, nomiPrima[chiave] ?? '');
    }
  }
}
