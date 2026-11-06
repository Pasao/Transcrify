import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/cartelle.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/dock.dart';
import 'package:transcrify/ui/molecole/cartella.dart';
import 'package:transcrify/ui/molecole/fascia_cartella.dart';
import 'package:transcrify/ui/molecole/fila_schede.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/molecole/titolo_giorno.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';

/// Le cartelle (6 nov, sua scelta: «solo cartelle che si aprono»): la pagina mostra solo le cartelle disegnate, due
/// per riga, più alte che larghe. Toccata, una cartella si apre lì dov'era (6 nov, giro 6): una fascia del suo colore,
/// allargandosi da lei, con le sue schede in fila; una sola alla volta; il nome si cambia lì. Tenendo premuta una cartella la si sceglie: la barra prende il
/// posto del Dock, Rinomina è un dialogo (Annulla · Rinomina), «Togli cartella» si annulla. «Indietro» chiude la scelta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const channel = MethodChannel('transcrify/core');
  final at = DateTime(2026, 11, 5, 9).millisecondsSinceEpoch;
  const giorno = 24 * 60 * 60 * 1000;

  late List<Map<String, Object?>> storia;
  late Map<String, String> nomi;
  late List<MethodCall> chiamate;

  Map<String, Object?> voce(String testo, int dopo, String? colore, {bool privata = false}) =>
      {'text': testo, 'at': at + dopo, 'purified': true, 'mode': null, 'source': null, 'colore': colore, 'privata': privata};

  setUp(() {
    Core.live.value = const Live();
    Segni.nomi.value = const {};
    TrascriviPage.scegliendo.value = false;
    chiamate = [];
    nomi = {};
    storia = [
      voce('Visibile, la più nuova del blu.', 3, '5:4'),
      voce('Segreto da non vedere.', 2, '5:4', privata: true),
      voce('Una gialla.', 1, '2:4'),
      voce('Senza colore.', 0, null),
      // Un blu del giorno prima: la cartella aperta va per giorni, come Trascrivi.
      voce('Blu di ieri.', -giorno, '5:4'),
    ];
    // Il nativo finto: tiene colori, nomi e «Annulla» come Store.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      chiamate.add(call);
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'history':
          return [for (final m in storia) {...m}];
        case 'segnaHistory':
          final ats = (args['ats'] as List).cast<int>();
          for (final m in storia) {
            if (ats.contains(m['at']) && args.containsKey('colore')) m['colore'] = args['colore'];
          }
        case 'rimettiHistory':
          final voci = (args['voci'] as List).cast<Map>();
          final loro = voci.map((m) => m['at']).toSet();
          storia = [
            ...storia.where((m) => !loro.contains(m['at'])),
            for (final m in voci) m.cast<String, Object?>(),
          ]..sort((x, y) => (y['at'] as int).compareTo(x['at'] as int));
        case 'nomiColori':
          return {...nomi};
        case 'nomeColore':
          final nome = (args['nome'] as String).trim();
          nome.isEmpty ? nomi.remove(args['colore']) : nomi[args['colore'] as String] = nome;
      }
      return null;
    });
  });

  Future<void> telefono(WidgetTester t, {double testo = 1.3, Brightness luce = Brightness.dark}) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(luce),
        // Le macchie della privata girano sempre: ferme, come con «riduci le animazioni», per aspettare la fine dei movimenti.
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(testo), disableAnimations: true), child: child!),
        home: const Scaffold(body: CartellePage(bottom: Dock.height)),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> chiudi(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  }

  /// Apre la cartella (lì dov'era) e aspetta che si sia allargata.
  Future<void> apri(WidgetTester t, String nome) async {
    await t.tap(find.widgetWithText(Cartella, nome));
    await t.pump();
    // A metà: la fascia si sta allargando, senza errori.
    await t.pump(const Duration(milliseconds: 150));
    expect(find.byType(FasciaCartella), findsOneWidget);
    await t.pumpAndSettle();
  }

  for (final luce in Brightness.values) {
    testWidgets('Stretto e testo grande ($luce): solo le cartelle, due per riga, più alte che larghe', (t) async {
      await telefono(t, testo: 1.6, luce: luce);
      final cartelle = find.byType(Cartella);
      expect(cartelle, findsNWidgets(2));
      // Due per riga, nella stessa riga e larghe uguali; in piedi.
      // Nell'ordine della tavolozza: il giallo prima del blu.
      final blu = t.getRect(find.widgetWithText(Cartella, 'Blu')), giallo = t.getRect(find.widgetWithText(Cartella, 'Giallo'));
      expect(blu.top, giallo.top);
      expect(blu.width, giallo.width);
      expect(blu.left, greaterThan(giallo.right));
      expect(blu.height, greaterThan(blu.width));
      // Solo le cartelle: niente sezioni, niente schede, niente titoli dei giorni.
      expect(find.byType(SchedaTrascrizione), findsNothing);
      expect(find.byType(TitoloGiorno), findsNothing);
      expect(find.textContaining('Senza colore'), findsNothing);
      // Premuta si apre un poco, lasciata si richiude: niente sborda.
      final g = await t.startGesture(blu.center);
      await t.pump(const Duration(milliseconds: 200));
      await g.cancel();
      await t.pump(const Duration(milliseconds: 200));
      await chiudi(t);
    });
  }

  for (final luce in Brightness.values) {
    testWidgets('Toccata, la cartella si apre lì ($luce): una fascia del suo colore, le schede in fila, le altre sotto; la X la richiude', (t) async {
      await telefono(t, testo: 1.6, luce: luce);
      await apri(t, 'Blu');
      final fascia = find.byType(FasciaCartella);
      expect(fascia, findsOneWidget);
      // Larga quanto la pagina, nel colore del dorso della cartella.
      final r = t.getRect(fascia);
      expect(r.width, 360);
      final contesto = t.element(fascia);
      expect(
        find.descendant(
          of: fascia,
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == Tinte.dorso(5, luce)),
        ),
        findsOneWidget,
      );
      expect(Theme.of(contesto).brightness, luce);
      // Le sue trascrizioni, schede normali in una fila che scorre di lato; niente giorni.
      final fila = t.widget<FilaSchede>(find.descendant(of: fascia, matching: find.byType(FilaSchede)));
      expect(fila.voci.map((e) => e.text), ['Visibile, la più nuova del blu.', 'Segreto da non vedere.', 'Blu di ieri.']);
      final schede = t.widgetList<SchedaTrascrizione>(find.descendant(of: fascia, matching: find.byType(SchedaTrascrizione))).toList();
      expect(schede, isNotEmpty);
      expect(schede.every((s) => s.width == SchedaTrascrizione.larga), isTrue);
      expect(find.byType(TitoloGiorno), findsNothing);
      // La gialla (prima, nella stessa riga) scende sotto la fascia; la blu non c'è più come cartella.
      expect(find.widgetWithText(Cartella, 'Blu'), findsNothing);
      expect(t.getRect(find.widgetWithText(Cartella, 'Giallo')).top, greaterThan(r.bottom));
      // La X la richiude: tornano le due cartelle.
      await t.tap(find.byTooltip('Chiudi la cartella'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await t.pumpAndSettle();
      expect(fascia, findsNothing);
      expect(find.byType(Cartella), findsNWidgets(2));
      await chiudi(t);
    });
  }

  testWidgets('Aperta, si allarga dalla cartella toccata; una sola aperta alla volta', (t) async {
    await telefono(t);
    final blu = t.getRect(find.widgetWithText(Cartella, 'Blu'));
    await t.tap(find.widgetWithText(Cartella, 'Blu'));
    await t.pump();
    // All'inizio il colore sta nel riquadro della cartella (a destra), poi arriva ai bordi.
    final colore = find.descendant(of: find.byType(FasciaCartella), matching: find.byType(DecoratedBox)).first;
    expect(t.getRect(colore).left, closeTo(blu.left, 1));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getRect(colore).left, inExclusiveRange(0, blu.left));
    await t.pumpAndSettle();
    expect(t.getRect(colore).left, 0);
    // Toccata l'altra, si apre lei e la prima torna cartella.
    await t.tap(find.widgetWithText(Cartella, 'Giallo'));
    await t.pumpAndSettle();
    expect(find.byType(FasciaCartella), findsOneWidget);
    expect(find.descendant(of: find.byType(FasciaCartella), matching: find.text('Una gialla.')), findsOneWidget);
    expect(find.widgetWithText(Cartella, 'Blu'), findsOneWidget);
    await chiudi(t);
  });

  testWidgets('Il nome si cambia lì (Annulla · Fatto), salvato nel nativo; tenendo premuta un\'altra si sceglie e la fascia si chiude', (t) async {
    await telefono(t, testo: 1.5, luce: Brightness.light);
    await apri(t, 'Blu');
    final fascia = find.byType(FasciaCartella);
    await t.tap(find.descendant(of: fascia, matching: find.text('Blu')));
    await t.pumpAndSettle();
    // «Annulla»: niente cambia.
    expect(find.byType(TextField), findsOneWidget);
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(chiamate.where((c) => c.method == 'nomeColore'), isEmpty);
    await t.tap(find.descendant(of: fascia, matching: find.text('Blu')));
    await t.pumpAndSettle();
    final campo = t.widget<TextField>(find.byType(TextField));
    // Già pronto: il nome di adesso, tutto scelto (si scrive sopra).
    expect(campo.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    await t.enterText(find.byType(TextField), 'Lavoro');
    await t.tap(find.text('Fatto'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(chiamate.lastWhere((c) => c.method == 'nomeColore').arguments, {'colore': '5:4', 'nome': 'Lavoro'});
    expect(find.descendant(of: fascia, matching: find.text('Lavoro')), findsOneWidget);
    // Tenendo premuta la gialla si comincia a scegliere: la fascia si richiude.
    await t.longPress(find.widgetWithText(Cartella, 'Giallo'));
    await t.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(fascia, findsNothing);
    await chiudi(t);
  });

  testWidgets('Dalla fascia: il cestino elimina con «Annulla»; la scheda toccata si apre', (t) async {
    await telefono(t);
    await apri(t, 'Blu');
    final fascia = find.byType(FasciaCartella);
    final scheda = find.ancestor(of: find.text('Visibile, la più nuova del blu.'), matching: find.byType(SchedaTrascrizione));
    final cestino = find.descendant(of: scheda, matching: find.byType(DeleteButton));
    await t.tap(cestino);
    await t.pump();
    await t.tap(cestino);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: fascia, matching: find.text('Visibile, la più nuova del blu.')), findsNothing);
    await t.tap(find.text('Annulla').last);
    await t.pumpAndSettle();
    expect(chiamate.where((c) => c.method == 'deleteHistory'), isEmpty);
    expect(find.descendant(of: fascia, matching: find.text('Visibile, la più nuova del blu.')), findsOneWidget);
    await t.tap(find.descendant(of: fascia, matching: find.text('Visibile, la più nuova del blu.')));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await chiudi(t);
  });
  testWidgets('Tenuta premuta la cartella si sceglie; Rinomina è un dialogo (Annulla · Rinomina), salvato nel nativo', (t) async {
    await telefono(t);
    await t.longPress(find.widgetWithText(Cartella, 'Giallo'));
    await t.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(find.text('1 scelta'), findsOneWidget);
    expect(find.bySemanticsLabel('Togli cartella'), findsOneWidget);
    expect(Scelta.attiva.value, isTrue);

    // «Annulla» nel dialogo: niente cambia.
    await t.tap(find.bySemanticsLabel('Rinomina'));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Annulla')));
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(chiamate.where((c) => c.method == 'nomeColore'), isEmpty);

    await t.tap(find.bySemanticsLabel('Rinomina'));
    await t.pumpAndSettle();
    // Come in Samsung: il titolo, il campo già pronto (vuoto, il nome di adesso come suggerimento), Annulla a sinistra,
    // Rinomina a destra, spento finché non c'è un nome nuovo.
    final dialogo = find.byType(Dialog);
    expect(find.descendant(of: dialogo, matching: find.text('Rinomina')), findsNWidgets(2));
    final campo = t.widget<TextField>(find.byType(TextField));
    expect(campo.controller!.text, isEmpty);
    expect(campo.decoration!.hintText, 'Giallo');
    expect(t.state<EditableTextState>(find.byType(EditableText)).widget.focusNode.hasFocus, isTrue);
    final annulla = find.descendant(of: dialogo, matching: find.widgetWithText(TextButton, 'Annulla'));
    final rinomina = find.descendant(of: dialogo, matching: find.widgetWithText(TextButton, 'Rinomina'));
    expect(t.getCenter(annulla).dx, lessThan(t.getCenter(rinomina).dx));
    expect(t.widget<TextButton>(rinomina).onPressed, isNull);
    await t.enterText(find.byType(TextField), '  Da copiare ');
    await t.pump();
    await t.tap(rinomina);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final salvato = chiamate.lastWhere((c) => c.method == 'nomeColore');
    expect(salvato.arguments, {'colore': '2:4', 'nome': 'Da copiare'});
    expect(find.widgetWithText(Cartella, 'Da copiare'), findsOneWidget);
    // Rinominata, la scelta finisce (come in Samsung).
    expect(find.byType(SelectionBar), findsNothing);
    // Riletto dal nativo (come all'avvio): è ancora lì.
    Segni.nomi.value = const {};
    await Segni.leggiNomi();
    expect(Segni.nomi.value, {'2:4': 'Da copiare'});
    await t.pump();

    // «Indietro» mentre si scelgono cartelle: finisce la scelta.
    await t.longPress(find.widgetWithText(Cartella, 'Blu'));
    await t.pumpAndSettle();
    expect(find.byType(SelectionBar), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(SelectionBar), findsNothing);
    expect(find.byType(Cartella), findsNWidgets(2));
    await chiudi(t);
  });

  testWidgets('«Togli cartella»: le trascrizioni restano senza colore, e «Annulla» la rimette', (t) async {
    await telefono(t);
    await t.longPress(find.widgetWithText(Cartella, 'Blu'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Togli cartella'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(Cartella, 'Blu'), findsNothing);
    expect(storia.where((m) => m['colore'] == '5:4'), isEmpty);
    expect(storia, hasLength(5));

    await t.tap(find.text('Annulla').last);
    await t.pumpAndSettle();
    expect(find.widgetWithText(Cartella, 'Blu'), findsOneWidget);
    expect(storia.where((m) => m['colore'] == '5:4'), hasLength(3));
    await chiudi(t);
  });


  testWidgets('Senza colori: le sagome di due cartelle vuote e la frase', (t) async {
    storia = [voce('Senza colore.', 0, null)];
    await telefono(t);
    expect(find.byType(Cartella), findsNothing);
    expect(find.textContaining('Dai un colore'), findsOneWidget);
    await chiudi(t);
  });
}
