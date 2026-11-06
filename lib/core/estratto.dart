import 'package:flutter/services.dart';

/// Il riassunto estrattivo di un testo, fatto dal motore sul telefono (Impostazioni → Prove).
/// Solo lettura: il nativo non scrive niente e non usa la rete.
class Estratto {
  Estratto(Map m)
    : stato = m['stato'] as String,
      modello = m['modello'] as String?,
      ms = m['ms'] as int? ?? 0,
      freddo = m['freddo'] as bool? ?? false,
      errore = m['errore'] as String?,
      frasi = [
        for (final f in (m['frasi'] as List? ?? const []).cast<Map>())
          (testo: f['testo'] as String, dove: TextRange(start: f['start'] as int, end: f['end'] as int)),
      ];

  /// "pronto", "senzaModello" (nessun modello scaricato e scelto) o "errore".
  final String stato;

  /// Il modello che ha dato il senso alle frasi ("preciso" o "leggero").
  final String? modello;

  /// Quanto ci ha messo sul telefono, in millisecondi. [freddo]: compreso il caricamento del modello.
  final int ms;
  final bool freddo;
  final String? errore;

  /// Le frasi scelte, nell'ordine del testo: pulite dai riempitivi, e dove stanno nel testo originale.
  final List<({String testo, TextRange dove})> frasi;

  static const _ch = MethodChannel('transcrify/core');

  static Future<Estratto> di(String testo) async => Estratto(await _ch.invokeMethod('estratto', {'testo': testo}) as Map);
}
