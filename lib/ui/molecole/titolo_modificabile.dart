import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Un titolo che si cambia lì dov'è (6 nov, giro 6): il titolo di una trascrizione aperta, il nome di una cartella
/// aperta. Toccato diventa un campo, già pronto, col titolo di adesso tutto scelto (si scrive sopra); sotto
/// «Annulla» e «Fatto», come nel dialogo «Rinomina». «Fatto» (o invio) passa il testo nuovo a [onFatto], pulito dagli
/// spazi: vuoto vuol dire «togli il mio titolo» (chi lo usa torna a quello di base). «Annulla» lascia tutto com'era.
class TitoloModificabile extends StatefulWidget {
  const TitoloModificabile({
    super.key,
    required this.titolo,
    required this.stile,
    required this.onFatto,
    this.suggerimento,
    this.righe = 2,
  });

  final String titolo;
  final TextStyle stile;
  final ValueChanged<String> onFatto;

  /// Quello che si legge nel campo svuotato (di solito il titolo di base).
  final String? suggerimento;

  /// Quante righe al massimo, fermo.
  final int righe;

  @override
  State<TitoloModificabile> createState() => _TitoloModificabileState();
}

class _TitoloModificabileState extends State<TitoloModificabile> {
  TextEditingController? _campo;

  @override
  void dispose() {
    _campo?.dispose();
    super.dispose();
  }

  void _modifica() => setState(() {
    _campo = TextEditingController(text: widget.titolo)..selection = TextSelection(baseOffset: 0, extentOffset: widget.titolo.length);
  });

  void _chiudi() => setState(() {
    _campo?.dispose();
    _campo = null;
  });

  void _fatto() {
    final nuovo = _campo?.text.trim() ?? widget.titolo;
    _chiudi();
    if (nuovo != widget.titolo) widget.onFatto(nuovo);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final campo = _campo;
    return AnimatedSize(
      duration: Durata.veloce,
      curve: Curva.standard,
      alignment: Alignment.topLeft,
      child: campo == null
          ? Semantics(
              button: true,
              hint: 'Cambia il titolo',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _modifica,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Misura.bottoneBasso),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.titolo,
                      maxLines: widget.righe,
                      overflow: TextOverflow.ellipsis,
                      style: widget.stile.copyWith(color: c.testo),
                    ),
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: campo,
                  autofocus: true,
                  style: widget.stile.copyWith(color: c.testo),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _fatto(),
                  decoration: CampoNudo.decorazione.copyWith(
                    hintText: widget.suggerimento,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: Spazio.s2),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.azione, width: Misura.anello)),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    Bottone('Annulla', tipo: TipoBottone.testo, alto: false, onPressed: _chiudi),
                    Bottone('Fatto', tipo: TipoBottone.testo, alto: false, onPressed: _fatto),
                  ],
                ),
              ],
            ),
    );
  }
}
