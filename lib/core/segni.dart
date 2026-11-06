import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native.dart';

/// Il colore di una trascrizione: una tinta e una luce della tavolozza, 16 tinte × 7 luci (i valori stanno in `Tinte`,
/// ui/ds; le prime 7 tinte sono quelle di prima, le altre 9 sono arrivate con la rosa dei colori, 6 nov).
/// Nel nativo si salva come «tinta:luce»: il Kotlin non sa che colore sia, lo tiene e basta.
@immutable
class Colore {
  const Colore(this.tinta, this.luce);

  /// Quante tinte e quante luci ha la tavolozza (`Tinte` ne ha tante così). Le tinte si aggiungono solo in fondo:
  /// «tinta:luce» salvato prima vuol dire sempre lo stesso colore.
  static const tinte = 16, luci = 7;

  final int tinta, luce;

  /// Da «tinta:luce»; null se manca o non è della tavolozza (una trascrizione di prima dei colori).
  static Colore? da(String? chiave) {
    final p = chiave?.split(':');
    if (p == null || p.length != 2) return null;
    final t = int.tryParse(p[0]), l = int.tryParse(p[1]);
    if (t == null || l == null || t < 0 || l < 0 || t >= tinte || l >= luci) return null;
    return Colore(t, l);
  }

  String get chiave => '$tinta:$luce';

  @override
  bool operator ==(Object other) => other is Colore && other.tinta == tinta && other.luce == luce;

  @override
  int get hashCode => Object.hash(tinta, luce);
}

/// I segni sulle trascrizioni: colore, privata, titolo, unite. Tutto si salva nel nativo, una scrittura per gesto.
abstract final class Segni {
  static const _ch = MethodChannel('transcrify/core');

  static List<int> _ms(Iterable<DateTime> ats) => [for (final a in ats) a.millisecondsSinceEpoch];

  /// Lo stesso colore (o nessuno) a tutte quelle in [ats].
  static Future<void> colora(Iterable<DateTime> ats, Colore? colore) async {
    if (!Core.preview.value) await _ch.invokeMethod('segnaHistory', {'ats': _ms(ats), 'colore': colore?.chiave});
  }

  /// Private (il testo non si vede sulla scheda) o di nuovo visibili.
  static Future<void> rendiPrivate(Iterable<DateTime> ats, bool privata) async {
    if (!Core.preview.value) await _ch.invokeMethod('segnaHistory', {'ats': _ms(ats), 'privata': privata});
  }

  /// Il titolo di una trascrizione; vuoto lo toglie (sulla scheda torna l'inizio del testo).
  static Future<void> intitola(DateTime at, String titolo) async {
    if (!Core.preview.value) await _ch.invokeMethod('segnaHistory', {'ats': _ms([at]), 'titolo': titolo.trim()});
  }

  /// Unisce le trascrizioni nell'ordine scelto (la prima è quella da cui sei partito). Torna quella nuova;
  /// null se non ce n'erano almeno due. Le altre se ne vanno nella stessa scrittura.
  static Future<Entry?> unisci(List<DateTime> ordine) async {
    if (Core.preview.value) return null;
    final m = await _ch.invokeMethod('unisciHistory', {'ats': _ms(ordine)}) as Map?;
    return m == null ? null : Entry(m);
  }

  /// «Annulla»: le trascrizioni tornano esattamente com'erano.
  static Future<void> rimetti(List<Entry> voci) async {
    if (Core.preview.value) return;
    await _ch.invokeMethod('rimettiHistory', {
      'voci': [for (final e in voci) e.toMap()],
    });
  }

  /// I nomi dati ai colori («Relazioni»): chiave del colore → nome. Si vedono nelle cartelle, non sulle schede.
  static final nomi = ValueNotifier<Map<String, String>>(const {});

  static Future<void> leggiNomi() async {
    if (Core.preview.value) return;
    final m = (await _ch.invokeMethod('nomiColori') as Map?)?.cast<String, String>() ?? const {};
    if (!mapEquals(m, nomi.value)) nomi.value = m;
  }

  /// Dà un nome a un colore; vuoto lo toglie.
  static Future<void> nomina(Colore colore, String nome) async {
    final pulito = nome.trim();
    nomi.value = {
      for (final MapEntry(:key, :value) in nomi.value.entries)
        if (key != colore.chiave) key: value,
      if (pulito.isNotEmpty) colore.chiave: pulito,
    };
    if (!Core.preview.value) await _ch.invokeMethod('nomeColore', {'colore': colore.chiave, 'nome': pulito});
  }
}
