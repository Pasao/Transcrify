import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/regole_colori.dart';
import '../atomi.dart';
import '../ds.dart';

/// Un'etichetta nelle Impostazioni → Etichette (10 nov: tolte dalla rosa, «troppa roba»): il puntino, il nome e quante
/// trascrizioni ha, il cestino ([onTogli]); sotto la sua regola (di cosa parlano: vuota vale il nome, che si legge
/// come suggerimento: 10 nov, «alcune etichette sono doppie», il nome scritto due volte) e «Offusca sempre». La regola
/// si salva quando lasci il campo; l'interruttore subito. [onCambia] riceve tutte e due. [doppio]: un altro colore ha
/// lo stesso nome; sotto si legge quale colore è questo.
class RigaEtichetta extends StatefulWidget {
  const RigaEtichetta({super.key, required this.colore, required this.nome, required this.quante, required this.regola, required this.onCambia, required this.onTogli, this.doppio = false});

  final Colore colore;

  /// Il nome che le hai dato; null se non ne ha (allora si vede quello della tavolozza).
  final String? nome;

  /// Quante trascrizioni ha.
  final int quante;
  final RegolaColore? regola;

  /// La regola scritta (uguale al nome: vuota) e «Offusca sempre».
  final void Function(String regola, bool offuscaSempre) onCambia;
  final VoidCallback onTogli;
  final bool doppio;

  @override
  State<RigaEtichetta> createState() => _RigaEtichettaState();
}

class _RigaEtichettaState extends State<RigaEtichetta> {
  late final _regola = TextEditingController(text: _scritta);
  final _fuoco = FocusNode();

  /// Quella salvata; senza, il campo è vuoto e vale il nome (il suggerimento).
  String get _scritta => widget.regola?.regola ?? '';

  bool get _offusca => widget.regola?.offuscaSempre ?? false;

  @override
  void initState() {
    super.initState();
    _fuoco.addListener(() {
      if (!_fuoco.hasFocus) _salva();
    });
  }

  @override
  void didUpdateWidget(RigaEtichetta prima) {
    super.didUpdateWidget(prima);
    // Rimessa da fuori («Annulla»): il campo segue, se non lo stai scrivendo.
    if (!_fuoco.hasFocus && _regola.text != _scritta) _regola.text = _scritta;
  }

  @override
  void dispose() {
    _fuoco.dispose();
    _regola.dispose();
    super.dispose();
  }

  /// Uguale al nome vale come vuota: la regola di base resta quella del nativo.
  String get _daSalvare => _regola.text.trim() == (widget.nome ?? '').trim() ? '' : _regola.text;

  void _salva([bool? offusca]) => widget.onCambia(_daSalvare, offusca ?? _offusca);

  @override
  Widget build(BuildContext context) {
    final c = context.col, tavolozza = Tinte.nome(widget.colore.tinta, widget.colore.luce), nome = widget.nome ?? tavolozza;
    return Scheda(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spazio.s2,
        children: [
          Row(
            spacing: Spazio.s2,
            children: [
              Icon(Icons.circle, size: Misura.iconaPiccola, color: PuntoColore.di(context, widget.colore)),
              Expanded(child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.titoloScheda.copyWith(color: c.testo))),
              Text(widget.quante == 1 ? '1 trascrizione' : '${widget.quante} trascrizioni', style: Testo.piccolo.copyWith(color: c.testoSecondario)),
              if (widget.nome != null || widget.regola != null)
                IconButton(
                  tooltip: "Togli l'etichetta",
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onTogli,
                  icon: Icon(Icons.delete_outline_rounded, size: Misura.iconaMedia, color: c.testoSecondario),
                ),
            ],
          ),
          if (widget.doppio) Text('Due colori con questo nome: questo è $tavolozza', style: Testo.piccolo.copyWith(color: c.testoSecondario)),
          TextField(
            controller: _regola,
            focusNode: _fuoco,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            style: Testo.testo.copyWith(color: c.testo),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.nome == null ? 'di cosa parlano' : 'di cosa parlano (vuota: «${widget.nome}»)',
              prefixIcon: Icon(Icons.rule_rounded, size: Misura.iconaPiccola, color: c.testoSecondario),
            ),
            onSubmitted: (_) => _salva(),
          ),
          Row(
            children: [
              Expanded(child: Text('Offusca sempre', style: Testo.testo.copyWith(color: c.testo))),
              Switch(value: _offusca, onChanged: _salva),
            ],
          ),
        ],
      ),
    );
  }
}
