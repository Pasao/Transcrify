import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';

/// Un pezzo di un argomento (B6 «PezzoArgomento»): di base il RIASSUNTO; «Originale» mostra quello
/// che avevi scritto. I pezzi corti si mostrano interi (non c'è niente da riassumere).
/// Sotto, da quale nota viene: toccandolo si apre la nota.
class PezzoArgomento extends StatefulWidget {
  const PezzoArgomento({super.key, required this.testo, required this.daNota, required this.onApriNota});

  final String testo;
  final String daNota;
  final VoidCallback onApriNota;

  /// Sotto questa lunghezza il pezzo è già breve: niente riassunto.
  static const breve = 220;

  @override
  State<PezzoArgomento> createState() => _PezzoArgomentoState();
}

class _PezzoArgomentoState extends State<PezzoArgomento> {
  /// I riassunti già fatti, finché l'app è aperta: non si richiedono a ogni visita.
  static final _fatti = <String, String>{};

  bool _originale = false;
  String? _riassunto;

  bool get _lungo => widget.testo.length > PezzoArgomento.breve;

  @override
  void initState() {
    super.initState();
    if (_lungo) _riassumi();
  }

  Future<void> _riassumi() async {
    final pronto = _fatti[widget.testo];
    if (pronto != null) return setState(() => _riassunto = pronto);
    try {
      final r = (await Core.summarize(widget.testo)).trim();
      if (r.isEmpty) return;
      _fatti[widget.testo] = r;
      if (mounted) setState(() => _riassunto = r);
    } catch (_) {
      // Senza rete o chiave resta l'originale: non è un errore da mostrare.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final riassunto = _riassunto;
    final mostraRiassunto = _lungo && !_originale && riassunto != null;
    return Scheda(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Spazio.s2,
        children: [
          AnimatedSize(
            duration: Durata.normale,
            alignment: Alignment.topLeft,
            child: Text(mostraRiassunto ? riassunto : widget.testo, style: Testo.testo.copyWith(color: c.testo)),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onApriNota,
                  child: Text('da «${widget.daNota}» ›', style: Testo.orario.copyWith(color: c.azione), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (_lungo && riassunto != null)
                Bottone(
                  _originale ? 'Riassunto' : 'Originale',
                  tipo: TipoBottone.testo,
                  alto: false,
                  colore: c.testoSecondario,
                  onPressed: () => setState(() => _originale = !_originale),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
