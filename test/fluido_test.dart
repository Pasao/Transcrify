// Quanto costano le liste, con tanti dati finti (mai quelli veri): 2000 trascrizioni, 500 note.
// Misura il primo fotogramma, lo scorrimento, la rilettura dal nativo, la ricerca e l'indicatore
// che gira. I tempi sono del test (debug, senza GPU): servono a confrontare prima e dopo, non sono
// quelli del telefono. `flutter test test/fluido_test.dart` li stampa.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/pensieri.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';

const _parole = [
  'oggi',
  'domani',
  'casa',
  'lavoro',
  'idea',
  'progetto',
  'chiamare',
  'comprare',
  'pane',
  'riunione',
  'scrivere',
  'leggere',
  'treno',
  'viaggio',
  'mare',
  'montagna',
  'amico',
  'libro',
  'musica',
  'tempo',
  'presto',
  'tardi',
  'sempre',
  'forse',
  'bello',
  'nuovo',
  'vecchio',
  'grande',
  'piccolo',
  'ricordare',
];

/// Un testo finto di circa [n] caratteri, con qualche a capo.
String _testo(math.Random r, int n) {
  final b = StringBuffer();
  while (b.length < n) {
    b.write(_parole[r.nextInt(_parole.length)]);
    b.write(r.nextInt(25) == 0 ? '.\n' : ' ');
  }
  return b.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('transcrify/core');
  final r = math.Random(7);
  final ora = DateTime(2026, 11, 3, 20).millisecondsSinceEpoch;
  // Cinque al giorno, per 400 giorni: dalla più nuova.
  final storia = [
    for (var i = 0; i < 2000; i++)
      {
        'text': _testo(r, 40 + r.nextInt(i % 10 == 0 ? 4000 : 400)),
        'at': ora - i * (86400000 ~/ 5),
        'purified': i.isEven,
        'mode': ['fedele', 'pulita', 'riassunto', null][i % 4],
        'source': i % 7 == 0 ? 'com.whatsapp' : null,
      },
  ];
  List<Map<String, Object?>> note({int inLavoro = 0}) => [
    for (var i = 0; i < 500; i++)
      {
        'id': 'n$i',
        'title': i % 3 == 0 ? '' : _testo(math.Random(i), 10 + i % 30),
        'text': _testo(math.Random(i + 1000), 20 + (i * 37) % (i % 9 == 0 ? 6000 : 700)),
        'created': ora - i * 3600000,
        'updated': ora - i * 3600000,
        'topics': i < inLavoro ? 'pending' : ['ready', 'off', 'stale'][i % 3],
        'source': i % 11 == 0 ? 'com.whatsapp' : null,
        'summary': null,
      },
  ];
  var inLavoro = 0;
  // Il telefono ne tiene al massimo 100 (Store.HISTORY_SIZE); 2000 per vedere dove si rompe.
  var quanteStoria = 2000;

  setUp(() {
    Core.live.value = const Live();
    inLavoro = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'history' => storia.take(quanteStoria).toList(),
        'notes' => note(inLavoro: inLavoro),
        'albums' => [
          for (var i = 0; i < 60; i++)
            {
              'id': i,
              'name': 'Argomento $i',
              'concetto': i ~/ 4,
              'concettoNome': 'Concetto ${i ~/ 4}',
              'pieces': [
                for (var j = 0; j < 3 + i % 5; j++) {'note': 'n${(i * 7 + j) % 500}', 'start': 0, 'end': 10},
              ],
            },
        ],
        _ => null,
      };
    });
  });

  Widget app(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  );

  Future<void> telefono(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  /// Quanto ci mette (in millisecondi) a fare quello che fa [f].
  Future<double> ms(Future<void> Function() f) async {
    final s = Stopwatch()..start();
    await f();
    return s.elapsedMicroseconds / 1000;
  }

  /// [n] fotogrammi di fila: ognuno sposta il dito di [passo] (o non fa niente, se [gesto] è null).
  Future<String> fotogrammi(WidgetTester t, int n, {TestGesture? gesto, Offset passo = Offset.zero}) async {
    final tempi = <double>[];
    for (var i = 0; i < n; i++) {
      tempi.add(
        await ms(() async {
          await gesto?.moveBy(passo);
          await t.pump(const Duration(milliseconds: 16));
        }),
      );
    }
    tempi.sort();
    final media = tempi.reduce((a, b) => a + b) / n;
    return 'media ${media.toStringAsFixed(2)} ms, peggiore ${tempi.last.toStringAsFixed(2)} ms';
  }

  Future<String> scorri(WidgetTester t, Offset da, Offset passo, {int n = 90}) async {
    final g = await t.startGesture(da);
    await g.moveBy(passo * 2);
    await t.pump();
    final out = await fotogrammi(t, n, gesto: g, passo: passo);
    await g.up();
    await t.pumpAndSettle();
    return out;
  }

  void dici(String s) => debugPrint('FLUIDO · $s');

  for (final quante in [2000, 100]) {
    testWidgets('Trascrivi con $quante trascrizioni', (t) async {
      quanteStoria = quante;
      await telefono(t);
      final primo = await ms(() async {
        await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
        await t.pump();
        await t.pump();
      });
      expect(find.text('Oggi'), findsWidgets);
      dici('Trascrivi $quante · primo fotogramma ${primo.toStringAsFixed(1)} ms');
      // La pagina è al contrario: il dito scende per vedere le più vecchie.
      dici('Trascrivi $quante · scorrere: ${await scorri(t, const Offset(180, 300), const Offset(0, 24))}');
      final rilettura = await ms(() async {
        Core.refresh();
        await t.pump();
        await t.pump();
      });
      dici('Trascrivi $quante · rilettura dal nativo (stessi dati) ${rilettura.toStringAsFixed(1)} ms');
      // Lo slider veloce: compare scorrendo, poi lo si prende sul bordo destro e si corre.
      final g = await t.startGesture(const Offset(180, 400));
      await g.moveBy(const Offset(0, 30));
      await t.pump();
      await g.up();
      await t.pump();
      final barretta = find.byWidgetPredicate((w) => w is GestureDetector && w.onVerticalDragUpdate != null && w.behavior == HitTestBehavior.opaque);
      if (barretta.evaluate().isNotEmpty) {
        final gesto = await t.startGesture(t.getCenter(barretta.first));
        await gesto.moveBy(const Offset(0, -30));
        await t.pump();
        dici('Trascrivi $quante · slider veloce: ${await fotogrammi(t, 60, gesto: gesto, passo: const Offset(0, -8))}');
        await gesto.up();
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('Pensieri con 500 note', (t) async {
    await telefono(t);
    final primo = await ms(() async {
      await t.pumpWidget(app(const PensieriPage(bottom: 76)));
      await t.pump();
      await t.pump();
    });
    // Due colonne larghe uguali, con lo spazio in mezzo; solo le schede che si vedono (e le vicine) sono costruite.
    final schede = find.byType(NoteCard).evaluate().map((e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dx).toSet();
    expect(schede, {16, 16 + (360 - 32 - 10) / 2 + 10});
    expect(find.byType(NoteCard).evaluate().length, lessThan(100));
    dici('Pensieri · primo fotogramma ${primo.toStringAsFixed(1)} ms');
    dici('Pensieri · scorrere: ${await scorri(t, const Offset(180, 600), const Offset(0, -24))}');
    final rilettura = await ms(() async {
      Core.refresh();
      await t.pump();
      await t.pump();
    });
    dici('Pensieri · rilettura dal nativo (stessi dati) ${rilettura.toStringAsFixed(1)} ms');
    // Tre note che si stanno dividendo per argomento: l'indicatore gira.
    inLavoro = 3;
    Core.refresh();
    await t.pump();
    await t.pump();
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await t.pump(const Duration(seconds: 1));
    dici('Pensieri · fermo, con 3 indicatori che girano: ${await fotogrammi(t, 60)}');
    final cerca = await ms(() async {
      await t.enterText(find.byType(TextField), 'treno');
      await t.pump();
    });
    dici('Pensieri · una ricerca ${cerca.toStringAsFixed(1)} ms');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('Argomenti con 60 album', (t) async {
    await telefono(t);
    final primo = await ms(() async {
      await t.pumpWidget(app(const ArgomentiPage(bottom: 76)));
      await t.pump();
      await t.pump();
    });
    dici('Argomenti · primo fotogramma ${primo.toStringAsFixed(1)} ms');
    dici('Argomenti · scorrere: ${await scorri(t, const Offset(180, 600), const Offset(0, -24))}');
    final rilettura = await ms(() async {
      Core.refresh();
      await t.pump();
      await t.pump();
    });
    dici('Argomenti · rilettura dal nativo (stessi dati) ${rilettura.toStringAsFixed(1)} ms');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
