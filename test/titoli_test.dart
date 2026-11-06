// Giro 6 (6 nov): il titolo delle trascrizioni (salvato col nativo, proposto dal riassunto estrattivo, cambiato lì),
// la fascia della scheda, il cerchio del colore nella trascrizione aperta, le macchie della privata. Dati finti.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/titoli.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/molecole/titolo_modificabile.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';
import 'package:transcrify/ui/trascrizione_aperta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const channel = MethodChannel('transcrify/core');
  final oggi = DateTime.now();

  late List<Map<String, Object?>> storia;
  late List<MethodCall> chiamate;

  /// Il riassunto estrattivo finto: «pronto» con le sue frasi, o «senzaModello».
  late Map<String, Object?> estratto;

  Map<String, Object?> voce(String testo, int ore, {String? titolo, String? colore, bool privata = false, String? mode, String? source}) => {
    'text': testo,
    'at': oggi.subtract(Duration(hours: ore)).millisecondsSinceEpoch,
    'purified': mode != null,
    'mode': mode,
    'source': source,
    'colore': colore,
    'privata': privata,
    'titolo': ?titolo,
  };

  setUp(() {
    Core.live.value = const Live();
    TrascriviPage.scegliendo.value = false;
    Titoli.dimentica();
    // Le prove di prima sono coi titoli accesi (Impostazioni → Prove → «Titoli automatici»); spenti: il gruppo in fondo.
    Titoli.automatici.value = true;
    chiamate = [];
    estratto = {'stato': 'senzaModello'};
    storia = [
      voce('Domani alle dieci passo a prendere i documenti in comune, poi chiamo Marta.', 1, mode: 'pulita', source: 'com.whatsapp'),
      voce('Ricordami di scrivere a Luca sul preventivo.', 2, titolo: 'Il preventivo', colore: '0:4', mode: 'fedele'),
      voce('Il treno segreto delle nove.', 3, privata: true, colore: '3:4'),
    ];
    // Il nativo finto: tiene il titolo come Store (vuoto lo toglie), come `segnaHistory` nel Kotlin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      chiamate.add(call);
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'history':
          return [for (final m in storia) {...m}];
        case 'estratto':
          return estratto;
        case 'segnaHistory':
          final ats = (args['ats'] as List).cast<int>();
          for (final m in storia) {
            if (!ats.contains(m['at'])) continue;
            if (args.containsKey('colore')) m['colore'] = args['colore'];
            if (args.containsKey('titolo')) m['titolo'] = (args['titolo'] as String).isEmpty ? null : args['titolo'];
          }
      }
      return null;
    });
  });

  // Le macchie della privata girano sempre: ferme qui, per aspettare la fine dei movimenti.
  Widget app(Widget child, {double testo = 1.3, Brightness luce = Brightness.dark, bool fermo = true}) => MaterialApp(
    theme: buildTheme(luce),
    builder: (context, figlio) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(testo), disableAnimations: fermo),
      child: figlio!,
    ),
    home: Scaffold(body: child),
  );

  Future<void> telefono(WidgetTester t, {double largo = 320}) async {
    t.view.physicalSize = Size(largo, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> fine(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  }

  group('Le regole del titolo', () {
    test('Senza titolo: le prime cinque parole (senza segni né punteggiatura in fondo); privata: «Privata»', () {
      expect(Titoli.taglia('Domani alle **dieci** passo a prendere i documenti.'), 'Domani alle dieci passo a');
      expect(Titoli.taglia('Ciao, Marta!'), 'Ciao, Marta');
      expect(Titoli.di(Entry(voce('Una cosa breve.', 0))), 'Una cosa breve');
      expect(Titoli.di(Entry(voce('Segreto.', 0, privata: true))), 'Privata');
      expect(Titoli.di(Entry(voce('Segreto.', 0, privata: true, titolo: 'Il mio'))), 'Il mio');
    });

    test('Dalle frasi del riassunto: la più corta, tagliata, con la maiuscola', () {
      expect(Titoli.daFrasi(['Poi chiamo Marta per la cena di sabato sera tardi.', 'passo in comune per i documenti']), 'Passo in comune per i');
      expect(Titoli.daFrasi(['', '  ']), isNull);
    });

    test('Il titolo va e viene dal nativo (e le trascrizioni di prima non ne hanno)', () async {
      final e = Entry(storia[1]);
      expect(e.titolo, 'Il preventivo');
      expect(Entry(e.toMap()), e);
      expect(Entry(storia[0]).titolo, isNull);
      await Segni.intitola(e.at, '  Luca ');
      expect(chiamate.last.arguments, {
        'ats': [e.at.millisecondsSinceEpoch],
        'titolo': 'Luca',
      });
      expect((await Core.history())[1].titolo, 'Luca');
      await Segni.intitola(e.at, '');
      expect((await Core.history())[1].titolo, isNull);
    });
  });

  group('Il titolo proposto', () {
    test('Col modello: la frase più corta, salvata una volta sola; le private e quelle col titolo no', () async {
      estratto = {
        'stato': 'pronto',
        'frasi': [
          {'testo': 'passo a prendere i documenti in comune', 'start': 0, 'end': 10},
          {'testo': 'poi chiamo Marta per la cena di sabato', 'start': 11, 'end': 20},
        ],
      };
      final voci = [for (final m in storia) Entry(m)];
      for (final e in voci) {
        Titoli.proponi(e);
        Titoli.proponi(e);
      }
      await pumpEventQueue();
      expect(chiamate.where((c) => c.method == 'estratto'), hasLength(1));
      final segno = chiamate.singleWhere((c) => c.method == 'segnaHistory');
      expect((segno.arguments as Map)['titolo'], 'Passo a prendere i documenti');
      expect(storia[0]['titolo'], 'Passo a prendere i documenti');
    });

    test('Senza modello: niente si salva, e non si chiede più', () async {
      for (final m in storia) {
        Titoli.proponi(Entry({...m, 'titolo': null, 'privata': false}));
      }
      await pumpEventQueue();
      expect(chiamate.where((c) => c.method == 'estratto'), hasLength(1));
      expect(chiamate.where((c) => c.method == 'segnaHistory'), isEmpty);
    });
  });

  for (final luce in Brightness.values) {
    testWidgets('La scheda ($luce, stretta, testo grande): in fondo il titolo col cestino e l\'ora con le iconcine, alte uguali', (t) async {
      await telefono(t);
      await t.pumpWidget(app(const TrascriviPage(bottom: 76), testo: 1.6, luce: luce));
      await t.pumpAndSettle();
      // Senza titolo l'inizio del testo; col titolo il suo; la privata col suo colore dice «Privata».
      expect(find.text('Domani alle dieci passo a'), findsOneWidget);
      expect(find.text('Il preventivo'), findsOneWidget);
      // Le iconcine senza parole: da WhatsApp, e ripassata dall'AI (pulita); la fedele non ha l'iconcina del modo.
      final prima = find.ancestor(of: find.text('Domani alle dieci passo a'), matching: find.byType(SchedaTrascrizione));
      expect(find.descendant(of: prima, matching: find.byType(SourceIcon)), findsOneWidget);
      expect(find.descendant(of: prima, matching: find.byType(EtichettaModo)), findsOneWidget);
      final seconda = find.ancestor(of: find.text('Il preventivo'), matching: find.byType(SchedaTrascrizione));
      expect(find.descendant(of: seconda, matching: find.byType(EtichettaModo)), findsNothing);
      expect(t.getRect(prima).height, SchedaTrascrizione.alta);
      await fine(t);
    });
  }

  for (final luce in Brightness.values) {
    testWidgets('Trascrizione aperta ($luce): il titolo a sinistra si cambia lì, il cerchio del colore a destra, sempre lì', (t) async {
      await telefono(t);
      Entry? aperta;
      await t.pumpWidget(
        app(
          Builder(builder: (context) => Center(child: TextButton(onPressed: () => openEntry(context, aperta!), child: const Text('Apri')))),
          testo: 1.5,
          luce: luce,
        ),
      );
      // Senza colore: l'invito tratteggiato col «+». Il titolo è l'inizio del testo.
      aperta = Entry(storia[0]);
      await t.tap(find.text('Apri'));
      await t.pumpAndSettle();
      final invito = find.byType(CerchioColore);
      expect(t.widget<CerchioColore>(invito).colore, isNull);
      expect(find.descendant(of: invito, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);
      final titolo = find.descendant(of: find.byType(TitoloModificabile), matching: find.text('Domani alle dieci passo a'));
      expect(titolo, findsOneWidget);
      // Il cerchio sta a destra del titolo, in alto.
      expect(t.getRect(invito).left, greaterThan(t.getRect(titolo).right));
      expect(t.getRect(invito).right, lessThanOrEqualTo(320));
      // Toccato il titolo: il campo, già pronto, con «Annulla» e «Fatto».
      await t.tap(titolo);
      await t.pumpAndSettle();
      expect(find.text('Annulla'), findsOneWidget);
      await t.enterText(find.descendant(of: find.byType(TitoloModificabile), matching: find.byType(TextField)), 'Documenti e cena');
      await t.tap(find.text('Fatto'));
      await t.pumpAndSettle();
      expect(find.text('Documenti e cena'), findsOneWidget);
      expect(storia[0]['titolo'], 'Documenti e cena');
      Navigator.of(t.element(find.byType(TitoloModificabile))).pop();
      await t.pumpAndSettle();

      // Col colore: il tondo pieno con l'anello attorno, nello stesso posto.
      aperta = Entry(storia[1]);
      await t.tap(find.text('Apri'));
      await t.pumpAndSettle();
      expect(t.widget<CerchioColore>(find.byType(CerchioColore)).colore, Tinte.di(0, 4));
      expect(find.descendant(of: find.byType(CerchioColore), matching: find.byIcon(Icons.add_rounded)), findsNothing);
      expect(t.getRect(find.byType(CerchioColore)).right, t.getRect(invito).right);
      expect(find.text('Il preventivo'), findsOneWidget);
      await fine(t);
    });
  }

  testWidgets('La privata: macchie sfocate che girano piano; ferme con «riduci le animazioni»', (t) async {
    await telefono(t, largo: 900);
    storia = [storia[2]];
    await t.pumpWidget(app(const TrascriviPage(bottom: 76), fermo: false));
    await t.pump(const Duration(milliseconds: 100));
    final copertura = find.byType(CoperturaPrivata);
    expect(copertura, findsOneWidget);
    expect(find.descendant(of: copertura, matching: find.byIcon(Icons.lock_rounded)), findsOneWidget);
    // La fascia resta: «Privata» col suo colore (il testo non si legge).
    expect(find.text('Privata'), findsOneWidget);
    expect(find.textContaining('treno'), findsNothing);
    // Girano: c'è sempre un fotogramma da disegnare (anche a schede ferme).
    await t.pump(const Duration(seconds: 1));
    expect(t.binding.hasScheduledFrame, isTrue);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 1));
    // Ferme: niente fotogrammi da disegnare.
    expect(t.binding.hasScheduledFrame, isFalse);
    await fine(t);
  });

  // Giro 7: i titoli si vedono solo con «Titoli automatici» (prove); spenti, la fascia ha una riga e l'aperta niente titolo.
  group('Titoli automatici spenti (di base)', () {
    setUp(() => Titoli.automatici.value = false);
    tearDown(() => Titoli.automatici.value = true);

    test('Non se ne propone nessuno', () async {
      estratto = {
        'stato': 'pronto',
        'frasi': [
          {'testo': 'passo a prendere i documenti', 'start': 0, 'end': 10},
        ],
      };
      for (final m in storia) {
        Titoli.proponi(Entry(m));
      }
      await pumpEventQueue();
      expect(chiamate.where((c) => c.method == 'estratto'), isEmpty);
    });

    for (final luce in Brightness.values) {
      testWidgets('La scheda: una riga sola (l\'ora, le iconcine, il cestino), centrata; niente titolo ($luce, testo grande)', (t) async {
        await telefono(t);
        await t.pumpWidget(app(const TrascriviPage(bottom: 76), testo: 1.6, luce: luce));
        await t.pumpAndSettle();
        expect(find.text('Il preventivo'), findsNothing);
        expect(find.text('Domani alle dieci passo a'), findsNothing);
        final scheda = find.byType(SchedaTrascrizione).first;
        final ora = t.getRect(find.descendant(of: scheda, matching: find.byType(SourceIcon)));
        final cestino = t.getRect(find.descendant(of: scheda, matching: find.byType(DeleteButton)));
        expect(ora.center.dy, moreOrLessEquals(cestino.center.dy, epsilon: 1));
        expect(t.getRect(scheda).height, SchedaTrascrizione.alta);
        await fine(t);
      });
    }

    testWidgets('La trascrizione aperta: niente titolo; in cima il giorno col cerchio del colore', (t) async {
      await telefono(t);
      await t.pumpWidget(
        app(Builder(builder: (context) => Center(child: TextButton(onPressed: () => openEntry(context, Entry(storia[1])), child: const Text('Apri'))))),
      );
      await t.tap(find.text('Apri'));
      await t.pumpAndSettle();
      expect(find.byType(TitoloModificabile), findsNothing);
      expect(find.text('Il preventivo'), findsNothing);
      expect(find.byType(CerchioColore), findsOneWidget);
      await fine(t);
    });
  });

  group('La privata (giro 7)', () {
    testWidgets('Le macchie restano dentro la copertura, sopra la fascia', (t) async {
      await telefono(t);
      storia = [storia[2]];
      await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
      await t.pumpAndSettle();
      final copertura = find.byType(CoperturaPrivata);
      final taglio = find.descendant(of: copertura, matching: find.byType(ClipRect));
      expect(taglio, findsOneWidget);
      expect(find.descendant(of: taglio, matching: find.byType(CustomPaint)), findsWidgets);
      final orario = find.descendant(of: find.byType(SchedaTrascrizione), matching: find.byType(DeleteButton));
      expect(t.getRect(copertura).bottom, lessThanOrEqualTo(t.getRect(orario).top));
      await fine(t);
    });

    testWidgets('Si fermano mentre la tieni premuta e con la trascrizione aperta sopra; poi ripartono', (t) async {
      await telefono(t);
      storia = [storia[2]];
      await t.pumpWidget(app(const TrascriviPage(bottom: 76), fermo: false));
      await t.pump(const Duration(milliseconds: 100));
      // Il giro delle macchie (il pittore lo tiene).
      bool gira() {
        final pittore = t.widget<CustomPaint>(find.descendant(of: find.byType(CoperturaPrivata), matching: find.byType(CustomPaint)).first).painter;
        return ((pittore as dynamic).giro as AnimationController).isAnimating;
      }

      expect(gira(), isTrue);
      // Premuta: ferma.
      final dito = await t.startGesture(t.getCenter(find.byType(CoperturaPrivata)));
      await t.pump(const Duration(milliseconds: 200));
      expect(gira(), isFalse);
      await dito.up();
      // Il tocco la apre: sotto la trascrizione aperta le macchie non girano.
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(CerchioColore), findsOneWidget);
      expect(gira(), isFalse);
      Navigator.of(t.element(find.byType(CerchioColore))).pop();
      await t.pump(const Duration(milliseconds: 600));
      expect(gira(), isTrue);
      await fine(t);
    });
  });
}
