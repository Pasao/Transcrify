import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/common.dart';
import 'package:transcrify/ui/molecole/piede_intro.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/prova_transcri.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/transcri.dart';

/// L'ultima pagina dell'introduzione (7 nov): provi Transcri, poi entri. «Salta» sempre in basso a sinistra, il
/// principale in basso a destra; senza chiave lo dice e si può saltare. Mentre parli Transcri va di lato col fumetto
/// (10 nov), tenerlo premuto lo spegne; a trascrizione fatta la sua scheda al centro, ed «Entra».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chiamate = <String>[];
  setUp(() {
    chiamate.clear();
    Core.live.value = const Live();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('transcrify/core'),
      (c) async {
        chiamate.add(c.method);
        if (c.method == 'history') return [{'text': 'Ciao, sono la prima.', 'at': 1, 'purified': false}];
        return null;
      },
    );
  });

  Future<List<bool>> apri(WidgetTester t, {required bool chiave}) async {
    final fine = <bool>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: ProvaTranscri(haChiave: chiave, onFine: fine.add, onIndietro: () {}),
      ),
    );
    return fine;
  }

  testWidgets('«Salta» a sinistra, il principale a destra; senza chiave lo dice', (t) async {
    final fine = await apri(t, chiave: false);
    final piede = find.byType(PiedeIntro);
    final salta = t.getCenter(find.descendant(of: piede, matching: find.text('Salta')));
    final principale = t.getCenter(find.descendant(of: piede, matching: find.text('Metti la chiave')));
    expect(salta.dx, lessThan(principale.dx));
    expect(find.textContaining('serve la chiave'), findsOneWidget);
    await t.tap(find.text('Salta'));
    expect(fine, [false]);
  });

  testWidgets('Stop, poi la trascrizione fatta: si entra con la prima trascrizione', (t) async {
    final fine = await apri(t, chiave: true);
    expect(find.text('Prova'), findsOneWidget);
    Core.live.value = const Live(phase: 'RECORDING', seconds: 65);
    await t.pump();
    expect(find.text('01:05'), findsOneWidget);
    await t.tap(find.text('Stop'));
    await t.pump();
    expect(chiamate, contains('stopListening'));
    expect(find.text('Trascrivo…'), findsOneWidget);
    Core.live.value = const Live(phase: 'PROCESSING');
    Core.live.value = const Live(phase: 'SUCCESS');
    await t.pump();
    await t.pump(Durata.lenta);
    // Pronta: al centro la sua scheda vera (quella della lista) col titolo sopra, fuori, ed «Entra».
    expect(find.text('Ecco la tua prima trascrizione'), findsOneWidget);
    expect(find.byType(SchedaTrascrizione), findsOneWidget);
    expect(find.descendant(of: find.byType(SchedaTrascrizione), matching: find.text('Ecco la tua prima trascrizione')), findsNothing);
    expect(t.getBottomLeft(find.text('Ecco la tua prima trascrizione')).dy, lessThanOrEqualTo(t.getTopLeft(find.byType(SchedaTrascrizione)).dy));
    expect(find.byType(PillolaBordo), findsOneWidget);
    expect(fine, isEmpty);
    await t.tap(find.text('Entra'));
    expect(fine, [true]);
    // La pillola se ne va; vola la scheda.
    await t.pump(Durata.normale);
    expect(find.byType(PillolaBordo), findsNothing);
    // La copia vola sopra tutto: senza la lista, svanisce dov'è.
    for (var i = 0; i < 3; i++) {
      await t.pump(Durata.attesaVoloPrima);
    }
    expect(find.text('Ecco la tua prima trascrizione'), findsOneWidget); // quella della pagina, la copia se n'è andata
  });

  testWidgets('Dopo un secondo va di lato col fumetto; tenuto premuto si spegne', (t) async {
    await apri(t, chiave: true);
    Core.live.value = const Live(phase: 'RECORDING');
    await t.pump();
    final fumetto = find.text('Leggi la frase qui sotto.');
    double vista() => t.widget<AnimatedOpacity>(find.ancestor(of: fumetto, matching: find.byType(AnimatedOpacity))).opacity;
    final centro = t.getCenter(find.byType(TranscriCorpo));
    expect(vista(), 0);
    await t.pump(Durata.provaDiLato);
    await t.pump(Durata.lenta);
    expect(vista(), 1);
    // Di lato diventa la pillola del bordo (non un Transcri piccolo).
    expect(find.byType(TranscriCorpo), findsNothing);
    // Si può fermare in ogni momento: lo dice. Il tempo non cambia la fase: la cambia lui, con «Avanti».
    expect(find.text('Puoi fermarmi quando vuoi: tienimi premuto.'), findsOneWidget);
    Core.live.value = const Live(phase: 'RECORDING', seconds: 30);
    await t.pump();
    expect(fumetto, findsOneWidget);
    await t.tap(find.text('Avanti'));
    await t.pump();
    await t.pump(Durata.lenta);
    await t.pump(Durata.lenta);
    expect(find.text('Ora tienimi premuto per fermarmi, oppure tocca Stop.'), findsOneWidget);
    expect(find.text('Avanti'), findsNothing);
    // La pillola sta a destra e in alto, il fumetto sotto di lei, la frase sotto il fumetto.
    final pillola = t.getCenter(find.byType(PillolaBordo));
    expect(pillola.dx, greaterThan(centro.dx));
    expect(pillola.dy, lessThan(centro.dy));
    final suggerimento = t.getRect(find.textContaining('Ora tienimi premuto'));
    expect(suggerimento.top, greaterThan(pillola.dy));
    expect(t.getRect(find.textContaining('Ciao Transcrify')).top, greaterThan(suggerimento.bottom));
    await t.longPress(find.byType(PillolaBordo));
    await t.pump();
    expect(chiamate, contains('stopListening'));
    expect(find.text('Trascrivo…'), findsOneWidget);
  });

  testWidgets("Toccare Transcri fa come «Prova»; l'anello sta staccato dal corpo", (t) async {
    await apri(t, chiave: true);
    VoidCallback? prova() => t.widget<PiedeIntro>(find.byType(PiedeIntro)).onPrincipale;
    expect(prova(), isNotNull);
    await t.tap(find.byType(TranscriCorpo));
    await t.pump();
    // Come «Prova»: sta chiedendo il microfono, e «Prova» si spegne finché non risponde.
    expect(prova(), isNull);
    Core.live.value = const Live(phase: 'RECORDING');
    await t.pump();
    final anello = t.getSize(find.byType(VoiceCircle)).width, corpo = t.getSize(find.byType(TranscriCorpo)).width;
    expect(anello - corpo, greaterThanOrEqualTo(Misura.anelloVoce * 2));
  });

  testWidgets('Con il permesso parte la pillola vera, già in ascolto; fermata da lei vale come «Stop»; «Entra» la ritira', (t) async {
    final args = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('transcrify/core'), (c) async {
      chiamate.add(c.method);
      args[c.method] = c.arguments;
      return switch (c.method) {
        'history' => [{'text': 'Ciao, sono la prima.', 'at': 1, 'purified': false}],
        _ => null,
      };
    });
    final fine = await apri(t, chiave: true);
    // Il microfono e «sopra le altre app» già permessi (come nelle prove: niente richieste vere).
    Core.preview.value = true;
    Core.previewGrant('overlay');
    await t.tap(find.text('Prova'));
    await t.pump();
    await t.pump();
    Core.preview.value = false;
    expect(chiamate, contains('startPill'));
    expect((args['startPill'] as Map)['record'], true);
    // Guidata: ferma sul bordo destro, in alto (una frazione dello schermo); il posto salvato non si tocca.
    final guida = (args['startPill'] as Map)['guida'] as double;
    expect(guida, inExclusiveRange(0, 0.5));
    expect((args['startPill'] as Map)['place'], false);
    expect(chiamate, isNot(contains('listen')));
    Core.live.value = const Live(phase: 'RECORDING');
    await t.pump();
    await t.pump(Durata.lenta);
    // La pillola vera è sul bordo: qui né Transcri né quella disegnata.
    expect(find.byType(TranscriCorpo), findsNothing);
    expect(find.byType(PillolaBordo), findsNothing);
    // Tenuta premuta la pillola vera: il nativo lavora, poi la trascrizione è pronta.
    Core.live.value = const Live(phase: 'PROCESSING');
    Core.live.value = const Live(phase: 'SUCCESS');
    await t.pump();
    await t.pump(Durata.lenta);
    expect(find.text('Ecco la tua prima trascrizione'), findsOneWidget);
    // Nella prova la prima non si butta: niente cestino, solo «Entra».
    expect(find.byType(DeleteButton), findsNothing);
    await t.tap(find.text('Entra'));
    expect(fine, [true]);
    expect(chiamate, contains('stopPill'));
    for (var i = 0; i < 3; i++) {
      await t.pump(Durata.attesaVoloPrima);
    }
  });

  testWidgets('Non si ferma mai da sola', (t) async {
    await apri(t, chiave: true);
    Core.live.value = const Live(phase: 'RECORDING', seconds: 60);
    await t.pump();
    await t.pump();
    expect(chiamate, isNot(contains('stopListening')));
  });

  testWidgets('Groq non risponde: lo dice in una riga, si riprova o si salta', (t) async {
    final fine = await apri(t, chiave: true);
    Core.live.value = const Live(phase: 'RECORDING');
    await t.pump();
    await t.tap(find.text('Stop'));
    Core.live.value = const Live(phase: 'ERROR', error: "Niente rete. L'audio è salvato");
    await t.pump();
    expect(find.text("Niente rete. L'audio è salvato"), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    expect(fine, isEmpty);
  });
}
