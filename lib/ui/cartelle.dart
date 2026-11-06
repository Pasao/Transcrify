import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'molecole/cartella_vuota.dart';
import 'molecole/fascia_cartella.dart';
import 'molecole/griglia_cartelle.dart';
import 'molecole/scheda_trascrizione.dart';
import 'molecole/stato_vuoto.dart';
import 'scelta_cartelle.dart';
import 'theme.dart';
import 'trascrivi.dart';
import 'trascrizione_aperta.dart';

export 'molecole/griglia_cartelle.dart' show DatiCartella;

/// Le cartelle (Figma D2): una per ogni colore che ha almeno una trascrizione, nell'ordine del giro dei colori.
abstract final class Cartelle {
  /// Il nome di una cartella: il tuo, se gliel'hai dato, se no quello della tinta («Giallo»).
  static String nome(Colore colore, Map<String, String> nomi) => nomi[colore.chiave] ?? Tinte.nome(colore.tinta, colore.luce);

  /// [voci] dalla più nuova, come le dà il nativo: dentro ogni cartella restano così.
  static List<DatiCartella> da(Iterable<Entry> voci, Map<String, String> nomi) {
    final dentro = <Colore, List<Entry>>{};
    for (final e in voci) {
      if (e.colore case final c?) (dentro[c] ??= []).add(e);
    }
    final colori = dentro.keys.toList()
      ..sort((a, b) => a.tinta != b.tinta ? Tinte.giro.indexOf(a.tinta) - Tinte.giro.indexOf(b.tinta) : a.luce - b.luce);
    return [for (final c in colori) (colore: c, nome: nome(c, nomi), voci: dentro[c]!)];
  }

  /// Nessuna cartella: le sagome di due cartelle vuote, non schede (qui arriveranno cartelle).
  static Widget vuote(double bottom) => StatoVuoto(
    frase: 'Dai un colore a una trascrizione:\nla ritrovi qui, nella sua cartella.',
    bottom: bottom,
    sagome: const [CartellaVuota(), CartellaVuota()],
  );
}

/// La pagina delle cartelle, nel Dock accanto a Trascrivi (6 nov, sua scelta: «solo cartelle che si aprono»): le
/// cartelle disegnate, due per riga. Toccata, una cartella si apre lì dov'era (6 nov, giro 6): una fascia del suo colore
/// con le sue trascrizioni in fila ([FasciaCartella]); una sola aperta alla volta. Tenuta premuta si sceglie, e la barra
/// delle scelte prende il posto del Dock (e la fascia si richiude).
class CartellePage extends StatefulWidget {
  const CartellePage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock.
  final double bottom;

  /// La pagina delle cartelle nel Dock (6 nov, giro 7: «i colori come filtri ne fanno le veci»): nascosta, si riaccende
  /// dalle prove («Mostra le cartelle»). Il codice resta. Vive finché l'app è aperta, come le altre prove.
  static final mostra = ValueNotifier<bool>(false);

  @override
  State<CartellePage> createState() => _CartellePageState();
}

class _CartellePageState extends State<CartellePage> {
  List<Entry>? _voci;

  late final _scelta = SceltaCartelle(onCambiate: _load);

  @override
  void initState() {
    super.initState();
    Core.addListener(_load);
    Segni.nomi.addListener(_ridisegna);
    _scelta.addListener(_ridisegna);
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    Segni.nomi.removeListener(_ridisegna);
    _scelta.dispose();
    super.dispose();
  }

  /// Scegliendo cartelle, quella aperta si richiude: il tocco ora sceglie.
  void _ridisegna() => setState(() {
    if (_scelta.scegliendo) _aperta = null;
  });

  /// La cartella aperta (una sola alla volta).
  Colore? _aperta;

  /// Le trascrizioni appena eliminate da una cartella aperta: spariscono subito, «Annulla» le riporta.
  final _via = <DateTime>{};

  /// Le letture si possono accavallare: vale solo l'ultima.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final voci = await Core.history();
    await Segni.leggiNomi();
    if (mounted && n == _loads) setState(() => _voci = voci);
  }

  /// Apre la cartella toccata, lì dov'era (e chiude quella che lo era).
  void _apri(DatiCartella k) => setState(() => _aperta = k.colore);

  Future<void> _elimina(List<Entry> gone) async {
    setState(() => _via.addAll(gone.map((e) => e.at)));
    await eliminaTrascrizioni(context, gone);
    _via.removeAll(gone.map((e) => e.at));
    await _load();
  }

  /// Una scheda nella fascia: la stessa di Trascrivi (tocco apre, cestino elimina con «Annulla»).
  Widget _scheda(Entry e) => SchedaTrascrizione(
    key: ValueKey(e.at),
    entry: e,
    onOpen: () => openEntry(context, e, onDelete: () => _elimina([e])),
    onDelete: () => _elimina([e]),
  );

  Widget _fascia(DatiCartella k, (double, double) da) => FasciaCartella(
    key: ValueKey(k.colore),
    colore: k.colore,
    nome: k.nome,
    voci: k.voci,
    da: da,
    scheda: _scheda,
    onRinomina: (nome) => Segni.nomina(k.colore, nome),
    onChiudi: () => setState(() => _aperta = null),
  );

  @override
  Widget build(BuildContext context) {
    final voci = _voci;
    if (voci == null) return const SizedBox.shrink();
    final cartelle = Cartelle.da(voci.where((e) => !_via.contains(e.at)), Segni.nomi.value);
    if (cartelle.isEmpty) return Cartelle.vuote(widget.bottom);
    return ConSelezione(
      bottom: widget.bottom,
      bar: _scelta.barra(context, cartelle),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: Spazio.s4, bottom: widget.bottom + Spazio.s6 + ConSelezione.spazio(_scelta.scegliendo)),
        child: AnimatedSize(
          duration: Durata.normale,
          curve: Curva.standard,
          alignment: Alignment.topCenter,
          child: GrigliaCartelle(
            cartelle: cartelle,
            scelte: _scelta.scelte,
            onApri: _apri,
            onScegli: _scelta.scegli,
            aperta: _aperta,
            fascia: _fascia,
          ),
        ),
      ),
    );
  }
}
