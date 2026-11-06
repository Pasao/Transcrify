import 'package:flutter/material.dart';

import '../core/segni.dart';
import 'cartelle.dart';
import 'molecole/filtri_voci.dart';
import 'molecole/tasto_filtri.dart';
import 'trascrivi.dart';

/// I filtri di Trascrivi collegati alla sua lista (6 nov, giro 7): il tasto «Filtri» tra le azioni in cima, col suo
/// pannello, e i filtri accesi sotto il titolo. Li mette la shell nell'intestazione; leggono e scrivono
/// [TrascriviPage.filtro], mostrano solo [TrascriviPage.possibili].
abstract final class FiltriTrascrivi {
  /// Quando ridisegnare l'intestazione: cambiano i filtri accesi, quelli possibili o i nomi dei colori.
  static final cambia = Listenable.merge([TrascriviPage.filtro, TrascriviPage.possibili, Segni.nomi]);

  static List<(String, List<VoceFiltro>)> _righe(BuildContext context) => righeFiltri(
    context,
    filtro: TrascriviPage.filtro.value,
    possibili: TrascriviPage.possibili.value,
    onFiltro: (f) => TrascriviPage.filtro.value = f,
    nome: (k) => Cartelle.nome(k, Segni.nomi.value),
  );

  /// Il tasto, o null se non c'è niente da filtrare (e niente di acceso).
  static Widget? tasto() {
    final quanti = TrascriviPage.filtro.value.quanti;
    if (TrascriviPage.possibili.value.vuoti && quanti == 0) return null;
    return TastoFiltri(
      quanti: quanti,
      pannello: (_) => ListenableBuilder(
        listenable: cambia,
        builder: (context, _) => PannelloFiltri(righe: _righe(context)),
      ),
    );
  }

  /// I filtri accesi, sotto il titolo.
  static Widget accesi() => Builder(builder: (context) => FiltriAccesi(righe: _righe(context)));
}
