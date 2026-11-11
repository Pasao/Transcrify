import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/core/orario.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/theme.dart';

/// La fascia in fondo alla scheda (10 nov, «il cestino è tutto spostato»): il cestino sta sempre dentro la fascia, a
/// destra (allo stesso posto qualunque sia l'ora e le iconcine) e centrato in altezza con l'ora, a ogni larghezza e
/// grandezza del testo.
void main() {
  Entry voce(int ms, {String? source, String? mode}) =>
      Entry({'text': 'Una cosa da dire, abbastanza lunga da andare a capo.', 'at': ms, 'purified': false, 'source': source, 'mode': mode});

  for (final larga in [160.0, SchedaTrascrizione.larga, 320.0]) {
    for (final scala in [1.0, 1.3, 2.0]) {
      testWidgets('Il cestino a destra e centrato · larga $larga · testo ×$scala', (t) async {
        t.view.physicalSize = const Size(400, 1200);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        // Ore e iconcine diverse: il cestino non si sposta con loro.
        final voci = [voce(DateTime(2026, 11, 10, 1, 1).millisecondsSinceEpoch), voce(DateTime(2026, 11, 10, 23, 58).millisecondsSinceEpoch, source: 'whatsapp', mode: 'riassunto')];
        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.light),
            home: MediaQuery(
              data: MediaQueryData(size: const Size(400, 1200), textScaler: TextScaler.linear(scala)),
              child: Scaffold(
                body: Column(
                  children: [for (final e in voci) SchedaTrascrizione(entry: e, width: larga, onOpen: () {}, onDelete: () {})],
                ),
              ),
            ),
          ),
        );
        final destre = <double>[];
        for (var i = 0; i < voci.length; i++) {
          final scheda = t.getRect(find.byType(SchedaTrascrizione).at(i));
          final cestino = t.getRect(find.descendant(of: find.byType(SchedaTrascrizione).at(i), matching: find.byIcon(Icons.delete_outline_rounded)));
          final ora = t.getRect(find.descendant(of: find.byType(SchedaTrascrizione).at(i), matching: find.text(hm(voci[i].at))));
          // Dentro la scheda, nella fascia (sotto la metà), mai attaccato ai bordi.
          expect(scheda.contains(cestino.topLeft) && scheda.contains(cestino.bottomRight), isTrue);
          expect(cestino.top, greaterThan(scheda.center.dy));
          expect(scheda.right - cestino.right, inInclusiveRange(Spazio.s3, Spazio.s6));
          expect(scheda.bottom - cestino.bottom, inInclusiveRange(Spazio.s2, Spazio.s6));
          // Centrato in altezza con l'ora.
          expect((cestino.center.dy - ora.center.dy).abs(), lessThan(1));
          destre.add(scheda.right - cestino.right);
        }
        // A destra, allo stesso posto su tutte.
        expect(destre.toSet(), hasLength(1));
      });
    }
  }
}
