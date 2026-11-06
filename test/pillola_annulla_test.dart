import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/theme.dart';

/// «Annulla» dopo un'eliminazione (6 nov: «un po' più piccolo»): una pillola sola per tutti, alta quanto un bottone
/// basso, coi token. E le cifre che scorrono (il tempo, i conteggi): il carattere del testo con le cifre tabellari,
/// niente più DM Mono.
void main() {
  for (final luce in Brightness.values) {
    testWidgets('«Trascrizione eliminata»: piccola, sopra il Dock, «Annulla» la riprende ($luce, stretto, testo grande)', (t) async {
      t.view.physicalSize = const Size(320, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      bool? ripresa;
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(luce),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(onPressed: () async => ripresa = await undoable(context, 'Trascrizione eliminata'), child: const Text('Elimina')),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Elimina'));
      // Non «settle»: il cerchio si consuma per tutto il tempo, e alla fine la pillola se ne va.
      await t.pump();
      await t.pump(Durata.veloce);
      expect(find.byType(PillolaAnnulla), findsOneWidget);
      final pillola = t.getRect(find.byType(PillolaAnnulla));
      expect(t.getSize(find.descendant(of: find.byType(PillolaAnnulla), matching: find.byType(Container)).first).height, Misura.bottoneBasso);
      // Sopra il Dock: il suo fondo sta più su dell'isola e del suo margine.
      expect(pillola.bottom, lessThanOrEqualTo(720 - Misura.isola - Spazio.s3));
      expect(find.text('Trascrizione eliminata'), findsOneWidget);
      await t.tap(find.text('Annulla'));
      await t.pumpAndSettle();
      expect(ripresa, isTrue);
      expect(find.byType(PillolaAnnulla), findsNothing);
    });
  }

  test('Le cifre che scorrono non ballano: il carattere del testo con le cifre tabellari; DM Mono non c\'è più', () {
    expect(Testo.orario.fontFamily, Testo.fontTesto);
    expect(Testo.orario.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('DM Mono')));
    final nelCodice = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') && f.readAsStringSync().contains("'DM Mono'")) f.path,
    ];
    expect(nelCodice, isEmpty);
  });
}
