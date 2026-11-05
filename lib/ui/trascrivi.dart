import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
import 'mode_icon.dart';
import 'molecole/stato_vuoto.dart';
import 'molecole/titolo_giorno.dart';
import 'molecole/voce_in_barra.dart';
import 'theme.dart';
import 'transcri.dart';

/// Trascrivi: quello che hai dettato, giorno per giorno. Oggi sta in basso, vicino al pollice.
class TrascriviPage extends StatefulWidget {
  const TrascriviPage({super.key, required this.bottom});

  /// Lo spazio in fondo coperto dal Dock: le schede non ci finiscono sotto.
  final double bottom;

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
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    _scroll.dispose();
    super.dispose();
  }

  /// Le letture si possono accavallare: vale solo l'ultima.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final list = await Core.history();
    if (!mounted || n != _loads) return;
    final now = list.where((x) => !_deleting.contains(x.at)).toList();
    // Il nativo avvisa spesso (la pillola, gli argomenti): se non è cambiato niente, non si ridisegna niente.
    if (listEquals(now, entries) && _giorniDel == _oggi) return;
    setState(() => entries = now);
  }

  /// Le trascrizioni appena cancellate: spariscono subito, ma per qualche secondo si possono riavere.
  /// Si cancellano davvero solo quando il messaggio "Annulla" se ne va.
  final _deleting = <DateTime>{};

  Future<void> _delete(List<Entry> gone) async {
    setState(() {
      _deleting.addAll(gone.map((e) => e.at));
      entries = entries?.where((x) => !_deleting.contains(x.at)).toList();
    });
    if (!await undoable(context, gone.length == 1 ? 'Trascrizione eliminata' : '${gone.length} trascrizioni eliminate')) {
      for (final e in gone) {
        await Core.deleteEntry(e.at);
      }
    }
    _deleting.removeAll(gone.map((e) => e.at));
    _load();
  }

  /// Le trascrizioni scelte tenendole premute. Finché ce n'è almeno una, toccarne un'altra la sceglie invece di aprirla.
  final selected = <DateTime>{};

  void _toggle(Entry e) => setState(() => selected.contains(e.at) ? selected.remove(e.at) : selected.add(e.at));

  List<Entry> get _chosen => [
    for (final e in entries ?? <Entry>[])
      if (selected.contains(e.at)) e,
  ];

  String get _chosenText => _chosen.map((e) => e.text).join('\n\n');

  Future<void> _copyChosen() async {
    await Clipboard.setData(ClipboardData(text: _chosenText));
    HapticFeedback.mediumImpact();
    setState(selected.clear);
  }

  Future<void> _shareChosen() async {
    await Core.share(_chosenText);
    setState(selected.clear);
  }

  void _deleteChosen() {
    final gone = _chosen;
    setState(selected.clear);
    _delete(gone);
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

  /// Il giorno al centro della pagina: l'ultimo che comincia sopra quel punto.
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

  /// Un giorno: il titolo, poi le sue schede (in fila, o su due colonne se l'hai aperto).
  Widget _giorno(String label, List<Entry> items) => Column(
    key: _dayKeys.putIfAbsent(label, GlobalKey.new),
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s5, Spazio.s6, Spazio.s2, Spazio.s3),
        child: TitoloGiorno(
          giorno: label,
          quante: items.length,
          aperto: items.length >= 4 ? openDays.contains(label) : null,
          onApri: () => setState(() => openDays.contains(label) ? openDays.remove(label) : openDays.add(label)),
        ),
      ),
      AnimatedSize(
        duration: Durata.normale,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: openDays.contains(label)
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
            : SizedBox(
                height: 176,
                child: ListView.separated(
                  // Il giorno esce dallo schermo e torna: le schede restano dove le avevi fatte scorrere.
                  key: PageStorageKey(label),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _card(items[i]),
                ),
              ),
      ),
    ],
  );

  Widget _card(Entry e, {double? width}) => _MiniCard(
    key: ValueKey(e.at),
    entry: e,
    width: width ?? _MiniCard.larga,
    selected: selected.contains(e.at),
    selecting: selected.isNotEmpty,
    onOpen: selected.isEmpty ? () => _open(e) : () => _toggle(e),
    onSelect: () => _toggle(e),
    onDelete: () => _delete([e]),
  );

  @override
  Widget build(BuildContext context) {
    final list = entries;
    final page = list == null
        ? const SizedBox.shrink()
        : list.isEmpty
        // Da vuota la pagina non scorre: non c'è niente sotto.
        ? StatoVuoto(titolo: 'Oggi', frase: 'Quello che detti compare qui,\ngiorno per giorno.', bottom: widget.bottom)
        // Le schede stanno in basso, dove arriva il pollice; se sono tante, si scorre.
        // Si costruiscono solo i giorni che si vedono (e i vicini); la lista al contrario parte dal fondo, da oggi.
        : _FastScroll(
            controller: _scroll,
            bottom: widget.bottom,
            dayAt: _dayInView,
            child: ListView.builder(
              controller: _scroll,
              // Si apre dal fondo: oggi è subito lì.
              reverse: true,
              padding: EdgeInsets.zero,
              itemCount: _groups.length + 1,
              findChildIndexCallback: _indexOf,
              itemBuilder: (context, i) {
                // Mentre scegli, le ultime salgono sopra la barra.
                if (i == 0) {
                  return AnimatedContainer(
                    duration: Durata.normale,
                    curve: Curva.standard,
                    height: widget.bottom + 24 + ConSelezione.spazio(selected.isNotEmpty),
                  );
                }
                final (label, items) = _groups[_groups.length - i];
                return _giorno(label, items);
              },
            ),
          );
    // Le azioni sulle trascrizioni scelte, in fondo, sopra il Dock: le stesse delle note.
    return ConSelezione(
      bottom: widget.bottom,
      bar: selected.isEmpty
          ? null
          : SelectionBar(
              label: selected.length == 1 ? '1 trascrizione' : '${selected.length} trascrizioni',
              onClose: () => setState(selected.clear),
              actions: [
                (Icons.content_copy_rounded, 'Copia', _copyChosen),
                (Icons.share_rounded, 'Condividi', _shareChosen),
                (Icons.delete_outline_rounded, 'Elimina', _deleteChosen),
              ],
            ),
      child: page,
    );
  }
}

/// Lo slider veloce, come nella galleria: mentre scorri compare sul bordo destro; se lo prendi corri
/// da un capo all'altro e accanto al dito c'è la data di quello che stai guardando.
class _FastScroll extends StatefulWidget {
  const _FastScroll({required this.controller, required this.bottom, required this.dayAt, required this.child});

  final ScrollController controller;

  /// Lo spazio in fondo coperto dal Dock: lo slider si ferma prima.
  final double bottom;

  /// Il giorno che si vede a questa altezza dello schermo.
  final String? Function(double middle) dayAt;
  final Widget child;

  @override
  State<_FastScroll> createState() => _FastScrollState();
}

class _FastScrollState extends State<_FastScroll> {
  static const _thumb = 56.0;
  bool _visible = false, _dragging = false;
  String? _day;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _show() {
    _hide?.cancel();
    if (!_visible) setState(() => _visible = true);
    if (!_dragging) {
      _hide = Timer(Durata.conferma, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  bool get _usable => widget.controller.hasClients && widget.controller.position.maxScrollExtent > 0;

  /// Da 0 (in alto, le più vecchie) a 1 (in fondo, oggi): la pagina è al contrario, 0 pixel vuol dire oggi.
  double get _at => _usable ? 1 - (widget.controller.offset / widget.controller.position.maxScrollExtent).clamp(0.0, 1.0) : 1;

  void _drag(double dy, double track) {
    final max = widget.controller.position.maxScrollExtent;
    final to = (_at + dy / track).clamp(0.0, 1.0);
    widget.controller.jumpTo(max * (1 - to));
    _readDay();
  }

  void _readDay() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final day = widget.dayAt(box.localToGlobal(Offset.zero).dy + box.size.height / 2);
    if (day != _day) {
      if (_day != null) HapticFeedback.selectionClick();
      setState(() => _day = day);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Le schede del giorno scorrono di lato: quelle non contano.
        if (n.metrics.axis == Axis.vertical && n is ScrollUpdateNotification) _show();
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 4,
            right: 0,
            bottom: widget.bottom + 4,
            left: 0,
            child: LayoutBuilder(
              builder: (context, box) {
                final track = box.maxHeight - _thumb;
                return AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    if (!_usable) return const SizedBox.shrink();
                    return IgnorePointer(
                      ignoring: !_visible,
                      child: AnimatedOpacity(
                        opacity: _visible ? 1 : 0,
                        duration: Durata.veloce,
                        child: Stack(
                          children: [
                            Positioned(
                              right: 0,
                              top: _at * track,
                              height: _thumb,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) {
                                  HapticFeedback.selectionClick();
                                  _hide?.cancel();
                                  setState(() => _dragging = true);
                                  _readDay();
                                },
                                onVerticalDragUpdate: (d) => _drag(d.delta.dy, track),
                                onVerticalDragEnd: (_) {
                                  setState(() => _dragging = false);
                                  _show();
                                },
                                onVerticalDragCancel: () {
                                  setState(() => _dragging = false);
                                  _show();
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_dragging && _day != null)
                                      Padding(padding: const EdgeInsets.only(right: Spazio.s2), child: EtichettaSospesa(_day!)),
                                    // Una zona larga per il dito, attorno a una barretta sottile.
                                    SizedBox(
                                      width: 36,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: AnimatedContainer(
                                          duration: Durata.veloce,
                                          width: _dragging ? 8 : 5,
                                          height: _thumb,
                                          margin: const EdgeInsets.only(right: 3),
                                          decoration: BoxDecoration(
                                            color: _dragging ? context.col.azione : context.col.testoSecondario,
                                            borderRadius: BorderRadius.circular(Raggio.piccolo),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Scheda piccola nel carosello del giorno.
/// Tenendola premuta la scegli, come una nota. Tenendo premuto il cestino la scheda si fa rossa, trema e sparisce.
class _MiniCard extends StatefulWidget {
  const _MiniCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onSelect,
    required this.onDelete,
    this.selected = false,
    this.selecting = false,
    this.width = larga,
  });

  /// La larghezza nel carosello del giorno.
  static const larga = 240.0;

  final Entry entry;
  final double width;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  /// È tra quelle scelte; [selecting]: se ne stanno scegliendo, il cestino si fa da parte.
  final bool selected, selecting;

  @override
  State<_MiniCard> createState() => _MiniCardState();
}

class _MiniCardState extends State<_MiniCard> with SingleTickerProviderStateMixin {
  late final _gone = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100)); // ds:eccezione: la scheda che trema e sparisce (cestino tenuto premuto)

  @override
  void dispose() {
    _gone.dispose();
    super.dispose();
  }

  // Fino a questo punto lasciare annulla; dopo, la scheda è andata.
  static const _commit = 0.6;
  bool _committed = false;

  void _holdStart() {
    _committed = false;
    HapticFeedback.selectionClick();
    _gone.animateTo(_commit, duration: const Duration(milliseconds: 700), curve: Curves.linear).then((_) { // ds:eccezione: come sopra
      if (!mounted || _gone.value < _commit) return;
      _committed = true;
      HapticFeedback.heavyImpact();
      _gone.animateTo(1, duration: Durata.lenta, curve: Curves.easeIn).then((_) {
        if (mounted) widget.onDelete();
      });
    });
  }

  void _holdEnd() {
    if (_committed) return;
    // Ripensamento: torna com'era.
    _gone.animateBack(0, duration: Durata.normale, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.col;
    final entry = widget.entry;
    return AnimatedBuilder(
      animation: _gone,
      builder: (context, child) {
        final v = _gone.value;
        // Prima si arrossa e trema, poi si rimpicciolisce e svanisce.
        // Fino alla soglia: si arrossa e trema sempre di più. Dopo: smette di tremare e svanisce.
        final hold = (v / _commit).clamp(0.0, 1.0);
        final red = hold;
        final shake = v < _commit ? math.sin(v * 140) * 5 * hold : 0.0;
        final out = Curves.easeIn.transform(((v - _commit) / (1 - _commit)).clamp(0.0, 1.0));
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Opacity(
            opacity: 1 - out,
            child: Transform.scale(
              scale: 1 - out * 0.25,
              // Il rosso sopra la scheda, con la sua forma (la scheda è piena: come colorarla).
              // Non un filtro di colore: quello costa un livello in più a ogni scheda, anche ferma.
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: red == 0
                    ? const BoxDecoration()
                    : ShapeDecoration(color: context.col.errore.withValues(alpha: red * 0.55), shape: Scheda.forma(context.col).copyWith(side: BorderSide.none)),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _card(context, tk, entry),
    );
  }

  Widget _card(BuildContext context, Colori tk, Entry entry) {
    final onOpen = widget.onOpen;
    return SizedBox(
      width: widget.width,
      height: 176,
      child: Material(
        // La Scheda del design system: «scelta» = fondo tenue e contorno.
        color: Scheda.fondo(context.col, scelta: widget.selected),
        shape: Scheda.forma(context.col, scelta: widget.selected),
        child: InkWell(
          borderRadius: BorderRadius.circular(Raggio.scheda),
          onTap: onOpen,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onSelect();
          },
          child: Padding(
            // Il cestino non sta attaccato all'angolo: lo stesso respiro del testo, a destra e sotto.
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Anteprima(entry.text, righe: 4, stile: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ),
                ),
                Row(
                  children: [
                    // A sinistra ora e modo: si stringono loro se la scheda è stretta (vista "Tutte").
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(hm(entry.at), style: monoStyle(context), overflow: TextOverflow.clip),
                          ),
                          if (entry.mode != null) ...[const SizedBox(width: 8), _ModeTag(entry.mode!)],
                          if (entry.source != null) ...[const SizedBox(width: 8), SourceIcon(entry.source)],
                        ],
                      ),
                    ),
                    if (widget.selecting)
                      const SizedBox(height: 40)
                    else
                      DeleteButton(onDelete: widget.onDelete, onHoldStart: _holdStart, onHoldEnd: _holdEnd),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Con che modo è stata pulita la trascrizione: l'icona, e nel testo aperto anche il nome.
class _ModeTag extends StatelessWidget {
  const _ModeTag(this.mode, {this.label = false});

  final String mode;
  final bool label;

  static const _names = {'fedele': 'Fedele', 'pulita': 'Pulita', 'riassunto': 'Riassunto'};

  @override
  Widget build(BuildContext context) {
    final color = context.col.testoSecondario;
    final icon = CustomPaint(size: const Size(16, 13), painter: ModeIcon(mode, color));
    if (!label) return Tooltip(message: _names[mode] ?? mode, child: icon);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Flexible(
          child: Text(_names[mode] ?? mode, style: monoStyle(context, size: 12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Il testo intero, aperto dal basso: si può cambiare e si salva da solo.
/// Copia, elimina e «aggiungi a voce» stanno in alto: con i testi lunghi sono subito lì.
/// Apre una trascrizione nella sua scheda (da Trascrivi o da una ricerca). [onDelete] arriva a scheda chiusa;
/// senza, la trascrizione si elimina subito.
void openEntry(BuildContext context, Entry e, {Future<void> Function()? onDelete}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _EntrySheet(
      entry: e,
      onDelete: () async {
        Navigator.pop(sheet);
        if (onDelete != null) return onDelete();
        await Core.deleteEntry(e.at);
        Core.refresh();
      },
    ),
  );
}

class _EntrySheet extends StatefulWidget {
  const _EntrySheet({required this.entry, required this.onDelete});

  final Entry entry;
  final VoidCallback onDelete;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late final _text = TextEditingController(text: widget.entry.text);
  final _sheet = DraggableScrollableController();
  final _focus = FocusNode();

  /// Il testo com'è salvato: quello che arriva a voce si riconosce perché lo allunga.
  late String _saved = widget.entry.text;
  Timer? _saving;

  @override
  void initState() {
    super.initState();
    _text.addListener(_edited);
    Core.addListener(_reload);
    // Scrivendo serve tutto lo spazio che resta sopra la tastiera.
    _focus.addListener(() {
      if (_focus.hasFocus) _sheet.animateTo(0.94, duration: Durata.normale, curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _saving?.cancel();
    _save();
    Core.removeListener(_reload);
    Core.refresh();
    _text.dispose();
    _sheet.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// L'ultimo punto del cursore: Flutter lo cancella quando la tastiera si chiude, ma la voce deve entrare lì.
  int _cursore = -1;

  void _edited() {
    if (_text.selection.isValid) _cursore = _text.selection.end;
    _saving?.cancel();
    _saving = Timer(const Duration(milliseconds: 500), _save); // ds:eccezione: tempo di comportamento (salva mezzo secondo dopo l'ultima lettera)
  }

  /// Un testo svuotato non si salva: per eliminarlo c'è il cestino.
  void _save() {
    final now = _text.text;
    if (now == _saved || now.trim().isEmpty) return;
    _saved = now;
    Core.editEntry(widget.entry.at, now);
  }

  /// Sono arrivate parole a voce: entrano dov'era il cursore, e lui si sposta dopo di loro.
  Future<void> _reload() async {
    final list = await Core.history();
    if (!mounted) return;
    final now = list.where((e) => e.at == widget.entry.at).firstOrNull?.text;
    if (now == null || now == _saved) return;
    final grown = now.length - _saved.length;
    final at = _text.selection.isValid ? _text.selection.baseOffset : _cursore;
    _saved = now;
    final dopo = at >= 0 && at + grown <= now.length ? at + grown : -1;
    _text.value = TextEditingValue(text: now, selection: TextSelection.collapsed(offset: dopo));
    // Il cursore si sposta dopo le parole arrivate: la prossima voce entra lì.
    _cursore = dopo;
  }

  /// Quando la tastiera si chiude sparisce anche il cursore; il punto resta ricordato per la voce.
  double _keyboard = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = MediaQuery.viewInsetsOf(context).bottom;
    if (_keyboard > 0 && now == 0 && _focus.hasFocus) _focus.unfocus();
    _keyboard = now;
  }

  Future<void> _addVoice() async {
    _saving?.cancel();
    _save();
    if (!await transcriReady(context)) return;
    // Il player sta sopra la tastiera: si chiude prima, così non copre il testo.
    if (_focus.hasFocus) {
      _focus.unfocus();
      await Future.delayed(const Duration(milliseconds: 320)); // ds:eccezione: tempo di comportamento (aspetta che la tastiera scenda)
      if (!mounted) return;
    }
    HapticFeedback.heavyImpact();
    // I comandi stanno nella barra (ComandiVoce): niente pannello del Floater sopra.
    await Core.listen(appendTo: widget.entry.at, cursor: _text.selection.isValid ? _text.selection.end : _cursore);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final tk = context.col;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        controller: _sheet,
        initialChildSize: 0.6,
        maxChildSize: 0.94,
        builder: (context, scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(shortStamp(entry.at), style: monoStyle(context, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (entry.mode != null) ...[const SizedBox(width: 10), Flexible(child: _ModeTag(entry.mode!, label: true))],
                      if (entry.source != null) ...[const SizedBox(width: 10), SourceIcon(entry.source)],
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            // Sempre lì, anche in fondo a un testo lungo e sopra la tastiera.
            BarraInFondo(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tk.linea)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: VoceInBarra(at: entry.at, onStart: _addVoice),
                        ),
                        DeleteButton(onDelete: widget.onDelete),
                        ListenableBuilder(
                          listenable: _text,
                          builder: (context, _) => CopyButton(text: _text.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
