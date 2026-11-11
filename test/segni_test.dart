import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/titoli.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/molecole/fila_colori.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/molecole/tavolozza.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';

/// Colore, privata e «Unisci» delle trascrizioni: la tavolozza si legge, i segni tornano dal nativo, l'unione segue l'ordine scelto
/// e «Annulla» rimette tutto com'era.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('transcrify/core');

  double contrasto(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
  }

  group('La tavolozza', () {
    test('16 tinte × 7 luci, quante ne sa il nativo (Colore.tinte, Colore.luci); il giro le mette in ordine', () {
      expect(Tinte.tonalita.length, Colore.tinte);
      expect(Tinte.nomi.length, Colore.tinte);
      expect(Tinte.luci.length, Colore.luci);
      // Le sette di prima restano dove sono: «tinta:luce» già salvato non cambia colore.
      expect(Tinte.tonalita.take(7), [4, 24, 46, 140, 192, 222, 275]);
      final gradi = [for (final t in Tinte.giro) Tinte.tonalita[t]];
      expect(gradi, [...gradi]..sort());
    });

    test('La rosa: 16 vivi fuori (tutte le tinte, a passo quasi uguale), 8 più chiari dentro, tutti della tavolozza', () {
      final fuori = Tinte.rosaFuori, dentro = Tinte.rosaDentro;
      expect(fuori, hasLength(16));
      expect(dentro, hasLength(8));
      expect(fuori.map((c) => c.$1).toSet(), hasLength(Colore.tinte));
      expect({...fuori, ...dentro}, hasLength(24));
      // Il passo tra due tinte vicine nel giro: tra 15° e 28° (22,5° sarebbe il passo uguale).
      final gradi = [for (final (t, _) in fuori) Tinte.tonalita[t]];
      for (var i = 0; i < gradi.length; i++) {
        final passo = (gradi[(i + 1) % gradi.length] - gradi[i]) % 360;
        expect(
          passo,
          inInclusiveRange(15, 28),
          reason:
              '${Tinte.nomi[fuori[i].$1]} → ${Tinte.nomi[fuori[(i + 1) % 16].$1]}',
        );
      }
      // Dentro più chiari di fuori, tinta per tinta.
      for (final (t, l) in dentro) {
        expect(
          Tinte.di(t, l).computeLuminance(),
          greaterThan(Tinte.di(t, Tinte.luceViva(t)).computeLuminance()),
          reason: Tinte.nomi[t],
        );
        expect(Colore.da(Colore(t, l).chiave), Colore(t, l));
      }
    });

    test('Il testo delle schede si legge su ogni tinta, chiaro e scuro (almeno 4,5:1)', () {
      for (final (luce, col) in [
        (Brightness.light, Colori.chiaro),
        (Brightness.dark, Colori.scuro),
      ]) {
        for (var t = 0; t < Colore.tinte; t++) {
          final fondo = Tinte.fondo(t, luce);
          for (final testo in [col.testo, col.testoSecondario]) {
            expect(
              contrasto(testo, fondo),
              greaterThanOrEqualTo(4.5),
              reason: '${Tinte.nomi[t]} $luce',
            );
          }
          // Il lucchetto (un'icona: almeno 3:1) sulla copertura della privata.
          expect(
            contrasto(col.testo, Tinte.fondoGiu(t, luce)),
            greaterThanOrEqualTo(3),
            reason: 'lucchetto ${Tinte.nomi[t]} $luce',
          );
        }
      }
    });

    test('Nel tema scuro il dorso delle cartelle si stacca dalla pagina (≥1,5:1) e dal davanti (≥1,25:1), ogni tinta (6 nov: il rosso era la pagina)', () {
      for (var t = 0; t < Colore.tinte; t++) {
        final dorso = Tinte.dorso(t, Brightness.dark),
            davanti = Tinte.fondo(t, Brightness.dark);
        expect(
          contrasto(dorso, Colori.scuro.pagina),
          greaterThanOrEqualTo(1.5),
          reason: 'dorso/pagina ${Tinte.nomi[t]}',
        );
        expect(
          contrasto(dorso, davanti),
          greaterThanOrEqualTo(1.25),
          reason: 'dorso/davanti ${Tinte.nomi[t]}',
        );
        // Più chiaro del davanti: scurito si confondeva col marrone della pagina.
        expect(
          dorso.computeLuminance(),
          greaterThan(davanti.computeLuminance()),
          reason: Tinte.nomi[t],
        );
      }
      // Nel chiaro resta com'era: il dorso una luce più scura del davanti.
      for (var t = 0; t < Colore.tinte; t++) {
        expect(
          Tinte.dorso(t, Brightness.light).computeLuminance(),
          lessThan(Tinte.fondo(t, Brightness.light).computeLuminance()),
          reason: Tinte.nomi[t],
        );
      }
    });

    test('Nel tema scuro i fondi sono tenui, non pesanti (5 nov: «bordeaux»); i puntini restano pieni', () {
      for (var t = 0; t < Colore.tinte; t++) {
        expect(
          HSLColor.fromColor(Tinte.fondo(t, Brightness.dark)).saturation,
          lessThanOrEqualTo(0.3),
          reason: Tinte.nomi[t],
        );
        expect(
          HSLColor.fromColor(Tinte.fondoGiu(t, Brightness.dark)).saturation,
          lessThanOrEqualTo(0.3),
          reason: Tinte.nomi[t],
        );
        expect(
          HSLColor.fromColor(Tinte.dorso(t, Brightness.dark)).saturation,
          lessThanOrEqualTo(0.3),
          reason: Tinte.nomi[t],
        );
        expect(
          HSLColor.fromColor(Tinte.di(t, Tinte.luceFila)).saturation,
          greaterThan(0.5),
          reason: Tinte.nomi[t],
        );
      }
    });

    test('Il rosso del pericolo si legge dove sta (almeno 4,5:1): sulla barra scura, sulle schede, nel chiaro e nello scuro', () {
      // La barra delle scelte e «Annulla» stanno sul floater, sempre scuro: prendono i token scuri (Colori.sospesi).
      for (final col in [Colori.chiaro, Colori.scuro]) {
        expect(
          contrasto(Colori.sospesi.errore, col.floater),
          greaterThanOrEqualTo(4.5),
          reason: 'Elimina sulla barra',
        );
        expect(
          contrasto(Colori.sospesi.azione, col.floater),
          greaterThanOrEqualTo(4.5),
          reason: '«Annulla» sul floater',
        );
      }
      // Nell'app, ogni tema col suo: sulla pagina, sulle schede, sulle isole e sul fondo del cestino armato.
      for (final col in [Colori.chiaro, Colori.scuro]) {
        for (final fondo in [
          col.pagina,
          col.scheda,
          col.isola,
          col.erroreTenue,
        ]) {
          expect(
            contrasto(col.errore, fondo),
            greaterThanOrEqualTo(4.5),
            reason: '$fondo',
          );
        }
      }
    });

    test('«tinta:luce» va e torna; quello che non è della tavolozza è nessun colore', () {
      expect(Colore.da(const Colore(3, 4).chiave), const Colore(3, 4));
      for (final x in [null, '', '16:0', '0:-1', 'rosso', '1:2:3']) {
        expect(Colore.da(x), isNull, reason: '$x');
      }
    });
  });

  group('Col nativo (finto)', () {
    final a = DateTime(2026, 11, 4, 9).millisecondsSinceEpoch,
        b = a + 1000,
        c = a + 2000;
    late List<Map<String, Object?>> storia;
    late List<MethodCall> chiamate;

    setUp(() {
      Core.live.value = const Live();
      TrascriviPage.scegliendo.value = false;
      chiamate = [];
      storia = [
        // Una di prima dei colori: senza «colore» né «privata».
        {
          'text': 'Terza, la più nuova.',
          'at': c,
          'purified': true,
          'mode': 'pulita',
          'source': null,
        },
        {
          'text': 'Seconda.',
          'at': b,
          'purified': false,
          'mode': null,
          'source': null,
          'colore': '5:1',
          'privata': false,
        },
        {
          'text': 'Prima, la più vecchia.',
          'at': a,
          'purified': true,
          'mode': 'fedele',
          'source': null,
          'colore': null,
          'privata': true,
        },
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            chiamate.add(call);
            final args = call.arguments is Map
                ? call.arguments as Map
                : const {};
            switch (call.method) {
              case 'history':
                return [
                  for (final m in storia) {...m},
                ];
              case 'segnaHistory':
                final ats = (args['ats'] as List).cast<int>();
                for (final m in storia) {
                  if (!ats.contains(m['at'])) continue;
                  if (args.containsKey('colore')) m['colore'] = args['colore'];
                  if (args.containsKey('privata')) m['privata'] = args['privata'];
                }
              case 'unisciHistory':
                // Come Ritocchi.kt (provato nel Kotlin): i testi nell'ordine, la più vecchia dà il giorno, la prima il resto.
                final ordine = (args['ats'] as List).cast<int>();
                final scelte = [
                  for (final at in ordine)
                    storia.firstWhere((m) => m['at'] == at),
                ];
                final fusa = {
                  ...scelte.first,
                  'text': scelte.map((m) => m['text']).join('\n\n'),
                  'at': ordine.reduce((x, y) => x < y ? x : y),
                };
                storia = [
                  ...storia.where((m) => !ordine.contains(m['at'])),
                  fusa,
                ]..sort((x, y) => (y['at'] as int).compareTo(x['at'] as int));
                return fusa;
              case 'rimettiHistory':
                final voci = (args['voci'] as List).cast<Map>();
                final loro = voci.map((m) => m['at']).toSet();
                storia = [
                  ...storia.where((m) => !loro.contains(m['at'])),
                  for (final m in voci) m.cast<String, Object?>(),
                ]..sort((x, y) => (y['at'] as int).compareTo(x['at'] as int));
              case 'nomiColori':
                return <String, String>{};
            }
            return null;
          });
    });

    test('Colore e privata tornano dal nativo; quelle di prima dei colori non ne hanno', () async {
      var voci = await Core.history();
      expect(voci.map((e) => e.colore), [null, const Colore(5, 1), null]);
      expect(voci.map((e) => e.privata), [false, false, true]);

      await Segni.colora([
        DateTime.fromMillisecondsSinceEpoch(c),
        DateTime.fromMillisecondsSinceEpoch(a),
      ], const Colore(2, 4));
      await Segni.rendiPrivate([DateTime.fromMillisecondsSinceEpoch(c)], true);
      voci = await Core.history();
      expect(voci.map((e) => e.colore), [
        const Colore(2, 4),
        const Colore(5, 1),
        const Colore(2, 4),
      ]);
      expect(voci.map((e) => e.privata), [true, false, true]);
      // Rimandata indietro (l'«Annulla»), una trascrizione resta identica.
      for (final e in voci) {
        expect(Entry(e.toMap()), e);
      }
    });

    /// La rosa si chiude (i due anelli rientrano, poi il fumetto): senza aspettare la pillola, che se ne andrebbe.
    Future<void> chiusa(WidgetTester t) async {
      await t.pump();
      await t.pump(Durata.rosa + Durata.veloce);
      await t.pump(Durata.veloce);
      await t.pump(Durata.veloce);
    }

    Widget app(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: MediaQuery(
        // Le macchie della privata girano sempre: ferme qui, per aspettare la fine dei movimenti.
        data: const MediaQueryData(size: Size(900, 800), disableAnimations: true),
        child: Scaffold(body: child),
      ),
    );

    testWidgets(
      'Su un telefono stretto, testo grande: la scelta del colore senza sbordare',
      (t) async {
        t.view.physicalSize = const Size(360, 720);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        Widget stretto(Widget child) => MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 720),
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: Scaffold(body: child),
          ),
        );
        await t.pumpWidget(stretto(const TrascriviPage(bottom: 76)));
        await t.pump(const Duration(milliseconds: 100));
        // Tenuta premuta: scelta. «Colore» nella barra: subito la rosa sopra il tasto, niente fila.
        await t.longPress(find.text('Terza, la più nuova.'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('1 scelta'), findsOneWidget);
        await t.tap(find.text('Colore'));
        await t.pumpAndSettle();
        expect(find.byType(Tavolozza), findsOneWidget);
        expect(find.byType(FilaColori), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(t.getRect(find.byType(Tavolozza)).bottom, lessThan(t.getRect(find.byType(SelectionBar)).top));
        expect(t.getRect(find.byType(Tavolozza)).right, lessThanOrEqualTo(360));
        // Un tocco colora subito (si vede sulla scheda): l'anello e la spunta, il nome in alto, il campo del nome.
        await t.tap(find.byTooltip('Orchidea'));
        await t.pump();
        var segno = chiamate.lastWhere((x) => x.method == 'segnaHistory');
        expect((segno.arguments as Map)['colore'], '13:4');
        expect((segno.arguments as Map)['ats'], [c]);
        expect(storia.first['colore'], '13:4');
        final scelto = find.ancestor(of: find.byIcon(Icons.check_rounded), matching: find.byType(PuntoColore));
        expect(t.widget<PuntoColore>(scelto).etichetta, 'Orchidea');
        expect(find.text('Che nome ha questa etichetta?'), findsOneWidget);
        // «Annulla» nella rosa: torna tutto com'era, anche il nome scritto (non si salva).
        await t.enterText(find.byType(TextField).first, 'Relazioni');
        await t.tap(find.descendant(of: find.byType(Tavolozza), matching: find.text('Annulla')));
        await t.pumpAndSettle();
        expect(find.byType(Tavolozza), findsNothing);
        expect(storia.first['colore'], isNull);
        expect(chiamate.where((x) => x.method == 'nomeColore'), isEmpty);
        expect(find.byType(PillolaAnnulla), findsNothing);
        // «Fatto»: si tiene, col nome; poi la pillola «Colore cambiato», e il suo «Annulla» rimette colore e nome.
        await t.tap(find.text('Colore'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Orchidea'));
        await t.pump();
        await t.enterText(find.byType(TextField).first, 'Relazioni');
        await t.tap(find.text('Fatto'));
        await chiusa(t);
        expect(find.byType(Tavolozza), findsNothing);
        expect(storia.first['colore'], '13:4');
        expect((chiamate.lastWhere((x) => x.method == 'nomeColore').arguments as Map)['nome'], 'Relazioni');
        expect(find.text('Colore cambiato'), findsOneWidget);
        await t.tap(find.descendant(of: find.byType(PillolaAnnulla), matching: find.text('Annulla')));
        await t.pumpAndSettle();
        expect(storia.first['colore'], isNull);
        final nome = chiamate.lastWhere((x) => x.method == 'nomeColore').arguments as Map;
        expect((nome['colore'], nome['nome']), ('13:4', ''));
        segno = chiamate.lastWhere((x) => x.method == 'segnaHistory');
        expect((segno.arguments as Map)['ats'], [c]);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('Tante di colori diversi: la stessa rosa; un tocco fuori tiene, la pillola rimette a ognuna il suo', (t) async {
      t.view.physicalSize = const Size(900, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
      await t.pump(const Duration(milliseconds: 100));
      await t.longPress(find.text('Terza, la più nuova.'));
      await t.pump();
      await t.tap(find.text('Seconda.'));
      await t.pump(Durata.scelta);
      expect(find.text('2 scelte'), findsOneWidget);
      await t.tap(find.text('Colore'));
      await t.pumpAndSettle();
      expect(find.text('Colori diversi'), findsOneWidget);
      await t.tap(find.byTooltip('Rosso'));
      await t.pump();
      expect([for (final m in storia) m['colore']], ['0:4', '0:4', null]);
      // Un tocco fuori: si tiene (è cambiato qualcosa: arriva la pillola).
      await t.tapAt(const Offset(4, 4));
      await chiusa(t);
      expect(find.byType(Tavolozza), findsNothing);
      expect([for (final m in storia) m['colore']], ['0:4', '0:4', null]);
      await t.tap(find.descendant(of: find.byType(PillolaAnnulla), matching: find.text('Annulla')));
      await t.pumpAndSettle();
      // Ognuna col suo colore di prima: la terza senza, la seconda blu.
      expect([for (final m in storia) m['colore']], [null, '5:1', null]);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets("Una trascrizione aperta: il cerchio apre la stessa rosa; «Annulla» la lascia com'era", (t) async {
      t.view.physicalSize = const Size(900, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
      await t.pump(const Duration(milliseconds: 100));
      await t.tap(find.text('Seconda.'));
      await t.pumpAndSettle();
      await t.tap(find.byType(CerchioColore));
      await t.pumpAndSettle();
      expect(find.byType(Tavolozza), findsOneWidget);
      expect(find.byType(FilaColori), findsNothing);
      expect(find.text('Blu 2'), findsWidgets);
      await t.tap(find.byTooltip('Rosso'));
      await t.pump();
      expect(storia[1]['colore'], '0:4');
      await t.tap(find.descendant(of: find.byType(Tavolozza), matching: find.text('Annulla')));
      await t.pumpAndSettle();
      expect(storia[1]['colore'], '5:1');
      // «Fatto» tiene; la pillola rimette.
      await t.tap(find.byType(CerchioColore));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close_rounded));
      await t.pump();
      await t.tap(find.text('Fatto'));
      await chiusa(t);
      expect(storia[1]['colore'], isNull);
      await t.tap(find.descendant(of: find.byType(PillolaAnnulla), matching: find.text('Annulla')));
      await t.pumpAndSettle();
      expect(storia[1]['colore'], '5:1');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'Tutte le schede hanno la stessa forma: il testo sopra, in fondo la fascia dell\'ora (una riga, giro 7), alta uguale',
      (t) async {
        t.view.physicalSize = const Size(900, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
        await t.pump(const Duration(milliseconds: 100));
        final schede = find.byType(SchedaTrascrizione);
        expect(schede, findsNWidgets(3));
        // Dal fondo della scheda: dove sta il cestino e dove l'ora (sulla stessa riga). Uguale su tutte.
        final misure = <(double, double)>{};
        double? fasciaPrivata;
        for (var i = 0; i < 3; i++) {
          final scheda = t.getRect(schede.at(i));
          expect(scheda.height, SchedaTrascrizione.alta);
          final entry = t.widget<SchedaTrascrizione>(schede.at(i)).entry;
          final cestino = t.getRect(find.descendant(of: schede.at(i), matching: find.byType(DeleteButton)));
          final ora = t.getRect(find.descendant(of: schede.at(i), matching: find.text(hm(entry.at))));
          misure.add(((scheda.bottom - cestino.center.dy).roundToDouble(), (scheda.bottom - ora.center.dy).roundToDouble()));
          // Dove comincia la fascia: la riga del titolo (7 nov: il cestino sta sotto, con l'ora).
          if (entry.privata) fasciaPrivata = t.getRect(find.descendant(of: schede.at(i), matching: find.text(Titoli.di(entry)))).top;
        }
        expect(misure, hasLength(1));
        // La privata: le macchie col lucchetto coprono solo la parte del testo, fino alla fascia (che resta).
        expect(t.getRect(find.byType(CoperturaPrivata)).bottom, closeTo(fasciaPrivata! - Spazio.s2, 1));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'Unisci, colori diversi: si sceglie il colore e si unisce subito; «Annulla» al contrario rimette tutto',
      (t) async {
        t.view.physicalSize = const Size(900, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final prima = [
          for (final m in storia) {...m},
        ];
        await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
        await t.pump(const Duration(milliseconds: 100));

        // La seconda tenuta premuta, poi la prima (privata: si tocca l'occhio) e la terza: l'ordine dei tocchi.
        await t.longPress(find.text('Seconda.'));
        await t.pump();
        await t.tap(find.byIcon(Offusca.icona).first);
        await t.pump();
        await t.tap(find.text('Terza, la più nuova.'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('3 scelte'), findsOneWidget);
        // Colori diversi (blu e nessuno): prima i soli colori in gioco, niente «+»; nessuna unione ancora.
        await t.tap(find.text('Unisci'));
        await t.pumpAndSettle();
        expect(find.byType(FilaColori), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FilaColori),
            matching: find.byType(PuntoColore),
          ),
          findsNWidgets(2),
        );
        expect(find.byTooltip('Tutti i colori e il nome'), findsNothing);
        expect(chiamate.where((x) => x.method == 'unisciHistory'), isEmpty);
        // Un tocco sceglie il colore e unisce: niente «Unisci N» da confermare.
        await t.tap(find.byTooltip('Blu 2'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('Trascrizioni fuse'), findsNothing);
        for (var i = 0; i < 14; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        final unione = chiamate.lastWhere((x) => x.method == 'unisciHistory');
        expect((unione.arguments as Map)['ats'], [b, a, c]);
        final segno = chiamate.lastWhere((x) => x.method == 'segnaHistory');
        expect((segno.arguments as Map)['ats'], [a]);
        expect((segno.arguments as Map)['colore'], '5:1');
        expect(
          storia.single['text'],
          'Seconda.\n\nPrima, la più vecchia.\n\nTerza, la più nuova.',
        );
        expect(storia.single['colore'], '5:1');
        expect(find.text('Trascrizioni fuse'), findsOneWidget);
        expect(find.byType(SelectionBar), findsNothing);

        // «Annulla»: il volo al contrario. Mentre vola, le schede vere sono nascoste sotto le copie.
        await t.tap(find.text('Annulla'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.pump(const Duration(milliseconds: 100));
        expect(
          t
              .widgetList<SchedaTrascrizione>(find.byType(SchedaTrascrizione))
              .where((s) => s.nascosta),
          isNotEmpty,
        );
        for (var i = 0; i < 14; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        // Alla fine: esattamente com'erano, anche i segni, e tutte di nuovo visibili ai loro posti.
        expect(
          storia
              .map(
                (m) => {
                  ...m,
                  'colore': m['colore'],
                  'privata': m['privata'] ?? false,
                  'titolo': m['titolo'],
                  'titoloChiesto': m['titoloChiesto'] ?? false,
                  'coloreAuto': m['coloreAuto'] ?? false,
                  'titoloUtente': m['titoloUtente'] ?? false,
                },
              )
              .toList(),
          [
            for (final m in prima)
              {
                ...m,
                'colore': m['colore'],
                'privata': m['privata'] ?? false,
                'titolo': m['titolo'],
                'titoloChiesto': m['titoloChiesto'] ?? false,
                'coloreAuto': m['coloreAuto'] ?? false,
                'titoloUtente': m['titoloUtente'] ?? false,
              },
          ],
        );
        final vere = t
            .widgetList<SchedaTrascrizione>(find.byType(SchedaTrascrizione))
            .where((s) => s.width == SchedaTrascrizione.larga);
        expect(vere.length, 3);
        expect(vere.every((s) => !s.nascosta), isTrue);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('Unisci, stesso colore: si unisce subito, senza domande', (
      t,
    ) async {
      t.view.physicalSize = const Size(900, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
      await t.pump(const Duration(milliseconds: 100));
      await t.longPress(find.text('Terza, la più nuova.'));
      await t.pump();
      await t.tap(find.byIcon(Offusca.icona).first);
      // La barra sale al posto del Dock: si tocca quando è arrivata.
      await t.pump(Durata.scelta);
      await t.tap(find.text('Unisci'));
      await t.pump();
      expect(find.byType(FilaColori), findsNothing);
      for (var i = 0; i < 14; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        (chiamate.lastWhere((x) => x.method == 'unisciHistory').arguments
            as Map)['ats'],
        [c, a],
      );
      expect(chiamate.where((x) => x.method == 'segnaHistory'), isEmpty);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  });
}
