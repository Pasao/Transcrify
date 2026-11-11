import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/regole_colori.dart';
import 'package:transcrify/ui/etichette.dart';
import 'package:transcrify/ui/theme.dart';

/// Impostazioni → Etichette (10 nov): le etichette con nome o in uso, la regola (parte col nome) e «Offusca sempre»;
/// accenderlo copre anche quelle che l'etichetta ha già, e «Annulla» rimette in vista esattamente quelle. Dati finti.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> chiamate;
  Map<String, Object?> voce(int ms, String colore, {bool privata = false}) =>
      {'text': 'Una cosa.', 'at': ms, 'purified': false, 'colore': colore, 'privata': privata};

  setUp(() {
    chiamate = [];
    RegoleColori.tutte.value = const {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('transcrify/core'), (c) async {
      chiamate.add(c);
      return switch (c.method) {
        'history' => [voce(1, '10:4'), voce(2, '10:4', privata: true), voce(3, '10:4'), voce(4, '0:4')],
        'nomiColori' => {'10:4': 'Lavoro', '6:2': 'Idee'},
        'regoleColori' => {'6:2': {'regola': 'Idee', 'offuscaSempre': false, 'daNome': true}},
        'salvaRegola' => (c.arguments as Map)['offuscaSempre'] == true ? {'offuscate': 2} : {'offuscate': 0},
        'proponiEtichette' => [
          {'nome': 'Relazioni', 'regola': 'amore, dolore, sentimenti, emozioni'},
          {'nome': 'Casa', 'regola': 'spesa, bollette'},
        ],
        'proponiRegole' => [
          {'colore': '10:4', 'nome': 'Lavoro', 'regola': 'preventivi, clienti'},
        ],
        _ => null,
      };
    });
  });

  testWidgets('La lista, la regola col nome, «Offusca sempre» e il suo «Annulla»', (t) async {
    t.view.physicalSize = const Size(360, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const EtichettePage()));
    await t.pumpAndSettle();
    // Lavoro (3), il rosso senza nome (1), Idee (nessuna): i più usati prima.
    expect(find.text('3 trascrizioni'), findsOneWidget);
    expect(find.text('Rosso'), findsOneWidget);
    expect(t.getTopLeft(find.text('Lavoro').first).dy, lessThan(t.getTopLeft(find.text('Idee').first).dy));
    // La regola vuota vale il nome: si legge come suggerimento, non scritto due volte («alcune etichette sono doppie»).
    expect(find.widgetWithText(TextField, 'di cosa parlano (vuota: «Lavoro»)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Lavoro'), findsNothing);
    // In cima: le etichette sono i colori della rosa.
    expect(find.textContaining('colori della rosa'), findsOneWidget);

    await t.tap(find.byType(Switch).first);
    await t.pump();
    final salvata = chiamate.lastWhere((c) => c.method == 'salvaRegola').arguments as Map;
    // Uguale al nome vale come vuota: la regola di base del nativo.
    expect(salvata, {'colore': '10:4', 'regola': '', 'offuscaSempre': true});
    expect(find.text('Offuscate 2 trascrizioni'), findsOneWidget);

    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    expect((chiamate.lastWhere((c) => c.method == 'salvaRegola').arguments as Map)['offuscaSempre'], false);
    // Spenta, il nativo rimette in vista tutte quelle dell'etichetta; la 2 era già offuscata prima e torna coperta.
    final rimesse = chiamate.lastWhere((c) => c.method == 'segnaHistory').arguments as Map;
    expect(rimesse, {'ats': [2], 'privata': true});
  });

  Future<void> apri(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const EtichettePage()));
    await t.pumpAndSettle();
  }

  testWidgets("Togli un'etichetta: nome e regola via, il colore solo se lo scegli", (t) async {
    await apri(t);
    await t.tap(find.byTooltip("Togli l'etichetta").first);
    await t.pumpAndSettle();
    expect(find.text('Togli «Lavoro»'), findsOneWidget);
    await t.tap(find.text('Togli il colore dalle trascrizioni'));
    await t.pump();
    await t.tap(find.text('Conferma'));
    await t.pumpAndSettle();
    expect(chiamate.where((c) => c.method == 'nomeColore').single.arguments, {'colore': '10:4', 'nome': ''});
    // Via il colore da tutte e tre le sue (anche la offuscata).
    expect(chiamate.lastWhere((c) => c.method == 'segnaHistory').arguments, {'ats': [1, 2, 3], 'colore': null});
  });

  testWidgets('Proponi etichette: anteprima con le spunte, poi regola e nome su colori liberi e distinti', (t) async {
    await apri(t);
    await t.tap(find.text('Proponi etichette'));
    await t.pumpAndSettle();
    expect(find.text('Etichette proposte'), findsOneWidget);
    expect(find.text('amore, dolore, sentimenti, emozioni'), findsOneWidget);
    // Tolta «Casa», si aggiunge solo «Relazioni»: prima la regola, poi il nome, su un colore che non c'era.
    await t.tap(find.text('Casa'));
    await t.pump();
    await t.tap(find.text('Aggiungi 1'));
    await t.pumpAndSettle();
    final regola = chiamate.lastWhere((c) => c.method == 'salvaRegola').arguments as Map;
    final nome = chiamate.lastWhere((c) => c.method == 'nomeColore').arguments as Map;
    expect(regola['regola'], 'amore, dolore, sentimenti, emozioni');
    expect(nome, {'colore': regola['colore'], 'nome': 'Relazioni'});
    expect(chiamate.indexWhere((c) => c.method == 'salvaRegola'), lessThan(chiamate.indexWhere((c) => c.method == 'nomeColore')));
    expect(['10', '0', '6'], isNot(contains((regola['colore'] as String).split(':').first)));
  });

  testWidgets('Proponi regole: una regola nuova per le etichette che hai, scelta nella stessa anteprima', (t) async {
    await apri(t);
    await t.tap(find.text('Proponi regole'));
    await t.pumpAndSettle();
    expect(find.text('Regole proposte'), findsOneWidget);
    expect(find.text('preventivi, clienti'), findsOneWidget);
    await t.tap(find.text('Applica 1'));
    await t.pumpAndSettle();
    // Sull'etichetta che c'era, con «Offusca sempre» com'era; nessun nome nuovo.
    expect(chiamate.lastWhere((c) => c.method == 'salvaRegola').arguments, {'colore': '10:4', 'regola': 'preventivi, clienti', 'offuscaSempre': false});
    expect(chiamate.where((c) => c.method == 'nomeColore'), isEmpty);
  });

  test('I colori proposti: liberi e lontani tra loro e da quelli usati', () {
    final scelte = Tinte.lontane({0}, 3);
    expect(scelte, hasLength(3));
    expect(scelte.toSet(), hasLength(3));
    expect(scelte, isNot(contains(0)));
    double d(int a, int b) {
      final x = (Tinte.tonalita[a] - Tinte.tonalita[b]).abs();
      return x > 180 ? 360 - x : x;
    }
    // Ognuna ad almeno 60° dalle altre (sedici tinte, quattro prese: c'è spazio).
    for (final a in [0, ...scelte]) {
      for (final b in [0, ...scelte]) {
        if (a != b) expect(d(a, b), greaterThanOrEqualTo(60));
      }
    }
    expect(Tinte.lontane({for (var i = 0; i < 16; i++) i}, 2), isEmpty);
  });
}
