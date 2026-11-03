// Le regole del codice (DESIGN-SYSTEM.md, «Le regole»), controllate a ogni `flutter test`.
// Se una fallisce, non si va avanti: si sistema il codice, non il test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/ds_rimasti.dart' as ds;

void main() {
  final radice = Directory.current;

  test('Regola 1 · I valori scritti a mano possono solo diminuire (e nei file nuovi sono zero)', () {
    final tetto = (jsonDecode(File('test/regole_tetto.json').readAsStringSync()) as Map).map(
      (f, c) => MapEntry(f as String, (c as Map).map((k, v) => MapEntry(k as String, v as int))),
    );
    final oltre = <String>[];
    ds.conta(radice).forEach((file, conti) {
      conti.forEach((k, n) {
        final max = tetto[file]?[k] ?? 0;
        if (n > max) oltre.add('$file: $k $n (massimo $max)');
      });
    });
    expect(oltre, isEmpty,
        reason: 'Valori scritti a mano invece dei token (lib/ui/ds/). Usa context.col, Testo, Spazio, Raggio, Misura, Durata, Ombra. '
            'Quando un file migliora: dart run tool/ds_rimasti.dart --tetto');
  });

  test('Regola 2 · Niente doppioni: ogni classe ha un nome solo, in un file solo', () {
    final dove = <String, List<String>>{};
    final rx = RegExp(r'^(?:abstract |final |sealed |base |interface )*(?:class|enum|mixin|extension type) (\w+)', multiLine: true);
    for (final (rel, f) in ds.fileDa(radice).where((e) => e.$1.endsWith('.dart'))) {
      for (final m in rx.allMatches(f.readAsStringSync())) {
        (dove[m.group(1)!] ??= []).add(rel);
      }
    }
    final doppi = {for (final e in dove.entries) if (e.value.length > 1) e.key: e.value};
    expect(doppi, isEmpty, reason: 'La stessa cosa definita due volte: tienine una e usa quella.');
  });

  test('Regola 3 · Niente codice copiato: lo stesso blocco non compare due volte nei pezzi nuovi', () {
    // Un blocco = 5 righe di fila (senza spazi, parentesi sole, import e commenti). Si confronta ogni
    // blocco dei pezzi nuovi con tutto il resto del codice: se c'è già, va estratto e riusato (DRY).
    const nuovi = ['lib/ui/ds/', 'lib/ui/atomi/', 'lib/ui/molecole/'];
    const lungo = 5;
    final struttura = RegExp(r'^(?:const )?(?:(?:child|children|body|builder): )?(?:\w+\(|\[)$|^(?:cross|main)Axis\w+: [\w.]+,$|^mainAxisSize: MainAxisSize\.\w+,$');
    List<(int, String)> righe(File f) {
      final out = <(int, String)>[];
      final l = f.readAsLinesSync();
      for (var i = 0; i < l.length; i++) {
        final t = l[i].trim().replaceAll(RegExp(r'\s+'), ' ');
        if (t.length < 4 || t.startsWith('//') || t.startsWith('import ') || t.startsWith('export ') || RegExp(r'^[\)\]\}\;,\s]*$').hasMatch(t)) continue;
        // Le righe solo di struttura (`child: Column(`, `children: [`, `Row(`…) ci sono in ogni widget: non sono copie.
        if (struttura.hasMatch(t)) continue;
        out.add((i + 1, t));
      }
      return out;
    }

    final visti = <String, String>{};
    final copie = <String>[];
    final file = ds.fileDa(radice).where((e) => e.$1.endsWith('.dart')).toList()
      ..sort((a, b) => nuovi.any(a.$1.startsWith) == nuovi.any(b.$1.startsWith) ? 0 : (nuovi.any(a.$1.startsWith) ? 1 : -1));
    for (final (rel, f) in file) {
      final r = righe(f);
      final mio = nuovi.any(rel.startsWith);
      for (var i = 0; i + lungo <= r.length; i++) {
        final blocco = r.sublist(i, i + lungo).map((e) => e.$2).join('\n');
        final dove = '$rel:${r[i].$1}';
        final prima = visti[blocco];
        if (prima == null) {
          visti[blocco] = dove;
        } else if (mio && prima.split(':').first != rel) {
          copie.add('$dove uguale a $prima');
        }
      }
    }
    expect(copie, isEmpty, reason: 'Codice copiato: estrai il pezzo in comune e usalo da entrambi i posti.');
  });

  test('Regola 4 · I pezzi nuovi usano solo i nomi nuovi (niente Tokens.* né tk.*)', () {
    const cartelle = ['lib/ui/atomi/', 'lib/ui/molecole/'];
    final vecchi = [
      for (final (rel, f) in ds.fileDa(radice))
        if (cartelle.any(rel.startsWith) && RegExp(r'\bTokens\.|\btk\.|context\.tk\b').hasMatch(f.readAsStringSync())) rel,
    ];
    expect(vecchi, isEmpty, reason: 'Nei pezzi nuovi: context.col e le misure di ds/.');
  });
}
