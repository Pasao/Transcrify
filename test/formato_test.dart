import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/formato.dart';
import 'package:transcrify/ui/theme.dart';

/// La formattazione dei testi: si riconosce, si vede, e il testo salvato resta quello scritto.
void main() {
  List<(TipoPezzo, String)> pezzi(String t) => [for (final p in Formato.leggi(t)) (p.tipo, t.substring(p.dentroInizio, p.dentroFine))];

  group('Formato.leggi', () {
    test('grassetto e corsivo', () {
      expect(pezzi('un **forte** e un *piano*'), [(TipoPezzo.grassetto, 'forte'), (TipoPezzo.corsivo, 'piano')]);
    });

    test('non sono formattazione: elenchi, conti, segni soli, spazi ai bordi', () {
      expect(pezzi('* una voce\n- un\'altra'), isEmpty);
      expect(pezzi('2*3*4 = 24'), isEmpty);
      expect(pezzi('** niente ** e * niente *'), isEmpty);
      expect(pezzi('**a capo\nnon vale**'), isEmpty);
    });

    test('link, e-mail e telefoni, senza la punteggiatura che chiude la frase', () {
      final t = 'Vai su www.esempio.it. Scrivi a mario.rossi@posta.it, chiama +39 333 123 4567 o 02 1234 5678.';
      final l = Formato.leggi(t);
      expect([for (final p in l) p.uri.toString()], ['https://www.esempio.it', 'mailto:mario.rossi@posta.it', 'tel:+393331234567', 'tel:0212345678']);
      expect(l.every((p) => p.tipo == TipoPezzo.collegamento), isTrue);
    });

    test('dentro un link non c\'è corsivo, e le date non sono telefoni', () {
      expect(pezzi('https://x.it/*a*/b'), [(TipoPezzo.collegamento, 'https://x.it/*a*/b')]);
      expect(pezzi('il 05/11/2026 alle 21:10, 2026'), isEmpty);
    });
  });

  /// Tutti i pezzi di uno span, anche quelli dentro altri (Text.rich ci mette intorno lo stile di default).
  List<TextSpan> foglie(InlineSpan s) {
    final out = <TextSpan>[];
    s.visitChildren((c) {
      if (c is TextSpan) out.add(c);
      return true;
    });
    return out;
  }

  Widget app(Widget child) => MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  );

  test('il collegamento dove sta il cursore, anche subito dopo l\'ultima lettera', () {
    const t = 'vai su www.x.it ora';
    expect(Formato.collegamentoIn(t, 8)?.uri.toString(), 'https://www.x.it');
    expect(Formato.collegamentoIn(t, 15)?.uri.toString(), 'https://www.x.it');
    expect(Formato.collegamentoIn(t, 2), isNull);
    expect(Formato.collegamentoIn(t, 17), isNull);
  });

  testWidgets('Nel campo i segni non si vedono, tranne dove sta il cursore (spenti)', (t) async {
    const testo = 'Un **forte** e un *piano*';
    final c = CampoFormattato(text: testo);
    addTearDown(c.dispose);
    await t.pumpWidget(app(TextField(controller: c, maxLines: null)));
    TextStyle? segno(String s, int k) => foglie(c.buildTextSpan(context: t.element(find.byType(TextField)), withComposing: false)).where((x) => x.text == s).elementAt(k).style;
    // Il cursore in fondo, attaccato al corsivo: i suoi segni si vedono, quelli del grassetto no.
    c.selection = const TextSelection.collapsed(offset: testo.length);
    expect(segno('**', 0), Testo.segnoNascosto);
    expect(segno('*', 0)?.color?.a, closeTo(Velo.segni, 0.01));
    // Dentro il grassetto: al contrario.
    c.selection = const TextSelection.collapsed(offset: 6);
    expect(segno('**', 1)?.color?.a, closeTo(Velo.segni, 0.01));
    expect(segno('*', 1), Testo.segnoNascosto);
  });

  testWidgets('Il campo mostra i segni (spenti) e il testo resta identico', (t) async {
    const testo = 'Un **forte**, un *piano* e https://esempio.it';
    final c = CampoFormattato(text: testo);
    addTearDown(c.dispose);
    await t.pumpWidget(app(TextField(controller: c, maxLines: null)));
    final span = c.buildTextSpan(context: t.element(find.byType(TextField)), withComposing: false);
    expect(span.toPlainText(), testo);
    expect(c.text, testo);
    final grassetto = foglie(span).firstWhere((s) => s.text == 'forte');
    expect(grassetto.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('Sulla scheda i segni spariscono e il link si tocca', (t) async {
    await t.pumpWidget(app(const Anteprima('Un **forte** e www.esempio.it', righe: 4)));
    final testo = t.widget<RichText>(find.byType(RichText).last).text as TextSpan;
    expect(testo.toPlainText(), 'Un forte e www.esempio.it');
    final link = foglie(testo).firstWhere((s) => s.text == 'www.esempio.it');
    expect(link.recognizer, isA<TapGestureRecognizer>());
  });

  testWidgets('Mentre scegli, il link non si tocca', (t) async {
    await t.pumpWidget(app(const Anteprima('www.esempio.it', righe: 2, collegamenti: false)));
    final testo = t.widget<RichText>(find.byType(RichText).last).text as TextSpan;
    expect(foglie(testo).every((s) => s.recognizer == null), isTrue);
  });

  testWidgets('Una scheda stretta con testo formattato lungo non sborda', (t) async {
    final lungo = List.filled(40, '**grassetto** *corsivo* https://un.indirizzo.molto.lungo.it/percorso/senza/spazi 333 123 4567').join(' ');
    await t.pumpWidget(
      app(
        Center(
          child: SizedBox(width: 140, height: 120, child: Anteprima(lungo, righe: 4)),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
