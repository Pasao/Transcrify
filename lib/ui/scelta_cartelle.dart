import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'molecole/griglia_cartelle.dart';
import 'molecole/rinomina.dart';
import 'molecole/scelta_colore.dart';

/// Le cartelle scelte e cosa farne (5 nov sera, sua scelta: lo stesso gesto delle schede). Tenendo premuta una
/// cartella si comincia a sceglierle; la barra delle scelte (al posto del Dock) ha Rinomina (con una sola: il dialogo),
/// Colore e «Togli cartella» (le sue trascrizioni restano, senza colore; si annulla).
class SceltaCartelle extends ChangeNotifier {
  SceltaCartelle({required this.onCambiate});

  /// Dopo una scrittura nel nativo: la pagina rilegge le trascrizioni.
  final Future<void> Function() onCambiate;

  final scelte = <Colore>{};

  bool get scegliendo => scelte.isNotEmpty;

  /// La sceglie, o la toglie se lo era già.
  void scegli(Colore c) {
    if (!scelte.remove(c)) scelte.add(c);
    notifyListeners();
  }

  void fine() {
    if (scelte.isEmpty) return;
    scelte.clear();
    notifyListeners();
  }

  /// La barra delle scelte per le cartelle; null se non se ne stanno scegliendo. [cartelle]: quelle che ci sono ora.
  SelectionBar? barra(BuildContext context, List<DatiCartella> cartelle) {
    final s = [
      for (final k in cartelle)
        if (scelte.contains(k.colore)) k,
    ];
    if (s.isEmpty) return null;
    return SelectionBar(
      quante: s.length,
      onClose: fine,
      actions: [
        if (s.length == 1) (Icons.edit_rounded, 'Rinomina', (_) => _rinomina(context, s.single)),
        SelectionBar.colore((dove) => _colora(context, dove, s)),
        (Icons.folder_off_rounded, 'Togli cartella', (_) => _togli(context, s)),
      ],
    );
  }

  /// Rinominata, la scelta è finita (come in Samsung): si torna alle cartelle, col nome nuovo.
  Future<void> _rinomina(BuildContext context, DatiCartella k) async {
    if (await apriRinomina(context, colore: k.colore, attuale: k.nome)) fine();
  }

  /// Un altro colore a tutte le loro trascrizioni, nella rosa (si vede subito; «Annulla» rimette tutto). Con una
  /// cartella sola il nome va col colore, se quello nuovo non ne ha già uno: la cartella cambia colore, non nome.
  /// Restano scelte, col colore che hanno adesso.
  void _colora(BuildContext context, Rect dove, List<DatiCartella> s) => apriSceltaColore(
    context,
    sopra: dove,
    prima: {for (final k in s) ...{for (final e in k.voci) e.at: e.colore}},
    nomeSegue: s.length == 1,
    onCambiati: (ora) {
      scelte
        ..clear()
        ..addAll(ora.values.nonNulls);
      notifyListeners();
      onCambiate();
    },
  );

  /// Toglie le cartelle scelte: le loro trascrizioni restano, senza colore. «Annulla» le rimette esattamente com'erano.
  Future<void> _togli(BuildContext context, List<DatiCartella> s) async {
    fine();
    final voci = [for (final k in s) ...k.voci];
    await Segni.colora(voci.map((e) => e.at), null);
    await onCambiate();
    if (!context.mounted) return;
    if (await undoable(context, s.length == 1 ? 'Cartella tolta' : '${s.length} cartelle tolte')) {
      await Segni.rimetti(voci);
      await onCambiate();
    }
  }
}
