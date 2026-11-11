import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/formato.dart';
import 'package:transcrify/core/scrittura.dart';
import 'package:transcrify/ui/barra_nota.dart';
import 'package:transcrify/ui/molecole/apri_collegamento.dart';
import 'package:transcrify/ui/theme.dart';

/// La barra delle note (7 nov): a sinistra si scrive, a destra l'intelligenza; i ritocchi sul testo; «Apri» sui link.
void main() {
  TextEditingValue v(String t, int a, [int? b]) => TextEditingValue(text: t, selection: TextSelection(baseOffset: a, extentOffset: b ?? a));

  group('Scrittura', () {
    test('grassetto e corsivo: attorno alla selezione (senza gli spazi ai bordi), e di nuovo li toglie', () {
      final g = Scrittura.segna(v('un forte qui', 2, 9), TipoPezzo.grassetto);
      expect(g.text, 'un **forte** qui');
      expect(g.selection.textInside(g.text), 'forte');
      final via = Scrittura.segna(g, TipoPezzo.grassetto);
      expect(via.text, 'un forte qui');
      expect(via.selection.textInside(via.text), 'forte');
      final c = Scrittura.segna(v('piano', 0, 5), TipoPezzo.corsivo);
      expect(c.text, '*piano*');
      // Il cursore fermo fuori da una parola: i due segni e lui in mezzo; toccato di nuovo, vanno via.
      final vuoto = Scrittura.segna(v('ab ', 3), TipoPezzo.grassetto);
      expect(vuoto.text, 'ab ****');
      expect(vuoto.selection.baseOffset, 5);
      expect(Scrittura.segna(vuoto, TipoPezzo.grassetto).text, 'ab ');
      expect(Scrittura.segna(Scrittura.segna(v('ab ', 3), TipoPezzo.corsivo), TipoPezzo.corsivo).text, 'ab ');
    });

    test('7 nov: il cursore dentro una parola la prende tutta (non la spezza), e resta dov\'era; di nuovo, via', () {
      final g = Scrittura.segna(v('un forte qui', 5), TipoPezzo.grassetto);
      expect(g.text, 'un **forte** qui');
      expect(g.selection.baseOffset, 7);
      expect(Scrittura.segna(g, TipoPezzo.grassetto).text, 'un forte qui');
      expect(Scrittura.segna(v('città', 2), TipoPezzo.corsivo).text, '*città*');
    });

    test('7 nov: scelto anche coi segni (che non si vedono), si toglie e non se ne mette un altro attorno', () {
      expect(Scrittura.segna(v('un **forte** qui', 3, 12), TipoPezzo.grassetto).text, 'un forte qui');
      expect(Scrittura.segna(v('*piano*', 0, 7), TipoPezzo.corsivo).text, 'piano');
    });

    test('7 nov: su più righe ogni riga per conto suo, senza il pallino né le righe vuote', () {
      final g = Scrittura.segna(v('• uno\n\ndue tre', 0, 14), TipoPezzo.grassetto);
      expect(g.text, '• **uno**\n\n**due tre**');
      expect(Formato.leggi(g.text).where((p) => p.tipo == TipoPezzo.grassetto).length, 2);
    });

    test('elenco: il pallino sulle righe scelte, e via da tutte se ce l\'hanno già', () {
      final e = Scrittura.elenco(v('uno\ndue\ntre', 0, 5));
      expect(e.text, '• uno\n• due\ntre');
      expect(Scrittura.elenco(e).text, 'uno\ndue\ntre');
      expect(Scrittura.continua('• uno', v('• uno\n', 6))?.text, '• uno\n• ');
      expect(Scrittura.continua('• uno\n• ', v('• uno\n• \n', 9))?.text, '• uno\n');
    });

    test('link: le parole portano all\'indirizzo; senza, le parentesi pronte; e di nuovo lo toglie', () {
      final url = Formato.indirizzo('www.esempio.it');
      final l = Scrittura.collega(v('vedi qui ora', 5, 8), url);
      expect(l.text, 'vedi [qui](https://www.esempio.it) ora');
      final p = Formato.leggi(l.text).single;
      expect((p.tipo, l.text.substring(p.dentroInizio, p.dentroFine), p.uri.toString()), (TipoPezzo.collegamento, 'qui', 'https://www.esempio.it'));
      expect(Scrittura.collega(v(l.text, 7), null).text, 'vedi qui ora');
      final senza = Scrittura.collega(v('vedi qui', 5, 8), null);
      expect(senza.text, 'vedi [qui]()');
      expect(senza.selection.baseOffset, senza.text.length - 1);
      expect(Scrittura.collega(v('vai ', 4), url).text, 'vai https://www.esempio.it');
      expect(Formato.indirizzo('non un link'), isNull);
    });
  });

  Widget app(Widget child, Brightness luce) => MaterialApp(
    theme: buildTheme(luce),
    builder: (context, figlio) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)), child: figlio!),
    home: Scaffold(body: child),
  );

  for (final luce in Brightness.values) {
    testWidgets('La barra, stretta e col testo grande: scrivere a sinistra, la linea, l\'intelligenza a destra ($luce)', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final fatti = <String>[];
      await t.pumpWidget(
        app(
          Align(
            alignment: Alignment.bottomCenter,
            child: BarraNota(
              undo: UndoHistoryController(),
              onGrassetto: () => fatti.add('g'),
              onCorsivo: () => fatti.add('c'),
              onElenco: () => fatti.add('e'),
              onLink: () => fatti.add('l'),
              dictation: null,
              onPaste: () {},
              topics: 0,
              onTopics: () {},
              onSlideStart: () {},
              onSlide: (_) {},
              onSlideEnd: () {},
              onSummarize: () {},
            ),
          ),
          luce,
        ),
      );
      expect(t.takeException(), isNull);
      for (final n in ['Annulla', 'Ripeti', 'Grassetto', 'Corsivo', 'Elenco', 'Link', 'Riassunto']) {
        expect(find.byTooltip(n), findsOneWidget, reason: n);
      }
      final linea = t.getRect(find.byType(VerticalDivider)).center.dx;
      expect(t.getRect(find.byTooltip('Riassunto')).center.dx, greaterThan(linea));
      expect(t.getRect(find.byTooltip('Annulla')).center.dx, lessThan(linea));
      await t.tap(find.byTooltip('Grassetto'));
      await t.tap(find.byTooltip('Corsivo'));
      expect(fatti, ['g', 'c']);
    });
  }

  testWidgets('Il cursore su un link: spunta «Apri»; fuori dal link, va via', (t) async {
    final c = TextEditingController(text: 'vedi www.esempio.it e poi');
    addTearDown(c.dispose);
    await t.pumpWidget(app(ApriCollegamento(testo: c, child: TextField(controller: c, maxLines: null)), Brightness.light));
    await t.showKeyboard(find.byType(TextField));
    c.selection = const TextSelection.collapsed(offset: 8);
    await t.pump();
    await t.pump();
    final apri = find.byKey(const ValueKey('apri collegamento'));
    expect(apri, findsOneWidget);
    // Sotto la riga del link, non sopra il testo.
    expect(t.getRect(apri).top, greaterThan(t.getRect(find.byType(TextField)).top));
    c.selection = const TextSelection.collapsed(offset: 1);
    await t.pump();
    await t.pump();
    expect(apri, findsNothing);
    expect(t.takeException(), isNull);
  });
}
