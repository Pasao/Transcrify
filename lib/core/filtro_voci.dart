import 'package:flutter/foundation.dart';

import 'native.dart';

/// Da dove arriva una trascrizione: i vocali di WhatsApp, quello che hai dettato tu, o quello condiviso da altre app.
enum Fonte {
  whatsapp('WhatsApp'),
  dettate('Dettate'),
  altre('Altre app');

  const Fonte(this.nome);

  final String nome;

  /// [source] è il pacchetto dell'app che l'ha mandato (null se l'hai dettato tu); prima di novembre 2026 si salvava
  /// solo «whatsapp». WhatsApp Business conta come WhatsApp.
  bool ammette(String? source) => switch (this) {
    Fonte.whatsapp => source != null && source.contains('whatsapp'),
    Fonte.dettate => source == null,
    Fonte.altre => source != null && !source.contains('whatsapp'),
  };
}

/// I modi di pulizia, come li salva il nativo, coi loro nomi.
const nomiModi = {'fedele': 'Fedele', 'pulita': 'Pulita', 'riassunto': 'Riassunto'};

/// I filtri di Trascrivi (6 nov, giro 7: tre file, «sono filtri diversi, combinabili»): da dove, come, il colore.
/// Dentro una fila basta uno (WhatsApp O Dettate); tra le file servono tutte (WhatsApp E Pulita). Una fila senza
/// niente acceso lascia passare tutto. Toccare di nuovo quello acceso lo spegne.
@immutable
class FiltroVoci {
  const FiltroVoci({this.fonti = const {}, this.modi = const {}, this.colori = const {}});

  final Set<Fonte> fonti;

  /// Chiavi di [nomiModi].
  final Set<String> modi;
  final Set<Colore> colori;

  static Set<T> _scambia<T>(Set<T> s, T x) => s.contains(x) ? ({...s}..remove(x)) : {...s, x};

  /// Lo stesso filtro con una cosa accesa, o spenta se lo era già.
  FiltroVoci conFonte(Fonte f) => FiltroVoci(fonti: _scambia(fonti, f), modi: modi, colori: colori);
  FiltroVoci conModo(String m) => FiltroVoci(fonti: fonti, modi: _scambia(modi, m), colori: colori);
  FiltroVoci conColore(Colore c) => FiltroVoci(fonti: fonti, modi: modi, colori: _scambia(colori, c));

  bool ammette(Entry e) =>
      (fonti.isEmpty || fonti.any((f) => f.ammette(e.source))) &&
      (modi.isEmpty || modi.contains(e.mode)) &&
      (colori.isEmpty || colori.contains(e.colore));

  /// Quanti filtri sono accesi (il tasto «Filtri» lo dice).
  int get quanti => fonti.length + modi.length + colori.length;

  @override
  bool operator ==(Object other) =>
      other is FiltroVoci && setEquals(other.fonti, fonti) && setEquals(other.modi, modi) && setEquals(other.colori, colori);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(fonti), Object.hashAllUnordered(modi), Object.hashAllUnordered(colori));
}

/// I filtri che servono (6 nov, giro 7: «inutile mostrare un filtro se non c'è niente da filtrare»): solo quelli che
/// lasciano passare almeno una trascrizione ma non tutte. Quelli accesi restano sempre, per poterli spegnere.
@immutable
class FiltriPossibili {
  const FiltriPossibili({this.fonti = const [], this.modi = const [], this.colori = const []});

  final List<Fonte> fonti;
  final List<String> modi;
  final List<Colore> colori;

  /// Da tutte le trascrizioni [voci]; [colori] nell'ordine in cui si mostrano (quello delle cartelle).
  factory FiltriPossibili.da(List<Entry> voci, List<Colore> colori, FiltroVoci acceso) {
    bool serve(bool Function(Entry) passa) {
      final quante = voci.where(passa).length;
      return quante > 0 && quante < voci.length;
    }

    return FiltriPossibili(
      fonti: [
        for (final f in Fonte.values)
          if (acceso.fonti.contains(f) || serve((e) => f.ammette(e.source))) f,
      ],
      modi: [
        for (final m in nomiModi.keys)
          if (acceso.modi.contains(m) || serve((e) => e.mode == m)) m,
      ],
      colori: [
        for (final k in {...colori, ...acceso.colori})
          if (acceso.colori.contains(k) || serve((e) => e.colore == k)) k,
      ],
    );
  }

  bool get vuoti => fonti.isEmpty && modi.isEmpty && colori.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is FiltriPossibili && listEquals(other.fonti, fonti) && listEquals(other.modi, modi) && listEquals(other.colori, colori);

  @override
  int get hashCode => Object.hash(Object.hashAll(fonti), Object.hashAll(modi), Object.hashAll(colori));
}
