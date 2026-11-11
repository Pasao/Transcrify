import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/filtro_voci.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/ricerche_recenti.dart';
import 'package:transcrify/ui/molecole/ricerche_fatte.dart';
import 'package:transcrify/ui/cerca.dart';
import 'package:transcrify/ui/molecole/riga_trovata.dart';
import 'package:transcrify/ui/theme.dart';

/// La ricerca (6 nov, giro 6): solo le parole e quello che trova il motore; i filtri sono andati in Trascrivi, sotto il
/// titolo. La regola dei filtri si prova qui da sola. Dati finti.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('transcrify/core');
  const verde = Colore(3, 3), rosso = Colore(0, 3);
  Map<String, Object?> voce(String testo, int giorno, Colore? k, {String? source, String mode = 'pulita'}) => {
    'text': testo,
    'at': DateTime(2026, 11, giorno, 9).millisecondsSinceEpoch,
    'purified': true,
    'mode': mode,
    'source': source,
    'colore': k?.chiave,
    'privata': false,
  };
  final storia = [
    voce('Verde vecchia del treno', 1, verde),
    voce('Rossa del treno', 2, rosso, source: 'com.whatsapp.w4b', mode: 'fedele'),
    voce('Verde nuova del treno', 3, verde, source: 'org.telegram.messenger'),
  ];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'history' => storia,
        'notes' => [
          {'id': 'n1', 'title': 'Una nota', 'text': 'Nota sul treno', 'created': 0, 'updated': DateTime(2026, 11, 4).millisecondsSinceEpoch},
        ],
        // Per parola le tre trascrizioni; per senso la nota.
        'cerca' => (call.arguments as Map)['senso'] == true
            ? [
                {'tipo': 'nota', 'id': 'n1', 'start': 0, 'end': 4, 'esatto': false},
              ]
            : [
                for (final v in storia) {'tipo': 'voce', 'id': '${v['at']}', 'start': 0, 'end': 5, 'esatto': true},
              ],
        _ => null,
      };
    });
  });

  test('I filtri: fonte, modo, colore; toccare di nuovo lo spegne; quanti ne sono accesi', () {
    final voci = [for (final v in storia) Entry(v)];
    List<String> passa(FiltroVoci f) => [
      for (final e in voci)
        if (f.ammette(e)) e.text,
    ];
    expect(const FiltroVoci().quanti, 0);
    expect(passa(const FiltroVoci().conColore(verde)), ['Verde vecchia del treno', 'Verde nuova del treno']);
    // WhatsApp Business conta come WhatsApp.
    expect(passa(const FiltroVoci().conFonte(Fonte.whatsapp)), ['Rossa del treno']);
    expect(passa(const FiltroVoci().conFonte(Fonte.altre)), ['Verde nuova del treno']);
    final due = const FiltroVoci().conModo('pulita').conColore(verde);
    expect(due.quanti, 2);
    expect(due.conModo('pulita').conColore(verde), const FiltroVoci());
    expect(const FiltroVoci().conFonte(Fonte.whatsapp).conFonte(Fonte.whatsapp).quanti, 0);
  });

  for (final luce in Brightness.values) {
    testWidgets('Niente filtri qui: con le parole, quello che trova il motore ($luce, stretto, testo grande)', (t) async {
      t.view.physicalSize = const Size(320, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(luce),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)), child: child!),
          home: const CercaPage(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(RigaTrovata), findsNothing);
      expect(find.byType(ChipFiltro), findsNothing);
      expect(find.byType(PuntoColore), findsNothing);
      await t.enterText(find.byType(TextField), 'treno');
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      // Prima quelle per parola, poi il titoletto e quelle per senso.
      expect(find.byType(RigaTrovata), findsNWidgets(4));
      final titoletto = find.text('PER SIGNIFICATO');
      expect(titoletto, findsOneWidget);
      final y = t.getTopLeft(titoletto).dy;
      final righe = find.byType(RigaTrovata).evaluate().map((e) => t.getTopLeft(find.byWidget(e.widget)).dy).toList();
      expect(righe.take(3).every((r) => r < y), isTrue);
      expect(righe.last, greaterThan(y));
      expect(t.takeException(), isNull);
    });
  }

  test('7 nov: le ultime ricerche, al massimo cinque, l\'ultima in cima, senza doppioni', () {
    var l = <String>[];
    for (final q in ['uno', 'due', 'tre', 'quattro', 'cinque', 'sei']) {
      l = RicercheRecenti.conNuova(l, q);
    }
    expect(l, ['sei', 'cinque', 'quattro', 'tre', 'due']);
    expect(RicercheRecenti.conNuova(l, '  Tre  '), ['Tre', 'sei', 'cinque', 'quattro', 'due']);
    expect(RicercheRecenti.conNuova(l, '   '), l);
  });

  testWidgets('7 nov: aperta la ricerca, le recenti (tocca e rifai, × e togli); nessuna, cosa si può cercare', (t) async {
    final scelte = <String>[], tolte = <String>[];
    Widget vista(List<String> r) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: RicercheFatte(ricerche: r, onScegli: scelte.add, onTogli: tolte.add)),
    );
    await t.pumpWidget(vista(const []));
    expect(find.text(RicercheFatte.invito), findsOneWidget);
    await t.pumpWidget(vista(const ['cena', 'treno']));
    expect(find.text('RECENTI'), findsOneWidget);
    await t.tap(find.text('treno'));
    await t.tap(find.byTooltip('Togli «cena»'));
    expect(scelte, ['treno']);
    expect(tolte, ['cena']);
  });
}
