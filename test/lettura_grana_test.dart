import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/molecole/testo_evidenziato.dart';
import 'package:transcrify/ui/pensieri.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/transcri.dart';

/// Il carattere per leggere (Onest), l'incavo del nido quando Transcri è fuori, le tre grane degli argomenti.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('transcrify/core');

  // Una nota di tre pezzi: il primo e il terzo dicono la stessa cosa (gruppo 0), il secondo altro (gruppo 1).
  const testo = 'Il Dock va più in basso. Il Dock respira. Domani il pane. Il pane fresco. Il Dock di nuovo. Il Dock ancora.';
  final topics = {
    'spans': [0, 24, 25, 41, 42, 57, 58, 73, 74, 91, 92, 107],
    'medium': [1, 3],
    'groups': [0, 1, 0],
    'keys': [0, 2, 4],
    'keywords': [3, 7],
  };

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'noteTopics' => topics,
        'history' || 'notes' || 'pending' => <Object>[],
        _ => null,
      };
    });
  });

  Widget app(Widget child, {Brightness tema = Brightness.light}) => MaterialApp(
    theme: buildTheme(tema),
    home: Scaffold(body: child),
  );

  Iterable<TextSpan> foglie(InlineSpan s) sync* {
    if (s is! TextSpan) return;
    yield s;
    for (final c in s.children ?? const <InlineSpan>[]) {
      yield* foglie(c);
    }
  }

  group('Il carattere per leggere', () {
    /// Le lettere di ogni posto dove si legge: la scheda, il campo dove scrivi, il testo con le frasi scelte.
    Future<Map<String, String?>> caratteri(WidgetTester t) async {
      final campo = t.widget<TextField>(find.byType(TextField)).controller!;
      final span = campo.buildTextSpan(context: t.element(find.byType(TextField)), style: const TextStyle(color: Colors.red), withComposing: false);
      // Text.rich mette lo span dentro lo stile di base dell'app: conta quello di chi legge, il primo figlio.
      TextSpan dentro(Finder f) => (t.widget<RichText>(find.descendant(of: f, matching: find.byType(RichText))).text as TextSpan).children!.first as TextSpan;
      final scheda = dentro(find.byType(Anteprima));
      final evidenziato = dentro(find.byType(TestoEvidenziato));
      return {'scheda': scheda.style?.fontFamily, 'campo': span.style?.fontFamily, 'evidenziato': evidenziato.style?.fontFamily};
    }

    testWidgets('Onest in tutti i posti dove si legge (giro 7: Literata tolto)', (t) async {
      final c = CampoFormattato(text: 'Una nota **forte**');
      addTearDown(c.dispose);
      await t.pumpWidget(
        app(
          ListView(
            children: [
              const Anteprima('Una trascrizione', righe: 2, stile: TextStyle(color: Colors.blue)),
              TextField(controller: c, maxLines: null),
              const TestoEvidenziato(testo: 'Una frase scelta.', pezzi: [TextRange(start: 0, end: 3)]),
            ],
          ),
        ),
      );
      expect((await caratteri(t)).values.toSet(), {'Onest'});
    });

    test('15 su 24, la scheda un passo più piccola; l\'interfaccia resta in Inter', () {
      expect(Testo.fontTesto, 'Inter');
      expect(Testo.etichetta.fontFamily, 'Inter');
      expect(Testo.orario.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('Le misure: 15/24 e 14/21', (t) async {
      late TextStyle lettura, scheda;
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) {
              lettura = Testo.lettura(context);
              scheda = Testo.letturaScheda(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(lettura.fontSize! * lettura.height!, closeTo(24, 0.01));
      expect(scheda.fontSize! * scheda.height!, closeTo(21, 0.01));
    });

    testWidgets('Una riga vuota tra due paragrafi è alta 8, non 24; il testo resta lo stesso', (t) async {
      double alto(String s) => t.getSize(find.byKey(ValueKey(s))).height;
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in ['uno\ndue', 'uno\n\ndue'])
                  Text.rich(Formattato.span(context, s, stile: Testo.lettura(context)), key: ValueKey(s)),
              ],
            ),
          ),
        ),
      );
      expect(alto('uno\n\ndue') - alto('uno\ndue'), closeTo(Testo.spazioParagrafo, 0.5));
      final span = t.widget<RichText>(find.descendant(of: find.byKey(const ValueKey('uno\n\ndue')), matching: find.byType(RichText))).text;
      expect(span.toPlainText(), 'uno\n\ndue');
    });
  });

  group('L\'incavo del nido', () {
    for (final tema in Brightness.values) {
      testWidgets('Transcri fuori: un pozzetto, niente contorno (${tema.name})', (t) async {
        await t.pumpWidget(app(Center(child: TranscriNest(on: true, limitedUntil: null, onChanged: () {})), tema: tema));
        await t.pump(const Duration(milliseconds: 500));
        final nido = t.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).map((a) => a.decoration).whereType<BoxDecoration>();
        expect(nido.map((d) => d.gradient), contains(Ombra.incavo(tema)));
        expect(nido.every((d) => d.border == null), isTrue);
        await t.pumpWidget(const SizedBox());
      });
    }

    // Giro 7: «l'incavo non si vede, anche coi colori scuri». Il pozzetto sopra l'isola (chiara e scura) ne stacca
    // almeno 1,3:1 in alto e 1,15:1 a metà; di notte il bordo di sotto è più chiaro del pozzetto (il filo di luce).
    for (final tema in Brightness.values) {
      test('Si vede sull\'isola (${tema.name})', () {
        final isola = (tema == Brightness.dark ? Colori.scuro : Colori.chiaro).isola;
        double k(Color a, Color b) {
          final (x, y) = (a.computeLuminance(), b.computeLuminance());
          return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
        }

        final g = Ombra.incavo(tema);
        final sopra = [for (final c in g.colors) Color.alphaBlend(c, isola)];
        expect(k(sopra.first, isola), greaterThanOrEqualTo(1.3));
        expect(k(sopra[1], isola), greaterThanOrEqualTo(1.15));
        expect(sopra.first.computeLuminance(), lessThan(isola.computeLuminance()));
        if (tema == Brightness.dark) expect(sopra.last.computeLuminance(), greaterThan(sopra[1].computeLuminance()));
      });
    }
  });

  group('Le grane degli argomenti', () {
    test('Il tocco gira: spento, argomenti, frasi, parole chiave, spento', () {
      final giro = [Grana.spenta];
      for (var i = 0; i < 4; i++) {
        giro.add(Grana.dopo(giro.last));
      }
      expect([for (final l in giro) Grana.nomi[l]], ['Spento', 'Argomenti', 'Frasi', 'Parole chiave', 'Spento']);
    });

    testWidgets('Le barre si accendono una dopo l\'altra, dall\'alto', (t) async {
      for (var livello = Grana.spenta; livello <= Grana.ultima; livello++) {
        await t.pumpWidget(app(Center(child: BarreGrana(livello: livello))));
        await t.pumpAndSettle();
        final c = t.element(find.byType(BarreGrana)).col;
        final colori = [
          for (var i = 0; i < 3; i++) (t.widget<AnimatedContainer>(find.byKey(ValueKey('barra$i'))).decoration! as BoxDecoration).color,
        ];
        expect([for (final x in colori) x == c.azione], [for (var i = 0; i < 3; i++) i < livello], reason: Grana.nomi[livello]);
      }
    });

    testWidgets('Nella nota: il tocco cambia grana, tenendo il tasto si leggono i nomi', (t) async {
      final ora = DateTime(2026, 11, 6);
      await t.pumpWidget(app(NoteEditor(note: Note(id: 'n1', text: testo, created: ora, updated: ora, topics: 'ready'))));
      await t.pump(const Duration(milliseconds: 100));
      final tasto = find.byKey(const ValueKey('grana'));
      int livello() => t.widget<BarreGrana>(tasto).livello;
      expect(livello(), Grana.spenta);
      // Il testo della nota si legge nel suo carattere (il titolo no: è un titolo).
      expect(t.widget<TextField>(find.byType(TextField).last).style?.fontFamily, Testo.fontLettura);
      for (final atteso in [Grana.argomenti, Grana.frasi, Grana.parole, Grana.spenta]) {
        await t.tap(tasto);
        await t.pump(const Duration(milliseconds: 50));
        expect(livello(), atteso);
      }
      await t.pump(const Duration(seconds: 2));
      final g = await t.startGesture(t.getCenter(tasto));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (final nome in Grana.nomi) {
        expect(find.text(nome), findsOneWidget);
      }
      expect(find.text('Argomenti specifici'), findsNothing);
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(find.text('Frasi'), findsNothing);
    });

    testWidgets('I pezzi che dicono cose simili hanno lo stesso colore, a ogni grana', (t) async {
      final c = TopicTextController(text: testo)
        ..topics = NoteTopics(topics)
        ..topicsFor = testo;
      addTearDown(c.dispose);
      await t.pumpWidget(app(TextField(controller: c, maxLines: null)));
      final ctx = t.element(find.byType(TextField));
      Color? fondo(String pezzo) => foglie(c.buildTextSpan(context: ctx, withComposing: false)).firstWhere((s) => s.text == pezzo).style?.backgroundColor;

      c.level = Grana.argomenti;
      final primo = fondo('Il Dock va più in basso. Il Dock respira.');
      expect(fondo('Il Dock di nuovo. Il Dock ancora.'), primo);
      expect(fondo('Domani il pane. Il pane fresco.'), isNot(primo));
      expect(foglie(c.buildTextSpan(context: ctx, withComposing: false)).first.style?.fontFamily, Testo.fontLettura);

      c.level = Grana.frasi;
      expect(fondo('Il Dock di nuovo.'), fondo('Il Dock va più in basso.'));
      expect(fondo('Domani il pane.'), isNot(fondo('Il Dock va più in basso.')));
    });
  });
}
