import 'package:flutter/material.dart';

import '../../core/cambio_colore.dart';
import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';
import 'fila_colori.dart';
import 'fumetto.dart';
import 'pillola_annulla.dart';
import 'tavolozza.dart';

/// La scelta del colore (7 nov): la rosa ([Tavolozza]) in un fumetto sopra il controllo che l'ha aperta ([sopra]:
/// «Colore» nella barra delle scelte, il cerchio del colore in una trascrizione aperta). La stessa per una trascrizione
/// e per tante: [prima] è il colore di ognuna adesso. Ogni colore provato si salva e si vede subito; dopo ogni
/// cambio (anche «Annulla») [onCambiati] riceve il colore di ognuna, e chi l'ha aperta si ridisegna.
/// «Annulla» rimette tutto com'era; chiusa tenendo («Fatto», «indietro», un tocco fuori), se qualcosa è cambiato
/// arriva la pillola «Colore cambiato · Annulla», che rimette ognuna col suo colore di prima (e i nomi).
/// [nomeSegue]: una cartella che cambia colore si porta dietro il nome (`CambioColore.nomeSegue`).
Future<void> apriSceltaColore(
  BuildContext context, {
  required Rect sopra,
  required Map<DateTime, Colore?> prima,
  required ValueChanged<Map<DateTime, Colore?>> onCambiati,
  bool nomeSegue = false,
}) async {
  // I nomi di adesso, prima di ricordarli: «Annulla» deve rimettere quelli veri.
  await Segni.leggiNomi();
  if (!context.mounted) return;
  final cambio = CambioColore(prima, nomeSegue: nomeSegue);
  void avvisa() => onCambiati(Map.unmodifiable(cambio.ora));
  final tieni = await apriFumetto<bool>(
    context,
    sopra: sopra,
    builder: (fumetto) => Sospeso(
      raggio: Raggio.gruppo,
      padding: const EdgeInsets.all(Spazio.s2),
      child: SingleChildScrollView(
        child: Tavolozza(cambio: cambio, onCambiati: avvisa, onChiusa: (tieni) => Navigator.pop(fumetto, tieni)),
      ),
    ),
  );
  if (tieni == false) {
    await cambio.rimetti();
    return avvisa();
  }
  await cambio.tieni();
  if (!cambio.cambiato || !context.mounted) return;
  avvisa();
  if (await undoable(context, 'Colore cambiato')) {
    await cambio.rimetti();
    avvisa();
  }
}

/// Unendo schede di colori diversi (anche senza colore): la fila coi soli colori in gioco. Un tocco sceglie il colore
/// di quella unita e chiude; null se l'hai chiusa senza scegliere (non si unisce).
Future<(Colore?,)?> apriColoreUnione(BuildContext context, {required Rect sopra, required List<Colore?> colori}) => apriFumetto<(Colore?,)>(
  context,
  sopra: sopra,
  builder: (fumetto) => Sospeso(
    raggio: Raggio.gruppo,
    padding: const EdgeInsets.all(Spazio.s2),
    child: FilaColori(colori: colori, titolo: 'Di che colore la unisco?', onColore: (c) => Navigator.pop(fumetto, (c,))),
  ),
);
