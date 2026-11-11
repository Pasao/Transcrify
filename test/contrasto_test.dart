// Giro 7 (6 nov): le schede staccano dalla pagina («sembrano molto simili»), e le prove nascoste partono spente.
// La regola dei token sta nel Kotlin (TokenTest, con ogni colore del telefono); qui i valori del primo istante.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/ui/cartelle.dart';
import 'package:transcrify/ui/theme.dart';

double contrasto(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final (nome, c) in [('chiaro', Colori.chiaro), ('scuro', Colori.scuro)]) {
    test('Le schede staccano dalla pagina almeno 1,25:1, e il testo ci si legge ($nome)', () {
      expect(contrasto(c.scheda, c.pagina), greaterThanOrEqualTo(1.25));
      expect(contrasto(c.testo, c.scheda), greaterThanOrEqualTo(7));
      expect(contrasto(c.testoSecondario, c.scheda), greaterThanOrEqualTo(4.5));
      expect(contrasto(c.errore, c.scheda), greaterThanOrEqualTo(4.5));
    });
  }

  test('Le cartelle partono spenti (si accendono dalle prove)', () {
    expect(CartellePage.mostra.value, isFalse);
  });
}
