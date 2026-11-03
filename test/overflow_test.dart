import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/dock.dart';
import 'package:transcrify/ui/molecole/intestazione.dart';
import 'package:transcrify/ui/molecole/riga_in_attesa.dart';
import 'package:transcrify/ui/molecole/scheda_argomento.dart';
import 'package:transcrify/ui/pensieri.dart';
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
    expect(find.text('Aggiungi a voce'), findsOneWidget);
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
          child: NoteToolbar(
            undo: UndoHistoryController(),
            onList: () {},
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
    await t.longPress(find.textContaining('Una trascrizione').first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    expect(find.byType(SelectionBar), findsOneWidget);
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
              label: '100 trascrizioni',
              onClose: () {},
              actions: [(Icons.content_copy_rounded, 'Copia', () {}), (Icons.share_rounded, 'Condividi', () {}), (Icons.delete_outline_rounded, 'Elimina', () {})],
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

  testWidgets("L'intestazione con le registrazioni in attesa, grande e ridotta", (t) async {
    await phone(t);
    for (final ridotta in [false, true]) {
      for (final riprovando in [false, true]) {
        await t.pumpWidget(
          app(
            Intestazione(
              titolo: 'Impostazioni',
              ridotta: ridotta,
              sotto: RigaInAttesa(quante: 12, riprovando: riprovando, onRiprova: () {}, onApri: () {}),
              accanto: const InAttesaCorto(quante: 12),
              azioni: [
                const ChipStato('Dati finti', tipo: TipoChip.azione),
                IconButton(onPressed: () {}, icon: const Icon(Icons.settings_rounded)),
              ],
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 500));
      }
    }
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
