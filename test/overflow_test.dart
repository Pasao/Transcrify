import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/barra_nota.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/dock.dart';
import 'package:transcrify/ui/molecole/fila_colori.dart';
import 'package:transcrify/ui/molecole/scheda_argomento.dart';
import 'package:transcrify/ui/molecole/tavolozza.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';

/// Niente deve sbordare: un overflow di Flutter fa fallire il test da solo. Si prova su un telefono
/// stretto, testo grande e la data più lunga. Il carattere dei test è più largo di quello vero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const channel = MethodChannel('transcrify/core');
  final old = DateTime(2026, 9, 30, 21, 10).millisecondsSinceEpoch;

  setUp(() {
    Core.live.value = const Live();
    TrascriviPage.scegliendo.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'history') {
        return [
          for (var i = 0; i < 5; i++)
            {'text': 'Una trascrizione di prova abbastanza lunga da riempire la scheda.', 'at': old - i, 'purified': true, 'mode': 'riassunto', 'source': 'whatsapp'},
        ];
      }
      return null;
    });
  });

  Widget app(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.dark),
    home: MediaQuery(
      data: const MediaQueryData(size: Size(360, 720), textScaler: TextScaler.linear(1.3)),
      child: Scaffold(body: child),
    ),
  );

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('Trascrivi, la trascrizione aperta e tutti gli stati della barra', (t) async {
    await phone(t);
    await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.textContaining('Una trascrizione').first);
    // Il primo fotogramma fa partire l'animazione, il secondo la porta in fondo.
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Detta qui'), findsOneWidget);
    // Il cestino armato si allarga: era lì il problema.
    await t.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Elimina'), findsOneWidget);
    // I ComandiVoce piccoli, col tempo e l'onda accanto; lavorando, il blob.
    for (final (live, cosa) in [
      (Live(phase: 'RECORDING', appendTo: old, seconds: 8), find.text('00:08')),
      (Live(phase: 'RECORDING', appendTo: old, paused: true), find.text('in pausa')),
      (Live(phase: 'PROCESSING', appendTo: old), find.byType(BlobLavoro)),
    ]) {
      Core.live.value = live;
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(cosa, findsOneWidget);
    }
    Core.live.value = const Live();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('La barra delle note, con la dettatura da incollare', (t) async {
    await phone(t);
    await t.pumpWidget(
      app(
        Align(
          alignment: Alignment.bottomCenter,
          child: BarraNota(
            undo: UndoHistoryController(),
            onGrassetto: () {},
            onCorsivo: () {},
            onElenco: () {},
            onLink: () {},
            dictation: Entry({'text': 'x', 'at': old, 'purified': false, 'mode': null}),
            onPaste: () {},
            topics: 2,
            onTopics: () {},
            onSlideStart: () {},
            onSlide: (_) {},
            onSlideEnd: () {},
            onSummarize: () {},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
  });

  // Il suo errore del 2 nov: scegliendo la prima trascrizione «ScrollController attached to multiple scroll views».
  testWidgets('Scegliere una trascrizione: niente errori, e la barra compare', (t) async {
    await phone(t);
    await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
    await t.pump(const Duration(milliseconds: 100));
    // Un gesto solo (5 nov): tenerla premuta la sceglie, e si comincia a scegliere. Niente menu.
    await t.longPress(find.textContaining('Una trascrizione').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Offusca'), findsOneWidget); // solo nella barra delle scelte, niente menu
    expect(find.byType(SelectionBar), findsOneWidget);
    expect(TrascriviPage.scegliendo.value, isTrue);
    expect(find.text('1 scelta'), findsOneWidget);
    expect(find.text('Tocca quelle da scegliere'), findsNothing);
    expect(find.byType(SpuntaScelta), findsWidgets);
    // La seconda esce appena dallo schermo: si tocca la parte che si vede.
    await t.tapAt(
      // (Il testo, non il titolo in fondo, che comincia uguale.)
      t.getRect(find.descendant(of: find.byType(Anteprima), matching: find.textContaining('Una trascrizione')).at(1)).topLeft +
          const Offset(Spazio.s4, Spazio.s4),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    for (final nome in [
      'Colore',
      'Copia',
      'Condividi',
      'Unisci',
      'Offusca',
      'Elimina',
    ]) {
      expect(find.text(nome), findsOneWidget, reason: nome);
    }
    expect(find.text('2 scelte'), findsOneWidget);
    // «Colore»: subito la rosa sopra il tasto (niente fila prima); la barra resta lì sotto. L'icona è la ruota dei colori.
    expect(find.descendant(of: find.byType(SelectionBar), matching: find.byType(RuotaColori)), findsOneWidget);
    await t.tap(find.text('Colore'));
    await t.pump();
    await t.pump(Durata.rosa);
    final barra = t.getRect(find.byType(SelectionBar));
    expect(find.byType(Tavolozza), findsOneWidget);
    expect(find.byType(FilaColori), findsNothing);
    expect(t.getRect(find.byType(Tavolozza)).bottom, lessThan(barra.top));
    expect(find.byType(BottomSheet), findsNothing);
    // Un tocco fuori la chiude (tenendo: non è cambiato niente, niente pillola), con la rosa che rientra.
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(find.byType(Tavolozza), findsNothing);
    expect(find.text('Colore cambiato'), findsNothing);
    // «Annulla» (la parola, non la X) chiude la scelta.
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await t.tap(find.widgetWithText(SelectionBar, 'Fine'));
    await t.pump();
    expect(TrascriviPage.scegliendo.value, isFalse);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets(
    '«Seleziona» (l\'interruttore del ⋮): la barra prende il posto del Dock, «indietro» chiude la scelta',
    (t) async {
      await phone(t);
      await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
      await t.pump(const Duration(milliseconds: 100));
      expect(Scelta.attiva.value, isFalse);
      // Il ⋮ dell'intestazione accende l'interruttore: si sceglie, ancora niente.
      TrascriviPage.scegliendo.value = true;
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SelectionBar), findsOneWidget);
      expect(find.text('Nessuna scelta'), findsOneWidget);
      // La barra sta nel posto del Dock: il suo bordo basso è quello del Dock (lo spazio che lascia meno la sua isola).
      expect(
        t.getRect(find.byType(SelectionBar)).bottom,
        720 - (76 - Misura.isola),
      );
      // Chi disegna il Dock lo sa, e si fa da parte.
      expect(Scelta.attiva.value, isTrue);
      // «Indietro» del telefono: finisce la scelta, non esce dall'app.
      expect(await t.binding.handlePopRoute(), isTrue);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(TrascriviPage.scegliendo.value, isFalse);
      expect(find.byType(SelectionBar), findsNothing);
      expect(Scelta.attiva.value, isFalse);
      // Senza scelta, «indietro» non è più suo.
      expect(
        t
            .widgetList<PopScope>(find.byWidgetPredicate((w) => w is PopScope))
            .every((p) => p.canPop),
        isTrue,
      );
      // Tenere premuta una scheda accende lo stesso interruttore; «Annulla» spegne tutto.
      await t.longPress(find.textContaining('Una trascrizione').first);
      await t.pump();
      expect(TrascriviPage.scegliendo.value, isTrue);
      await t.tap(find.widgetWithText(SelectionBar, 'Fine'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SelectionBar), findsNothing);
      expect(find.byType(SpuntaScelta), findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('La barra di selezione e il Dock', (t) async {
    await phone(t);
    await t.pumpWidget(
      app(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SelectionBar(
              quante: 100,
              onClose: () {},
              // Tutte quelle di Trascrivi: sei azioni coi nomi, su un telefono stretto col testo grande.
              actions: [
                SelectionBar.colore((_) {}),
                (Icons.content_copy_rounded, 'Copia', (_) {}),
                (Icons.share_rounded, 'Condividi', (_) {}),
                (Icons.call_merge_rounded, 'Unisci', (_) {}),
                (Offusca.icona, 'Offusca', (_) {}),
                (Icons.delete_outline_rounded, 'Elimina', (_) {}),
              ],
            ),
            Dock(
              power: Power.pensieri,
              onTocco: () {},
              onProssimo: () {},
              onTira: (_) {},
              nest: const SizedBox.square(dimension: Misura.tondo),
              action: (Icons.edit_rounded, 'Scrivi', () {}),
              pages: const [(Icons.notes_rounded, 'Note'), (Icons.bubble_chart_rounded, 'Argomenti')],
            ),
          ],
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Un grande concetto col mosaico dei sotto-argomenti', (t) async {
    await phone(t);
    Album album(int id, String name, int n) => Album({
      'id': id,
      'name': name,
      'concetto': 0,
      'pieces': [for (var i = 0; i < n; i++) {'note': 'n$i', 'start': 0, 'end': 5}],
    });
    await t.pumpWidget(
      app(
        SingleChildScrollView(
          child: SchedaArgomento(
            nome: 'Un concetto con un nome molto lungo che non ci sta',
            colore: Colors.orange,
            album: [album(1, 'Riunione · Progetto · Cliente importante', 12), album(2, 'Colleghi simpatici e antipatici', 4), album(3, 'Ferie', 1)],
            onApri: (_) {},
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('1 pezzo'), findsOneWidget);
  });
}
