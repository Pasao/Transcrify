import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/cambio_colore.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/regole_colori.dart';
import 'package:transcrify/ui/molecole/tavolozza.dart';
import 'package:transcrify/ui/theme.dart';

/// La rosa dei colori, la sola scelta del colore (7 nov): 24 colori in due anelli, la ✕ al centro (senza colore), il dito
/// che scorre accende il colore e ne dice il nome, lasciando lo sceglie; e il movimento che ha chiesto lui: aprendo
/// l'anello di dentro esce per primo e va piano, quello di fuori esce da sotto dopo e va più svelto, e arrivano insieme;
/// chiudendo al contrario, al centro insieme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  final at = DateTime(2026, 11, 7);
  late List<String?> colorate;
  late List<Map> regole;
  late List<bool> chiuse;
  late CambioColore cambio;

  setUp(() {
    colorate = [];
    regole = [];
    RegoleColori.tutte.value = const {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('transcrify/core'), (call) async {
      if (call.method == 'segnaHistory') colorate.add((call.arguments as Map)['colore'] as String?);
      if (call.method == 'salvaRegola') regole.add(call.arguments as Map);
      return null;
    });
  });

  Future<void> apri(WidgetTester t, Brightness luce, {Colore? scelto, Map<Colore, int> usi = const {}}) async {
    chiuse = [];
    Segni.nomi.value = const {'10:4': 'Relazioni'};
    cambio = CambioColore({at: scelto});
    t.view.physicalSize = const Size(320, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(luce),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!),
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Tavolozza(cambio: cambio, usi: usi, onCambiati: () {}, onChiusa: chiuse.add),
            ),
          ),
        ),
      ),
    );
  }

  // Il primo puntino di ogni anello sta in alto: il rosso chiaro dentro, il rosso vivo fuori.
  final dentro = find.byTooltip('Rosso 3'), fuori = find.byTooltip('Rosso');
  Offset centro(WidgetTester t) => t.getCenter(find.byWidgetPredicate((w) => w is SizedBox && w.width == Tavolozza.lato && w.height == Tavolozza.lato));
  double lontano(WidgetTester t, Finder f) => (t.getCenter(f) - centro(t)).distance;
  Finder titolo(String testo) => find.descendant(of: find.byType(Column), matching: find.text(testo)).first;

  for (final luce in Brightness.values) {
    testWidgets('24 colori: 16 fuori, 8 dentro, la ✕ al centro; un tocco sceglie, la ✕ toglie ($luce, stretto, testo grande)', (t) async {
      await apri(t, luce, scelto: const Colore(6, 2));
      await t.pumpAndSettle();
      final rosa = find.byWidgetPredicate((w) => w is SizedBox && w.width == Tavolozza.lato);
      expect(find.descendant(of: rosa, matching: find.byType(PuntoColore)), findsNWidgets(24 + 1));
      expect(lontano(t, dentro), moreOrLessEquals(Misura.rosaDentro, epsilon: 0.5));
      expect(lontano(t, fuori), moreOrLessEquals(Misura.rosaFuori, epsilon: 0.5));
      expect((t.getCenter(find.byIcon(Icons.close_rounded)) - centro(t)).distance, lessThan(0.5));
      // Quello scelto ha l'anello e la spunta (Viola 3 sta nell'anello di dentro), e c'è solo il campo del nome (10 nov:
      // la regola e «Offusca sempre» stanno in Impostazioni → Etichette).
      expect(t.widget<PuntoColore>(find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(PuntoColore))).etichetta, 'Viola 3');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Annulla'), findsOneWidget);
      expect(find.text('Fatto'), findsOneWidget);
      await t.tap(find.byTooltip('Relazioni · Menta'));
      await t.pump();
      expect(colorate, ['10:4']);
      expect(find.text('Relazioni · Menta'), findsWidgets);
      // La ✕ al centro: senza colore, e il campo del nome se ne va.
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pump();
      expect(colorate, ['10:4', null]);
      expect(find.byType(TextField), findsNothing);
      expect(t.widget<PuntoColore>(find.ancestor(of: find.byIcon(Icons.close_rounded), matching: find.byType(PuntoColore))).scelto, isTrue);
    });
  }

  testWidgets('Il dito che scorre accende il colore sotto e ne dice il nome; lasciando lo sceglie', (t) async {
    await apri(t, Brightness.light);
    await t.pumpAndSettle();
    expect(titolo('Senza colore'), findsOneWidget);
    final dito = await t.startGesture(centro(t) + const Offset(Spazio.s2, Spazio.s2));
    await t.pump();
    // Sul centro: la ✕.
    expect(titolo('Senza colore'), findsOneWidget);
    await dito.moveTo(t.getCenter(find.byTooltip('Relazioni · Menta')));
    await t.pump();
    expect(titolo('Relazioni · Menta'), findsOneWidget);
    expect(colorate, isEmpty);
    await dito.moveTo(t.getCenter(fuori));
    await t.pump(Durata.veloce);
    expect(titolo('Rosso'), findsOneWidget);
    // Acceso: più grande degli altri.
    double scala(Finder f) => t.widget<AnimatedScale>(find.ancestor(of: f, matching: find.byType(AnimatedScale)).first).scale;
    // Gli altri: pieni quelli tuoi (Relazioni ha un nome), più piccoli quelli liberi (Rosso 3).
    expect((scala(fuori), scala(dentro), scala(find.byTooltip('Relazioni · Menta'))), (Misura.rosaSotto, Misura.rosaLibera, Misura.rosaFerma));
    Color punto(Finder f) => t.widget<PuntoColore>(find.ancestor(of: f, matching: find.byType(PuntoColore))).colore;
    expect(punto(find.byTooltip('Relazioni · Menta')).a, 1);
    expect(punto(dentro).a, lessThan(1));
    expect(colorate, isEmpty);
    await dito.up();
    await t.pump();
    expect(colorate, ['0:${Tinte.luceViva(0)}']);
    expect(titolo('Rosso'), findsOneWidget);
    expect(t.widget<PuntoColore>(find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(PuntoColore))).etichetta, 'Rosso');
  });

  testWidgets('Aprendo: dentro esce per primo e va piano, fuori esce dopo da sotto e va svelto; arrivano insieme', (t) async {
    await apri(t, Brightness.light);
    await t.pump();
    final tempo = Durata.rosa;
    Duration parte(double x) => Duration(microseconds: (tempo.inMicroseconds * x).round());
    // All'inizio tutti al centro.
    expect(lontano(t, dentro), lessThan(0.5));
    expect(lontano(t, fuori), lessThan(0.5));
    // Poco dopo: dentro è già uscito, fuori aspetta ancora sotto.
    await t.pump(parte(Curva.rosaRitardo / 2));
    expect(lontano(t, dentro), greaterThan(Spazio.s2));
    expect(lontano(t, fuori), lessThan(0.5));
    // Quasi alla fine nessuno dei due è arrivato; alla fine tutti e due, insieme.
    await t.pump(parte(0.8 - Curva.rosaRitardo / 2));
    expect(lontano(t, dentro), lessThan(Misura.rosaDentro - 0.1));
    expect(lontano(t, fuori), lessThan(Misura.rosaFuori - 0.1));
    await t.pump(parte(0.2));
    await t.pump();
    expect(lontano(t, dentro), moreOrLessEquals(Misura.rosaDentro, epsilon: 0.5));
    expect(lontano(t, fuori), moreOrLessEquals(Misura.rosaFuori, epsilon: 0.5));
  });

  testWidgets('Chiudendo («Annulla»): fuori aspetta e poi rientra svelto, dentro rientra piano; al centro insieme, poi si chiude', (t) async {
    await apri(t, Brightness.dark);
    await t.pumpAndSettle();
    final tempo = Durata.rosa;
    Duration parte(double x) => Duration(microseconds: (tempo.inMicroseconds * x).round());
    await t.tap(find.text('Annulla'));
    await t.pump();
    await t.pump(parte(Curva.rosaRitardo / 2));
    // Dentro ha già cominciato a rientrare; fuori è ancora al suo posto.
    expect(lontano(t, dentro), lessThan(Misura.rosaDentro - 0.1));
    expect(lontano(t, fuori), moreOrLessEquals(Misura.rosaFuori, epsilon: 0.5));
    await t.pump(parte(0.8 - Curva.rosaRitardo / 2));
    expect(lontano(t, dentro), greaterThan(0.1));
    expect(lontano(t, fuori), greaterThan(0.1));
    expect(chiuse, isEmpty);
    // Arrivati al centro (un attimo dopo la fine: il controller si ferma appena la passa), si chiude senza tenere.
    await t.pump(parte(0.2) + const Duration(milliseconds: 1));
    await t.pump();
    expect(lontano(t, dentro), lessThan(0.5));
    expect(lontano(t, fuori), lessThan(0.5));
    expect(chiuse, [false]);
  });

  testWidgets('7 nov: i colori già in uso hanno il puntino appena fuori; scorrendo il nome dice quante sono', (t) async {
    await apri(t, Brightness.light, usi: {const Colore(10, 4): 12, const Colore(99, 0): 1});
    await t.pumpAndSettle();
    final menta = find.byKey(const ValueKey('in uso 10:4'));
    expect(menta, findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('in uso')), findsOneWidget); // un colore che non è sulla rosa non ha posto
    // Appena fuori dal suo colore, verso il bordo, e dentro la rosa.
    final suo = find.byTooltip('Relazioni · Menta');
    expect(lontano(t, menta), moreOrLessEquals(lontano(t, suo) + Misura.rosaUsoFuori, epsilon: 0.5));
    expect(lontano(t, menta) + Misura.rosaUso / 2, lessThan(Tavolozza.lato / 2));
    final g = await t.startGesture(t.getCenter(suo));
    await t.pump();
    expect(find.text('Relazioni · 12'), findsOneWidget);
    await g.up();
  });

  testWidgets('7 nov: dato un colore, la rosa si chiude più svelta, nello stesso modo', (t) async {
    await apri(t, Brightness.light);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Relazioni · Menta'));
    await t.pump();
    await t.tap(find.text('Fatto'));
    await t.pump();
    await t.pump(Durata.rosaVia + const Duration(milliseconds: 1));
    await t.pump();
    expect(chiuse, [true]);
  });

  testWidgets('10 nov: nella rosa solo colore e nome; «Fatto» salva il nome, non tocca le regole', (t) async {
    await apri(t, Brightness.light, scelto: const Colore(10, 4));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Regola'), findsNothing);
    await t.tap(find.text('Fatto'));
    await t.pumpAndSettle();
    expect(regole, isEmpty);
  });
}
