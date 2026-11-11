import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native.dart';

/// La regola di un'etichetta (7 nov, sua richiesta: «Colora da sola» solo con regole scritte da te, mai a caso).
/// - [regola]: di cosa parlano le trascrizioni da mettere qui («Metti qui le trascrizioni che parlano di…»).
/// - [offuscaSempre]: quelle colorate così arrivano già offuscate.
typedef RegolaColore = ({String regola, bool offuscaSempre});

/// Un'etichetta proposta da Groq («Proponi etichette», 10 nov): il nome e la sua regola.
typedef PropostaEtichetta = ({String nome, String regola});

/// Una regola nuova proposta da Groq per un'etichetta che hai già («Proponi regole», 10 nov).
typedef PropostaRegola = ({Colore colore, String nome, String regola});

/// Le regole delle etichette: le tiene il nativo (`regoleColori`, `salvaRegola`), che le usa per colorare da solo
/// soltanto quando è sicuro. Qui si leggono e si salvano dalle Impostazioni → Etichette (10 nov: via dalla rosa).
abstract final class RegoleColori {
  static const _ch = MethodChannel('transcrify/core');

  /// Chiave del colore («tinta:luce») → la sua regola. Solo i colori che ne hanno una.
  static final tutte = ValueNotifier<Map<String, RegolaColore>>(const {});

  static RegolaColore? di(Colore c) => tutte.value[c.chiave];

  static Future<void> leggi() async {
    final m = await Core.chiedi('regoleColori');
    if (m is! Map) return;
    tutte.value = {
      for (final MapEntry(:key, :value) in m.entries)
        // Quella che viene dal nome (`daNome`) vale come vuota: la regola di base, che segue il nome.
        if (value is Map)
          key as String: (
            regola: value['daNome'] == true ? '' : value['regola'] as String? ?? '',
            offuscaSempre: value['offuscaSempre'] as bool? ?? false,
          ),
    };
  }

  /// Salva la regola di [colore]; una regola vuota e senza «offusca sempre» la toglie (vuota, il nativo usa il nome
  /// dell'etichetta). Solo se è cambiata. Torna quante trascrizioni ha offuscato adesso (accendendo «Offusca sempre»
  /// il nativo copre anche quelle che l'etichetta ha già).
  static Future<int> salva(Colore colore, String regola, bool offuscaSempre) async {
    final pulita = regola.trim();
    final prima = di(colore);
    if (prima?.regola == pulita && prima?.offuscaSempre == offuscaSempre) return 0;
    if (prima == null && pulita.isEmpty && !offuscaSempre) return 0;
    tutte.value = {
      for (final MapEntry(:key, :value) in tutte.value.entries)
        if (key != colore.chiave) key: value,
      if (pulita.isNotEmpty || offuscaSempre) colore.chiave: (regola: pulita, offuscaSempre: offuscaSempre),
    };
    final m = await Core.chiedi('salvaRegola', {'colore': colore.chiave, 'regola': pulita, 'offuscaSempre': offuscaSempre});
    return (m is Map ? m['offuscate'] as num? : null)?.toInt() ?? 0;
  }

  /// Un'etichetta ha appena preso il nome (10 nov): il nativo colora le trascrizioni di prima che ne parlano. Torna
  /// quali ha colorato (per «Annulla»); nessuna se non ne ha trovate.
  static Future<List<Object?>> coloraRetro(Colore colore) async {
    final m = await Core.chiedi('coloraRetro', {'colore': colore.chiave});
    return m is Map ? (m['ids'] as List?) ?? const [] : const [];
  }

  /// «Annulla» di [coloraRetro]: quelle tornano com'erano.
  static Future<void> annullaColoraRetro(List<Object?> ids) => Core.chiedi('annullaColoraRetro', {'ids': ids});

  /// «Proponi etichette» (10 nov): il nativo manda a Groq solo i TITOLI delle trascrizioni e torna da 4 a 8 etichette
  /// nuove (non quelle che hai già). Un errore (senza chiave, senza rete, risposta tagliata) arriva come
  /// `PlatformException`, col suo messaggio: chi chiede lo mostra.
  static Future<List<PropostaEtichetta>> proponi() async {
    if (Core.preview.value) return const [];
    final l = await _ch.invokeMethod('proponiEtichette') as List?;
    return [
      for (final m in l ?? const [])
        if (m is Map) (nome: m['nome'] as String? ?? '', regola: m['regola'] as String? ?? ''),
    ];
  }

  /// «Proponi regole» (10 nov): il nativo manda a Groq solo i TITOLI e le etichette con la regola di adesso; torna
  /// una regola nuova per quelle che cambiano. Gli errori arrivano come in [proponi].
  static Future<List<PropostaRegola>> proponiRegole() async {
    if (Core.preview.value) return const [];
    final l = await _ch.invokeMethod('proponiRegole') as List?;
    return [
      for (final m in l ?? const [])
        if (m is Map)
          if (Colore.da(m['colore'] as String?) case final c?) (colore: c, nome: m['nome'] as String? ?? '', regola: m['regola'] as String? ?? ''),
    ];
  }
}
