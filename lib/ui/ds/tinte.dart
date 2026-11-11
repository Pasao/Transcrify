import 'dart:math' as math;

import 'package:flutter/material.dart';

/// colore/: la tavolozza delle trascrizioni (Figma D1–D2), 16 tinte × 7 luci, in HSL. Un colore = (tinta, luce).
/// Sta qui e basta: il nativo salva solo «tinta:luce» e non lo disegna.
abstract final class Tinte {
  /// Le tinte (gradi HSL) e i loro nomi: il nome di una cartella finché non gliene dai uno tuo. Le prime sette sono
  /// quelle di sempre; le altre nove (6 nov) riempiono il giro della rosa ([rosaFuori]): sedici tinte quasi a passo
  /// uguale (da 15° a 28° l'una dall'altra, perché le sette di prima restano dove sono). Si aggiungono solo in fondo:
  /// «tinta:luce» già salvato non cambia colore.
  static const tonalita = <double>[4, 24, 46, 140, 192, 222, 275, 68, 90, 113, 166, 207, 248, 293, 315, 338];
  static const nomi = [
    'Rosso', 'Arancio', 'Giallo', 'Verde', 'Azzurro', 'Blu', 'Viola', //
    'Lime', 'Pistacchio', 'Prato', 'Menta', 'Cielo', 'Indaco', 'Orchidea', 'Magenta', 'Rosa',
  ];

  /// Le tinte nell'ordine del giro dei colori (dal rosso al rosa): la ruota dei colori, le cartelle, la rosa.
  static final giro = List<int>.generate(tonalita.length, (i) => i)..sort((a, b) => tonalita[a].compareTo(tonalita[b]));

  /// La rosa dei colori (6 nov, al posto della griglia 7 × 7): fuori le sedici tinte, vive; dentro una ogni due, otto,
  /// più chiare. Al centro quello scelto.
  static List<(int, int)> get rosaFuori => [for (final t in giro) (t, luceViva(t))];
  static List<(int, int)> get rosaDentro => [for (var i = 0; i < giro.length; i += 2) (giro[i], luceDentro)];

  /// Le [quante] tinte libere più lontane da quelle [occupate] e tra loro (10 nov, «Proponi etichette»: colori ben
  /// distinti): ogni volta quella con più giro libero intorno. Meno, se non ce ne sono abbastanza.
  static List<int> lontane(Set<int> occupate, int quante) {
    final prese = {...occupate}, scelte = <int>[];
    double distanza(int t) {
      if (prese.isEmpty) return giroIntero;
      return prese.map((p) => (tonalita[t] - tonalita[p]).abs()).map((d) => d > giroIntero / 2 ? giroIntero - d : d).reduce(math.min);
    }

    while (scelte.length < quante) {
      final libere = giro.where((t) => !prese.contains(t)).toList();
      if (libere.isEmpty) break;
      final t = libere.reduce((a, b) => distanza(b) > distanza(a) ? b : a);
      prese.add(t);
      scelte.add(t);
    }
    return scelte;
  }

  /// Il giro dei colori, in gradi.
  static const giroIntero = 360.0;

  /// La luce dell'anello di dentro: chiara, ma il puntino si vede ancora sulla carta.
  static const luceDentro = 2;

  /// Le tinte che alla luce della fila si spengono (il giallo diventa senape, l'azzurro verde acqua, il lime oliva):
  /// nella rosa vanno una luce più chiare.
  static const _piuChiare = {2, 4, 7};

  /// La luce viva di una tinta: quella della fila, o una più chiara per quelle in [_piuChiare].
  static int luceViva(int tinta) => _piuChiare.contains(tinta) ? luceFila - 1 : luceFila;

  static const saturazione = 0.62;

  /// Le luci, dalla più chiara alla più scura.
  static const luci = <double>[0.93, 0.86, 0.77, 0.66, 0.54, 0.42, 0.30];

  /// La luce «di base» di una tinta: il suo nome è la tinta e basta («Rosso»; le altre luci «Rosso 2»…).
  static const luceFila = 4;

  /// La luce del fondo di una scheda (e del corpo di una cartella) nel tema chiaro; la linguetta e
  /// la copertura della privata sono una luce più scura.
  static const luceFondo = 1;

  /// Nel tema scuro la stessa tinta, ma bassa: il testo chiaro resta leggibile (contrasto controllato nei test).
  static const luceFondoScuro = 0.22, luceFondoScuroGiu = 0.16;

  /// Nel tema scuro i fondi sono meno saturi (5 nov: «troppo pesanti», il rosso sembrava bordeaux): la tinta si
  /// riconosce, ma non grida. I puntini della tavolozza restano pieni.
  static const saturazioneScuro = 0.26;

  /// Il nome di un colore che non ne ha uno tuo: la tinta, e la luce se non è quella della fila («Rosso», «Rosso 2»).
  static String nome(int tinta, int luce) => luce == luceFila ? nomi[tinta] : '${nomi[tinta]} ${luce + 1}';

  /// Il colore puro della tavolozza: i puntini e la griglia.
  static Color di(int tinta, int luce) => _hsl(tinta, luci[luce]);

  /// Il fondo di una scheda di questa tinta.
  static Color fondo(int tinta, Brightness b) => b == Brightness.light ? di(tinta, luceFondo) : _hsl(tinta, luceFondoScuro, saturazioneScuro);

  /// Una luce più scura del fondo: la copertura della privata, la linguetta della cartella.
  static Color fondoGiu(int tinta, Brightness b) =>
      b == Brightness.light ? di(tinta, luceFondo + 1) : _hsl(tinta, luceFondoScuroGiu, saturazioneScuro);

  /// Il dorso di una cartella (la parte dietro, con la linguetta). Nel chiaro una luce più scura del davanti, come
  /// [fondoGiu]. Nel tema scuro invece più CHIARO del davanti (6 nov: «la cartella rossa è uguale allo sfondo»: scurita
  /// diventava il marrone della pagina): staccato dalla pagina e dal davanti, con un contrasto misurato nei test.
  static Color dorso(int tinta, Brightness b) => b == Brightness.light ? fondoGiu(tinta, b) : _hsl(tinta, luceDorsoScuro, saturazioneScuro);

  /// La luce del dorso di una cartella nel tema scuro (vedi [dorso]).
  static const luceDorsoScuro = 0.30;

  /// Le macchie sfocate sopra la copertura di una privata ([fondoGiu]), 6 nov, giro 6: la stessa tinta, una più chiara,
  /// una più viva e una più scura, che si muovono piano. Nel buio restano basse: il lucchetto si legge.
  static List<Color> macchie(int tinta, Brightness b) => b == Brightness.light
      ? [di(tinta, luceFondo), di(tinta, luceFondo + 2), di(tinta, luceFondo + 3)]
      : [_hsl(tinta, luceDorsoScuro, saturazioneScuro), _hsl(tinta, luceFondoScuro, saturazione / 2), _hsl(tinta, luceFondoScuroGiu / 2, saturazioneScuro)];

  static Color _hsl(int tinta, double luce, [double s = saturazione]) => HSLColor.fromAHSL(1, tonalita[tinta], s, luce).toColor();
}
