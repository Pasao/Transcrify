import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/ui/molecole/risultato_estratto.dart';
import 'package:transcrify/ui/prova_estratto.dart';
import 'package:transcrify/ui/theme.dart';

/// La prova del riassunto estrattivo (Impostazioni → Prove): scegli un testo, il nativo sceglie le frasi.
/// Solo lettura: dal nativo si leggono la storia e le note e si chiede l'estratto, nient'altro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const channel = MethodChannel('transcrify/core');
  final at = DateTime(2026, 11, 5, 9).millisecondsSinceEpoch;
  // Lungo: l'ultima frase sta fuori dallo schermo, toccandola si scorre.
  final testo = '${List.filled(60, 'Una riga qualunque di riempimento.').join(' ')} Devo mandare il preventivo a Luca entro giovedì.';
  final frase = testo.indexOf('Devo');

  late List<String> chiamate;
  late Map<String, Object?> risposta;

  setUp(() {
    chiamate = [];
    risposta = {
      'stato': 'pronto',
      'modello': 'preciso',
      'ms': 812,
      'freddo': true,
      'frasi': [
        {'start': frase, 'end': testo.length - 1, 'testo': 'Devo mandare il preventivo a Luca entro giovedì.'},
      ],
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      chiamate.add(call.method);
      return switch (call.method) {
        'history' => [
          {'text': testo, 'at': at, 'purified': true, 'mode': null, 'source': null, 'colore': null, 'privata': false},
        ],
        'notes' => <Object>[],
        'estratto' => risposta,
        _ => null,
      };
    });
  });

  Future<void> apri(WidgetTester t, Brightness luce) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme(luce), home: const ProvaEstrattoPage()));
    await t.pumpAndSettle();
  }

  for (final luce in Brightness.values) {
    testWidgets('Sceglie un testo, mostra le frasi e il testo illuminato ($luce); tocco = scorre fin lì', (t) async {
      await apri(t, luce);
      await t.tap(find.textContaining('Una riga qualunque').first);
      await t.pumpAndSettle();
      expect(find.byType(RisultatoEstratto), findsOneWidget);
      expect(find.textContaining('812 ms (col caricamento del modello)'), findsOneWidget);
      final lista = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(lista.pixels, 0);
      await t.tap(find.text('Devo mandare il preventivo a Luca entro giovedì.'));
      await t.pumpAndSettle();
      expect(lista.pixels, greaterThan(0));
      expect(t.takeException(), isNull);
      // Solo lettura: niente scritture, niente altro.
      expect(chiamate.toSet(), {'history', 'notes', 'estratto'});
    });
  }

  testWidgets('Senza modello: lo dice e porta a sceglierlo', (t) async {
    risposta = {'stato': 'senzaModello'};
    await apri(t, Brightness.light);
    await t.tap(find.textContaining('Una riga qualunque').first);
    await t.pumpAndSettle();
    expect(find.text('Scegli il modello'), findsOneWidget);
  });
}
