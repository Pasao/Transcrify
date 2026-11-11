import 'package:flutter/material.dart';

import '../ds.dart';

/// Una fila che, se non ci sta, scorre di lato da sola (7 nov: i filtri accesi sotto il titolo, le file del pannello
/// dei filtri). Allineata a sinistra. Quando c'è altro fuori dalla vista il bordo da quella parte sfuma: si capisce
/// che continua.
class FilaScorre extends StatefulWidget {
  const FilaScorre({super.key, required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;

  /// Il margine dentro lo scorrimento: i pezzi partono da qui, ma scorrendo arrivano fino al bordo.
  final EdgeInsets padding;

  @override
  State<FilaScorre> createState() => _FilaScorreState();
}

class _FilaScorreState extends State<FilaScorre> {
  final _scorri = ScrollController();

  /// C'è altro a sinistra, a destra.
  bool _prima = false, _dopo = false;

  void _guarda() {
    if (!_scorri.hasClients) return;
    final p = _scorri.position;
    final prima = p.pixels > p.minScrollExtent, dopo = p.pixels < p.maxScrollExtent;
    if (prima == _prima && dopo == _dopo) return;
    setState(() {
      _prima = prima;
      _dopo = dopo;
    });
  }

  @override
  void initState() {
    super.initState();
    _scorri.addListener(_guarda);
  }

  @override
  void dispose() {
    _scorri.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dopo ogni disegno: la fila può essere cambiata (un filtro in più o in meno).
    WidgetsBinding.instance.addPostFrameCallback((_) => _guarda());
    final fila = SingleChildScrollView(
      controller: _scorri,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: Row(spacing: Spazio.s2, children: widget.children),
    );
    // Della tinta conta solo quanto è piena: dove è vuota, la fila sfuma. Sempre la stessa maschera, così lo
    // scorrimento non si perde quando il bordo cambia.
    final pieno = context.col.testo, vuoto = pieno.withValues(alpha: 0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final bordo = r.width == 0 ? 0.0 : (Spazio.s8 / r.width).clamp(0.0, 0.5);
        return LinearGradient(
          colors: [_prima ? vuoto : pieno, pieno, pieno, _dopo ? vuoto : pieno],
          stops: [0, bordo, 1 - bordo, 1],
        ).createShader(r);
      },
      child: fila,
    );
  }
}
