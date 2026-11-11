import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/avvio.dart';
import 'package:transcrify/ui/molecole/piede_intro.dart';
import 'package:transcrify/ui/onboarding.dart';
import 'package:transcrify/ui/prova_transcri.dart';
import 'package:transcrify/ui/theme.dart';

/// L'introduzione intera (7 nov, «super rotta»): ogni strada col canale finto. Prima pagina → chiave → prova → app;
/// «Salta» da ogni pagina, indietro (freccia e gesto) sempre alla pagina prima, la chiave (Groq che non si apre,
/// incollata, rifiutata, buona, trovata negli appunti), la prova (microfono negato, ascolto, Stop, trascrive, riuscita
/// → la sua scheda al centro, «Entra» e Transcri atterra; indietro mentre ascolta butta la voce). Su un telefono stretto col testo grande,
/// chiaro e scuro: niente sborda (un overflow fa fallire il test da solo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const buona = 'gsk_AAAAAAAAAAAAAAAAAAAAAAAA', cattiva = 'gsk_BBBBBBBBBBBBBBBBBBBBBBBB';
  late List<String> chiamate;
  late bool chiave;
  late bool microfono;
  String? appunti;

  setUp(() {
    chiamate = [];
    chiave = false;
    microfono = true;
    appunti = null;
    Core.live.value = const Live();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(const MethodChannel('transcrify/core'), (c) async {
      chiamate.add(c.method);
      if (c.method == 'checkKey' && (c.arguments as Map)['key'] != buona) throw PlatformException(code: 'k', message: 'Chiave non valida');
      if (c.method == 'setKey') chiave = true;
      if (c.method == 'history') return [{'text': 'La mia prima trascrizione.', 'at': 1, 'purified': false}];
      // «Mostra sopra altre app» non c'è: la prova lo chiede, e con «Non ora» ascolta nella pagina.
      if (c.method == 'canDrawOverlays') return false;
      return null;
    });
    m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.getData') return appunti == null ? null : {'text': appunti};
      if (c.method == 'Clipboard.setData') appunti = (c.arguments as Map)['text'] as String?;
      return null;
    });
    // Groq non si apre (nessun browser): url_launcher risponde «non aperta».
    m.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (_) async => false);
    // Il microfono: 1 = permesso, 0 = negato (permission_handler).
    m.setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), (c) async {
      final s = microfono ? 1 : 0;
      return switch (c.method) {
        'checkPermissionStatus' => s,
        'requestPermissions' => {for (final p in c.arguments as List) p: s},
        _ => null,
      };
    });
  });

  /// La bolla della prima pagina e Transcri respirano sempre: non si aspetta che stiano fermi, solo i passaggi.
  Future<void> assesta(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  late List<bool> entrate;
  late int viste;

  Future<void> avvia(WidgetTester t, {Brightness luce = Brightness.light, double testo = 1, Size schermo = const Size(400, 800)}) async {
    entrate = [];
    viste = 0;
    t.view.physicalSize = schermo;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(luce),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(testo)), child: child!),
        home: Avvio(
          leggi: () async => (hasKey: chiave, introSeen: false),
          segnaVista: () async => viste++,
          casa: (atterra, _) {
            entrate.add(atterra);
            return const Scaffold(body: Text('casa'));
          },
        ),
      ),
    );
    await assesta(t);
  }

  Finder nelPiede(String testo) => find.descendant(of: find.byType(PiedeIntro), matching: find.text(testo));

  /// Il fondo è sempre lo stesso: «Salta» a sinistra, «N di 3» in mezzo, il principale a destra.
  void piede(WidgetTester t, String conta, String principale) {
    final (s, n, p) = (t.getCenter(nelPiede('Salta')), t.getCenter(nelPiede(conta)), t.getCenter(nelPiede(principale)));
    expect(s.dx, lessThan(n.dx));
    expect(n.dx, lessThan(p.dx));
    expect((s.dy - p.dy).abs(), lessThan(1));
  }

  Future<void> tocca(WidgetTester t, Finder f) async {
    await t.tap(f);
    await assesta(t);
  }

  testWidgets('Primo avvio: le tre pagine in fila, il fondo sempre uguale; indietro torna alla pagina prima', (t) async {
    await avvia(t);
    expect(find.byType(IntroPage), findsOneWidget);
    piede(t, '1 di 3', 'Avanti');
    await tocca(t, nelPiede('Avanti'));
    expect(find.byType(KeyPage), findsOneWidget);
    piede(t, '2 di 3', 'Apri Groq');
    // La freccia, poi il gesto indietro: alla prima pagina, e non oltre (niente giri).
    await tocca(t, find.byTooltip('Indietro'));
    expect(find.byType(IntroPage), findsOneWidget);
    await tocca(t, nelPiede('Avanti'));
    await t.binding.handlePopRoute();
    await assesta(t);
    expect(find.byType(IntroPage), findsOneWidget);
    await tocca(t, nelPiede('Avanti'));
    await tocca(t, nelPiede('Salta'));
    expect(find.byType(ProvaTranscri), findsOneWidget);
    piede(t, '3 di 3', 'Metti la chiave');
    // Senza chiave la prova lo dice, e «Metti la chiave» riporta alla chiave.
    expect(find.textContaining('serve la chiave'), findsOneWidget);
    await tocca(t, nelPiede('Metti la chiave'));
    expect(find.byType(KeyPage), findsOneWidget);
    await tocca(t, nelPiede('Salta'));
    await t.binding.handlePopRoute();
    await assesta(t);
    expect(find.byType(KeyPage), findsOneWidget);
    expect(entrate, isEmpty);
  });

  testWidgets('«Salta» dalla prima pagina entra subito, e l\'introduzione è segnata vista', (t) async {
    await avvia(t);
    await tocca(t, nelPiede('Salta'));
    expect(find.text('casa'), findsOneWidget);
    expect(entrate, [false]);
    expect(viste, 1);
  });

  testWidgets('La chiave: Groq che non si apre lo dice; incollata, vuota è spenta, rifiutata lo dice, buona va avanti', (t) async {
    await avvia(t);
    await tocca(t, nelPiede('Avanti'));
    // Nei test Groq non si apre (non c'è il browser): una riga, non un blocco.
    await tocca(t, nelPiede('Apri Groq'));
    expect(find.textContaining('Non riesco ad aprire Groq'), findsOneWidget);
    await tocca(t, find.text('Ho già una chiave, la incollo io'));
    final usa = find.ancestor(of: nelPiede('Usa questa chiave'), matching: find.byType(TextButton));
    expect(t.widget<TextButton>(usa).onPressed, isNull);
    await t.enterText(find.byType(TextField), cattiva);
    await t.pump();
    await tocca(t, nelPiede('Usa questa chiave'));
    expect(find.text('Groq non riconosce questa chiave.'), findsOneWidget);
    expect(chiave, isFalse);
    await t.enterText(find.byType(TextField), buona);
    await t.pump();
    await tocca(t, nelPiede('Usa questa chiave'));
    expect(chiave, isTrue);
    expect(appunti, '');
    expect(find.byType(ProvaTranscri), findsOneWidget);
    piede(t, '3 di 3', 'Prova');
  });

  testWidgets('La chiave negli appunti si trova da sola; rifiutata, se ne incolla un\'altra', (t) async {
    appunti = cattiva;
    await avvia(t);
    await tocca(t, nelPiede('Avanti'));
    expect(find.text('Trovata negli appunti'), findsOneWidget);
    await tocca(t, nelPiede('Usa questa chiave'));
    expect(find.text('Groq non riconosce questa chiave.'), findsOneWidget);
    await tocca(t, find.text('Incollo un’altra chiave'));
    expect(find.text('Trovata negli appunti'), findsNothing);
    await t.enterText(find.byType(TextField), buona);
    await t.pump();
    await tocca(t, nelPiede('Usa questa chiave'));
    expect(find.byType(ProvaTranscri), findsOneWidget);
  });

  group('La prova', () {
    Future<void> allaProva(WidgetTester t) async {
      await avvia(t);
      // La chiave c'è già quando si arriva alla prova (all'avvio no, se no si entrerebbe subito).
      chiave = true;
      await tocca(t, nelPiede('Avanti'));
      await tocca(t, nelPiede('Salta'));
      expect(find.byType(ProvaTranscri), findsOneWidget);
    }

    testWidgets('Senza microfono lo dice, «Riprova»; «Salta» entra senza atterrare', (t) async {
      microfono = false;
      await allaProva(t);
      await tocca(t, nelPiede('Prova'));
      expect(find.textContaining('Senza microfono'), findsOneWidget);
      expect(chiamate, isNot(contains('listen')));
      piede(t, '3 di 3', 'Riprova');
      await tocca(t, nelPiede('Salta'));
      expect(entrate, [false]);
    expect(viste, 1);
    });

    testWidgets('Prova, ascolta, Stop, trascrive, riuscita: si entra e Transcri atterra', (t) async {
      await allaProva(t);
      await tocca(t, nelPiede('Prova'));
      expect(find.text('Un ultimo permesso'), findsOneWidget);
      await tocca(t, find.text('Non ora'));
      expect(chiamate, contains('listen'));
      Core.live.value = const Live(phase: 'RECORDING', seconds: 3);
      await t.pump();
      await t.tap(nelPiede('Stop'));
      await t.pump();
      expect(chiamate, contains('stopListening'));
      expect(t.widget<TextButton>(find.ancestor(of: nelPiede('Trascrivo…'), matching: find.byType(TextButton))).onPressed, isNull);
      Core.live.value = const Live(phase: 'PROCESSING');
      await t.pump();
      Core.live.value = const Live(phase: 'SUCCESS');
      await assesta(t);
      // 10 nov: pronta, la sua scheda al centro; «Entra» entra e Transcri atterra (la scheda vola nella lista).
      expect(find.text('Ecco la tua prima trascrizione'), findsOneWidget);
      piede(t, '3 di 3', 'Entra');
      await tocca(t, nelPiede('Entra'));
      expect(find.text('casa'), findsOneWidget);
      expect(entrate, [true]);
      // Qui la lista non c'è: la copia svanisce dov'è.
      await t.pump(Durata.attesaVoloPrima);
      await t.pump(Durata.voloPrima);
    });

    testWidgets('Indietro mentre ascolta: la voce si butta e si torna alla chiave', (t) async {
      await allaProva(t);
      Core.live.value = const Live(phase: 'RECORDING');
      await t.pump();
      await t.binding.handlePopRoute();
      await assesta(t);
      expect(chiamate, contains('discardListening'));
      expect(find.byType(KeyPage), findsOneWidget);
    });
  });

  // Telefono stretto e basso, testo grande, chiaro e scuro: ogni pagina, anche la prova mentre ascolta con l'avviso.
  for (final luce in Brightness.values) {
    testWidgets('Stretto, testo grande, ${luce.name}: niente sborda', (t) async {
      appunti = buona;
      await avvia(t, luce: luce, testo: 1.6, schermo: const Size(320, 560));
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await assesta(t);
      await tocca(t, nelPiede('Avanti'));
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await assesta(t);
      await tocca(t, nelPiede('Salta'));
      Core.live.value = const Live(phase: 'RECORDING', seconds: 65);
      await t.pump();
      Core.live.value = const Live(phase: 'ERROR', error: 'Groq non ha risposto per un bel po\' di tempo, riprova.');
      await t.pump();
      expect(find.byType(ProvaTranscri), findsOneWidget);
    });
  }
}
