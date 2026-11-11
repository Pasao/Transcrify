import 'package:flutter/material.dart';

import '../../core/cambio_colore.dart';
import '../../core/native.dart';
import '../../core/regole_colori.dart';
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
/// Un'etichetta che prende il nome per la prima volta (10 nov) colora da sola, in fondo, quelle di prima che ne
/// parlano ([RegoleColori.coloraRetro]); se ne ha trovate, la pillola «Ho colorato N come «nome» · Annulla».
Future<void> apriSceltaColore(
  BuildContext context, {
  required Rect sopra,
  required Map<DateTime, Colore?> prima,
  required ValueChanged<Map<DateTime, Colore?>> onCambiati,
  bool nomeSegue = false,
}) async {
  // I nomi di adesso, prima di ricordarli: «Annulla» deve rimettere quelli veri.
  await Future.wait([Segni.leggiNomi(), RegoleColori.leggi()]);
  // I colori già in uso, contati una volta all'apertura: sulla rosa hanno il puntino.
  final usi = Segni.usi(await Core.history());
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
        child: Tavolozza(cambio: cambio, usi: usi, onCambiati: avvisa, onChiusa: (tieni) => Navigator.pop(fumetto, tieni)),
      ),
    ),
  );
  if (tieni == false) {
    await cambio.rimetti();
    return avvisa();
  }
  await cambio.tieni();
  if (!cambio.cambiato || !context.mounted) return;
  final colorate = [
    for (final MapEntry(:key, :value) in Segni.nomi.value.entries)
      // Il nome è nuovo, non quello di una cartella che ha solo cambiato colore.
      if (!cambio.nomiPrima.containsKey(key) && !cambio.nomiPrima.containsValue(value)) _coloraIndietro(context, Colore.da(key), value),
  ];
  avvisa();
  if (await undoable(context, 'Colore cambiato')) {
    await cambio.rimetti();
    // Senza il nome, nemmeno quelle colorate col nome.
    for (final ids in await Future.wait(colorate)) {
      if (ids.isNotEmpty) await RegoleColori.annullaColoraRetro(ids);
    }
    Core.refresh();
    avvisa();
  }
}

/// [colore] ha appena preso il [nome]: colora quelle di prima che ne parlano e propone «Annulla». Torna quelle
/// colorate e non riprese (per l'«Annulla» del colore).
Future<List<Object?>> _coloraIndietro(BuildContext context, Colore? colore, String nome) async {
  if (colore == null) return const [];
  final ids = await RegoleColori.coloraRetro(colore);
  if (ids.isEmpty || !context.mounted) return ids;
  Core.refresh();
  return await annullaColorati(context, nome, ids) ? const [] : ids;
}

/// «Ho colorato N come «nome» · Annulla» (10 nov): dopo che un'etichetta ha colorato quelle di prima ([ids]). Ripresa,
/// tornano com'erano; true se l'hai ripresa.
Future<bool> annullaColorati(BuildContext context, String nome, List<Object?> ids) async {
  if (!await undoable(context, 'Ho colorato ${ids.length} come «$nome»')) return false;
  await RegoleColori.annullaColoraRetro(ids);
  Core.refresh();
  return true;
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
