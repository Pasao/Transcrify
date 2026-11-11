import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/filtro_voci.dart';
import '../core/native.dart';
import '../core/proposte_colore.dart';
import 'cartelle.dart';
import 'common.dart';
import 'molecole/fila_schede.dart';
import 'molecole/fumetto.dart';
import 'molecole/intestazione.dart';
import 'molecole/scelta_colore.dart';
import 'molecole/scheda_trascrizione.dart';
import 'molecole/scorri_giorni.dart';
import 'molecole/stato_vuoto.dart';
import 'molecole/titolo_giorno.dart';
import 'molecole/volo_prima.dart';
import 'molecole/volo_unione.dart';
import 'theme.dart';
import 'trascrizione_aperta.dart';

/// Elimina le trascrizioni [via] quando se ne va «Annulla», se non l'hai toccato (chi chiama le ha già tolte dalla
/// vista). Lo stesso in Trascrivi e in una cartella aperta.
Future<void> eliminaTrascrizioni(BuildContext context, List<Entry> via) async {
  if (await undoable(context, via.length == 1 ? 'Trascrizione eliminata' : '${via.length} trascrizioni eliminate')) return;
  for (final e in via) {
    await Core.deleteEntry(e.at);
  }
}

/// Trascrivi: quello che hai dettato, giorno per giorno. Oggi sta in basso, vicino al pollice.
class TrascriviPage extends StatefulWidget {
  const TrascriviPage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock: le schede non ci finiscono sotto.
  final double bottom;

  /// Si stanno scegliendo le trascrizioni: lo accende «Seleziona» nel menu dell'intestazione, e lo accende anche
  /// tenere premuta una scheda (5 nov: un gesto solo, come nella Galleria); lo spegne «Fine» nella barra (o
  /// «indietro»).
  static final scegliendo = ValueNotifier<bool>(false);

  /// I filtri accesi (6 nov, giro 7): li toccano il pannello del tasto «Filtri» e la fila sotto il titolo
  /// (nell'intestazione, `shell.dart`); la lista qui mostra solo quello che passa, sempre giorno per giorno.
  static final filtro = ValueNotifier<FiltroVoci>(const FiltroVoci());

  /// I filtri che servono, da tutte le trascrizioni (i colori nell'ordine delle cartelle).
  static final possibili = ValueNotifier<FiltriPossibili>(const FiltriPossibili());

  /// Tutte le trascrizioni, anche quelle che i filtri lasciano fuori: le proposte di colore accanto al titolo
  /// (nell'intestazione, `shell.dart`) ne mostrano i titoli.
  static final tutte = ValueNotifier<List<Entry>>(const []);

  @override
  State<TrascriviPage> createState() => _TrascriviPageState();
}

class _TrascriviPageState extends State<TrascriviPage> {
  final Set<String> openDays = {};
  List<Entry>? entries;

  @override
  void initState() {
    super.initState();
    Core.addListener(_load);
    TrascriviPage.scegliendo.addListener(_modoScelta);
    TrascriviPage.filtro.addListener(_filtrata);
    _load();
    // Le proposte di «Colora da sola», accanto al titolo (poi le rilegge quando il nativo ne ha di nuove).
    unawaited(ProposteColore.leggi());
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    TrascriviPage.scegliendo.removeListener(_modoScelta);
    TrascriviPage.filtro.removeListener(_filtrata);
    _scroll.dispose();
    super.dispose();
  }

  /// Le letture si possono accavallare: vale solo l'ultima.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final tutte = await Core.history();
    if (!mounted || n != _loads) return;
    TrascriviPage.tutte.value = tutte;
    final filtro = TrascriviPage.filtro.value;
    TrascriviPage.possibili.value = FiltriPossibili.da(tutte, [for (final k in Cartelle.da(tutte, const {})) k.colore], filtro);
    final now = tutte.where((x) => !_deleting.contains(x.at) && filtro.ammette(x)).toList();
    // Il nativo avvisa spesso (la pillola, gli argomenti): se non è cambiato niente, non si ridisegna niente.
    if (listEquals(now, entries) && _giorniDel == _oggi) return;
    setState(() => entries = now);
    if (VoloPrima.aspetta) _accogliPrima();
  }

  /// Si accoglie già la prima trascrizione dell'introduzione: una volta sola.
  bool _accoglie = false;

  /// Si entra dalla prova (10 nov): la prima trascrizione arriva in volo dal centro (`VoloPrima`) sulla più nuova;
  /// la scheda vera resta nascosta finché la copia non è atterrata.
  Future<void> _accogliPrima() async {
    final e = entries?.fold<Entry?>(null, (a, b) => a == null || b.at.isAfter(a.at) ? b : a);
    if (_accoglie || e == null) return;
    _accoglie = true;
    setState(() => _inVolo.add(e.at));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await VoloPrima.arriva(_inVista([e]).firstOrNull);
    if (mounted) setState(() => _inVolo.remove(e.at));
  }

  /// Tutte, anche quelle appena cancellate e quelle che i filtri lasciano fuori: l'unione le cerca qui.
  List<Entry> get _tutte => TrascriviPage.tutte.value;

  /// Cambiati i filtri: la lista si rifà e torna in fondo, sulle più nuove (la lista cresce dal basso).
  void _filtrata() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  /// Le trascrizioni appena cancellate: spariscono subito, ma per qualche secondo si possono riavere.
  /// Si cancellano davvero solo quando il messaggio "Annulla" se ne va.
  final _deleting = <DateTime>{};

  Future<void> _delete(List<Entry> gone) async {
    setState(() {
      _deleting.addAll(gone.map((e) => e.at));
      entries = entries?.where((x) => !_deleting.contains(x.at)).toList();
    });
    await eliminaTrascrizioni(context, gone);
    _deleting.removeAll(gone.map((e) => e.at));
    _load();
  }

  /// Le trascrizioni scelte, nell'ordine dei tocchi (l'unione segue quest'ordine). Mentre scegli, toccarne una la
  /// sceglie invece di aprirla.
  final selected = <DateTime>{};

  /// Si sta scegliendo (anche se non ne hai ancora scelta nessuna). Tornando su Trascrivi si riparte da com'era.
  late bool _scegliendo = TrascriviPage.scegliendo.value;

  void _modoScelta() => setState(() {
    _scegliendo = TrascriviPage.scegliendo.value;
    if (!_scegliendo) selected.clear();
  });

  /// Comincia o finisce di scegliere: la pagina e chi ascolta l'interruttore (il menu dell'intestazione) insieme.
  void _scegli(bool si) {
    setState(() {
      _scegliendo = si;
      if (!si) selected.clear();
    });
    TrascriviPage.scegliendo.value = si;
  }

  /// Finito di scegliere: via la barra, le schede tornano come prima.
  void _fineScelta() => _scegli(false);

  void _toggle(Entry e) {
    HapticFeedback.selectionClick();
    setState(() => selected.contains(e.at) ? selected.remove(e.at) : selected.add(e.at));
  }

  /// Tenuta premuta: la sceglie (e si comincia a scegliere, se non si stava già scegliendo); mentre scegli, come un tocco.
  void _tieni(Entry e) {
    if (_scegliendo) return _toggle(e);
    _scegli(true);
    setState(() => selected.add(e.at));
  }

  List<Entry> get _chosen => [
    for (final e in entries ?? <Entry>[])
      if (selected.contains(e.at)) e,
  ];

  static String _testo(List<Entry> voci) => voci.map((e) => e.text).join('\n\n');

  Future<void> _copia(List<Entry> voci) async {
    await Clipboard.setData(ClipboardData(text: _testo(voci)));
    HapticFeedback.mediumImpact();
    _fineScelta();
  }

  Future<void> _condividi(List<Entry> voci) async {
    await Core.share(_testo(voci));
    _fineScelta();
  }

  /// Offuscate (o di nuovo in vista) tutte insieme, in una scrittura.
  Future<void> _rendiPrivate(List<Entry> voci, bool privata) async {
    await Segni.rendiPrivate(voci.map((e) => e.at), privata);
    _load();
  }

  /// La rosa sopra «Colore», per tutte le scelte: si vede subito sulle schede; «Annulla» rimette a ognuna il suo.
  void _coloraScelte(Rect dove) =>
      apriSceltaColore(context, sopra: dove, prima: {for (final e in _chosen) e.at: e.colore}, onCambiati: (_) => _load());

  /// Una copia di una scheda, da far muovere sopra la pagina (il volo dell'unione).
  static Widget _copiaDi(Entry e, double larga) => SchedaTrascrizione(entry: e, width: larga, onOpen: () {}, onDelete: () {});

  /// Le schede vere sullo schermo (una chiave per trascrizione): da dove parte il volo dell'unione.
  final _chiavi = <DateTime, GlobalKey>{};

  Rect? _dove(DateTime at) {
    final c = _chiavi[at]?.currentContext;
    return c == null ? null : dovSta(c);
  }

  /// Quelle che si vedono, nell'ordine, con dove stanno e la loro copia.
  List<(Rect, Widget)> _inVista(Iterable<Entry> voci) => [
    for (final e in voci)
      if (_dove(e.at) case final r?) (r, _copiaDi(e, r.width)),
  ];

  /// Le schede nascoste mentre le loro copie volano (e la scheda unita, finché non è arrivata).
  final _inVolo = <DateTime>{};

  /// «Unisci» nella barra (5 nov: «ho toccato Unisci perché volevo unire»): si uniscono subito, nell'ordine in cui
  /// le hai scelte. Se hanno colori diversi (o qualcuna non ne ha), prima spuntano i loro colori sopra «Unisci»:
  /// un tocco sceglie quello della scheda unita e unisce.
  Future<void> _unisciScelte(Rect dove) async {
    final ordine = [for (final at in selected) at];
    final colori = [for (final c in {for (final e in _chosen) e.colore}) c];
    (Colore?,)? colore;
    if (colori.length > 1) {
      colore = await apriColoreUnione(context, sopra: dove, colori: colori);
      if (colore == null || !mounted) return;
    }
    _fineScelta();
    _unisci(ordine, colore: colore);
  }

  /// Le unisce nel nativo (una scrittura; poi il colore scelto, se c'è). Intanto le schede volano sulla prima e la
  /// scheda unita batte al suo posto (`voloUnione`); solo dopo arriva «Annulla», più a lungo del solito, che le
  /// rimette com'erano col volo al contrario (`voloSeparazione`).
  Future<void> _unisci(List<DateTime> ordine, {(Colore?,)? colore}) async {
    final prima = [
      for (final at in ordine) ?_tutte.where((e) => e.at == at).firstOrNull,
    ];
    final schede = _inVista(prima);
    setState(() => _inVolo.addAll(ordine));
    final fusa = Segni.unisci(ordine).then((e) async {
      if (e != null && colore != null) await Segni.colora([e.at], colore.$1);
      return e;
    });
    Future<(Rect, Widget)?> arrivo() async {
      final e = await fusa;
      if (e == null || !mounted) return null;
      await _load();
      await WidgetsBinding.instance.endOfFrame;
      return _inVista(_tutte.where((x) => x.at == e.at)).firstOrNull;
    }

    if (schede.isNotEmpty) await voloUnione(context, schede: schede, arrivo: arrivo());
    final e = await fusa;
    if (!mounted) return;
    setState(() => _inVolo.removeAll(ordine));
    if (e == null) return;
    await _load();
    if (!mounted) return;
    if (await undoable(context, 'Trascrizioni fuse', durata: Durata.annullaUnione)) await _separa(e, prima);
  }

  /// «Annulla» dell'unione: le trascrizioni tornano esattamente com'erano, e si vede: la scheda unita torna sulla
  /// prima e da lei le altre volano ai loro posti.
  Future<void> _separa(Entry unita, List<Entry> prima) async {
    final da = _inVista(_tutte.where((x) => x.at == unita.at)).firstOrNull;
    final nascoste = {unita.at, ...prima.map((e) => e.at)};
    setState(() => _inVolo.addAll(nascoste));
    Future<List<(Rect, Widget)>> rimesse() async {
      await Segni.rimetti(prima);
      await _load();
      await WidgetsBinding.instance.endOfFrame;
      return _inVista(prima);
    }

    final tornano = rimesse();
    if (da != null && mounted) await voloSeparazione(context, unita: da, schede: tornano);
    await tornano;
    if (mounted) setState(() => _inVolo.removeAll(nascoste));
  }

  void _deleteChosen() {
    final gone = _chosen;
    _fineScelta();
    _delete(gone);
  }

  /// Le azioni sulle scelte, ognuna col suo nome. «Unisci» solo da due in su; «Offusca» le copre, «Mostra» se lo
  /// sono già tutte.
  List<AzioneScelte> get _azioniScelte {
    final voci = _chosen;
    if (voci.isEmpty) return const [];
    final private = voci.every((e) => e.privata);
    return [
      SelectionBar.colore(_coloraScelte),
      (Icons.content_copy_rounded, 'Copia', (_) => _copia(voci)),
      (Icons.share_rounded, 'Condividi', (_) => _condividi(voci)),
      if (voci.length >= 2) (Icons.call_merge_rounded, 'Unisci', _unisciScelte),
      if (Offusca.azione(coperta: private) case (final icona, final nome)) (icona, nome, (_) => _rendiPrivate(voci, !private)),
      (Icons.delete_outline_rounded, 'Elimina', (_) => _deleteChosen()),
    ];
  }

  void _open(Entry e) => openEntry(context, e, onDelete: () => _delete([e]));

  final _scroll = ScrollController();

  /// Ogni giorno: serve a sapere quale giorno si sta guardando.
  final _dayKeys = <String, GlobalKey>{};

  /// Dove sta un giorno nella lista (0 è lo spazio in fondo, 1 oggi): quando arriva un giorno nuovo,
  /// gli altri tengono le loro schede invece di rifarle.
  int? _indexOf(Key key) {
    final g = _groups;
    for (var i = 0; i < g.length; i++) {
      if (_dayKeys[g[i].$1] == key) return g.length - i;
    }
    return null;
  }

  /// Il giorno a quell'altezza dello schermo (al centro, in cima): l'ultimo che comincia sopra quel punto.
  /// La lista costruisce solo i giorni attorno a quello che si vede: si guardano quelli.
  String? _dayInView(double middle) {
    String? found;
    var foundTop = double.negativeInfinity;
    for (final (label, _) in _groups) {
      final box = _dayKeys[label]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= middle && top > foundTop) (found, foundTop) = (label, top);
    }
    return found ?? (_groups.isEmpty ? null : _groups.first.$1);
  }

  /// Le trascrizioni in gruppi per giorno, dal più vecchio (in alto) a oggi (in basso, vicino al pollice).
  /// Si rifanno solo quando cambiano le trascrizioni, o il giorno («Oggi» diventa «Ieri»).
  List<(String, List<Entry>)> get _groups {
    final list = entries ?? const <Entry>[];
    final oggi = _oggi;
    if (!identical(list, _giorniDi) || oggi != _giorniDel) {
      final out = <(String, List<Entry>)>[];
      for (final e in list) {
        final label = dayLabel(e.at);
        if (out.isNotEmpty && out.last.$1 == label) {
          out.last.$2.add(e);
        } else {
          out.add((label, [e]));
        }
      }
      _giorni = out.reversed.toList();
      _giorniDi = list;
      _giorniDel = oggi;
    }
    return _giorni;
  }

  List<(String, List<Entry>)> _giorni = const [];
  List<Entry>? _giorniDi;
  DateTime? _giorniDel;

  static DateTime get _oggi {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Un giorno aperto («Tutte»): le schede su due colonne.
  bool _aperto(String label) => openDays.contains(label);

  /// Un giorno: il titolo, poi le sue schede (in fila, o su due colonne se l'hai aperto).
  Widget _giorno(String label, List<Entry> items) => Column(
    key: _dayKeys.putIfAbsent(label, GlobalKey.new),
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: TitoloGiorno.margine,
        child: TitoloGiorno(
          giorno: label,
          quante: items.length,
          aperto: items.length >= 4 ? openDays.contains(label) : null,
          onApri: () => setState(() => openDays.contains(label) ? openDays.remove(label) : openDays.add(label)),
        ),
      ),
      AnimatedSize(
        duration: Durata.normale,
        curve: Curva.standard,
        alignment: Alignment.topCenter,
        child: _aperto(label)
            // Il giorno aperto: due colonne, si legge tutto senza scorrere di lato.
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [for (final e in items) _card(e, width: w)],
                    );
                  },
                ),
              )
            : FilaSchede(chiave: label, voci: items, scheda: _card),
      ),
    ],
  );

  Widget _card(Entry e, {double? width}) => SchedaTrascrizione(
    key: _chiavi.putIfAbsent(e.at, GlobalKey.new),
    entry: e,
    width: width ?? SchedaTrascrizione.larga,
    selected: selected.contains(e.at),
    selecting: _scegliendo,
    nascosta: _inVolo.contains(e.at),
    onOpen: _scegliendo ? () => _toggle(e) : () => _open(e),
    onTieni: () => _tieni(e),
    onDelete: () => _delete([e]),
  );

  @override
  Widget build(BuildContext context) {
    final list = entries;
    final page = list == null
        ? const SizedBox.shrink()
        : list.isEmpty
        // Da vuota la pagina non scorre: non c'è niente sotto.
        ? (_tutte.isEmpty
              ? StatoVuoto(titolo: 'Oggi', frase: 'Quello che detti compare qui,\ngiorno per giorno.', bottom: widget.bottom)
              : StatoVuoto(frase: 'Niente con questi filtri.\nToccane uno acceso per spegnerlo.', bottom: widget.bottom))
        // Le schede stanno in basso, dove arriva il pollice; se sono tante, si scorre.
        // Si costruiscono solo i giorni che si vedono (e i vicini); la lista al contrario parte dal fondo, da oggi.
        : ScorriGiorni(
            controller: _scroll,
            bottom: widget.bottom,
            giornoA: _dayInView,
            child: ListView.builder(
              controller: _scroll,
              // Si apre dal fondo: oggi è subito lì.
              reverse: true,
              // In cima (dove finisce, il giorno più vecchio) lo spazio delle pillole: arrivati lì il primo giorno sta
              // sotto di loro, e le pillole galleggiano sul fondo vuoto.
              padding: const EdgeInsets.only(top: Intestazione.sottoPillole),
              itemCount: _groups.length + 1,
              findChildIndexCallback: _indexOf,
              itemBuilder: (context, i) {
                // Mentre scegli, le ultime salgono sopra la barra (più alta del Dock, di cui prende il posto).
                if (i == 0) {
                  return AnimatedContainer(
                    duration: Durata.scelta,
                    curve: Curva.standard,
                    height: widget.bottom + 24 + ConSelezione.spazio(_scegliendo),
                  );
                }
                final (label, items) = _groups[_groups.length - i];
                return _giorno(label, items);
              },
            ),
          );
    // Le azioni sulle trascrizioni scelte, in fondo al posto del Dock: le stesse delle note.
    return ConSelezione(
      bottom: widget.bottom,
      bar: !_scegliendo ? null : SelectionBar(quante: selected.length, onClose: _fineScelta, actions: _azioniScelte),
      child: page,
    );
  }
}
