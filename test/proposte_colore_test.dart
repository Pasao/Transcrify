import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/proposte_colore.dart';
import 'package:transcrify/ui/da_sistemare.dart';
import 'package:transcrify/ui/molecole/riga_in_attesa.dart';
import 'package:transcrify/ui/theme.dart';

/// «Colora da sola» propone, non cambia (10 nov): stanno con le registrazioni in attesa, nella riga sotto «Trascrivi»
/// (o accanto al titolo nella pillola); la scintilla apre la pagina «Da sistemare», dove hanno la loro parte: ognuna col titolo (toccato
/// apre la trascrizione) e il colore, ✓ / ✕ e «Accetta tutte». Dati finti.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> chiamate;
  Entry voce(int ms, String titolo) => Entry({'text': 'Una cosa.', 'at': ms, 'purified': false, 'titolo': titolo});
  final voci = [voce(1, 'Preventivo bagno'), voce(2, 'Cena con Marta')];

  setUp(() {
    chiamate = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('transcrify/core'), (c) async {
      chiamate.add(c);
      return switch (c.method) {
        'proposteColore' => [
          {'at': 1, 'colore': '10:4'},
          {'at': 2, 'colore': '0:4'},
          // Di una trascrizione che non c'è più: non si mostra.
          {'at': 9, 'colore': '0:4'},
        ],
        'pending' => [],
        _ => null,
      };
    });
  });

  /// L'ultima chiamata che non sia il foglio che rilegge le registrazioni in attesa.
  MethodCall ultima() => chiamate.lastWhere((c) => c.method != 'pending');

  late List<String> aperte;

  Future<void> apri(WidgetTester t, {bool corto = false}) async {
    aperte = [];
    await ProposteColore.leggi();
    final quante = ProposteColore.con(voci).length;
    void onApri(BuildContext _, Entry e) => aperte.add(e.titolo ?? '');
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              void foglio(DaSistemare parte) => apriDaSistemare(context, parte: parte, onRiprova: () {}, voci: voci, onApri: onApri);
              return Align(
                alignment: Alignment.topLeft,
                child: corto
                    ? InAttesaCorto(quante: 0, proposte: quante, onApri: foglio)
                    : RigaInAttesa(quante: 0, proposte: quante, riprovando: false, onRiprova: () {}, onApri: foglio),
              );
            },
          ),
        ),
      ),
    );
    await t.pump();
    // Solo proposte: niente orologio né «Riprova», la scintilla di «Colora da sola».
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.text('Riprova'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    await t.tap(find.text(corto ? '2' : '2 proposte di colore'));
    await t.pumpAndSettle();
  }

  testWidgets('Dal segno nella pillola si apre la stessa pagina', (t) async {
    await apri(t, corto: true);
    expect(find.text('Proposte di colore'), findsOneWidget);
    // Niente in attesa: il loro spazio non c'è.
    expect(find.text('In attesa di rete'), findsNothing);
  });

  testWidgets('Toccato il titolo, si apre la sua trascrizione', (t) async {
    await apri(t);
    await t.tap(find.text('Cena con Marta'));
    expect(aperte, ['Cena con Marta']);
  });

  testWidgets('Le proposte col titolo; ✓ mette il colore, ✕ non la propone più', (t) async {
    await apri(t);
    expect(find.text('Proposte di colore'), findsOneWidget);
    expect(find.text('Preventivo bagno'), findsOneWidget);
    expect(find.text('Cena con Marta'), findsOneWidget);

    await t.tap(find.byIcon(Icons.check_rounded).first);
    await t.pump();
    expect(ultima().method, 'accettaProposta');
    expect(ultima().arguments, {'at': 1});
    expect(find.text('Preventivo bagno'), findsNothing);
    expect(find.text('Cena con Marta'), findsOneWidget);

    await t.tap(find.byIcon(Icons.close_rounded));
    await t.pump();
    expect(ultima().method, 'rifiutaProposta');
    expect(ultima().arguments, {'at': 2});
    // Finite le proposte (e niente in attesa), la pagina resta e lo dice.
    await t.pumpAndSettle();
    expect(find.text('Proposte di colore'), findsNothing);
    expect(find.textContaining('Niente da sistemare'), findsOneWidget);
  });

  testWidgets('«Accetta tutte»', (t) async {
    await apri(t);
    await t.tap(find.text('Accetta tutte'));
    await t.pump();
    expect(ultima().method, 'accettaTutte');
    await t.pumpAndSettle();
    expect(find.text('Proposte di colore'), findsNothing);
  });

  testWidgets('«Scarta tutte»', (t) async {
    await apri(t);
    await t.tap(find.text('Scarta tutte'));
    await t.pump();
    expect(ultima().method, 'rifiutaTutte');
    await t.pumpAndSettle();
    expect(find.text('Proposte di colore'), findsNothing);
  });
}
