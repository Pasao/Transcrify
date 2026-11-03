import 'package:flutter/services.dart';

import 'native.dart';

/// Una cosa trovata cercando: una nota o una trascrizione, e la frase che c'entra.
class Trovato {
  Trovato(Map m)
    : nota = m['tipo'] == 'nota',
      id = m['id'] as String,
      frase = TextRange(start: m['start'] as int, end: m['end'] as int),
      esatto = m['esatto'] as bool;

  /// Una nota (true) o una trascrizione (false). Di una trascrizione [id] è il suo «at» in millisecondi.
  final bool nota;
  final String id;

  /// Dove sta la frase trovata, nel testo (della nota senza titolo, o della trascrizione).
  final TextRange frase;

  /// Trovata per parola (ci sono tutte le parole cercate) o solo per senso.
  final bool esatto;
}

/// Una categoria fissa, come quelle della galleria, con le frasi chiave dei pezzi che ci stanno dentro.
class Categoria {
  Categoria(Map m)
    : nome = m['nome'] as String,
      frasi = [
        for (final p in (m['pieces'] as List).cast<Map>())
          (note: p['note'] as String, range: TextRange(start: p['start'] as int, end: p['end'] as int)),
      ];

  final String nome;
  final List<({String note, TextRange range})> frasi;
}

/// La ricerca e le categorie, fatte dal motore sul telefono.
abstract final class Ricerca {
  static const _ch = MethodChannel('transcrify/core');

  /// Prima quelle con tutte le parole, poi quelle vicine per senso (se il modello degli argomenti c'è).
  static Future<List<Trovato>> cerca(String testo) async {
    if (Core.preview.value || testo.trim().isEmpty) return [];
    final out = await _ch.invokeMethod('cerca', {'testo': testo}) as List;
    return [for (final m in out.cast<Map>()) Trovato(m)];
  }

  static Future<List<Categoria>> categorie() async {
    if (Core.preview.value) return [];
    final out = await _ch.invokeMethod('categorie') as List;
    return [for (final m in out.cast<Map>()) Categoria(m)];
  }
}
