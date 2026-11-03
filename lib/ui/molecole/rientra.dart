import 'package:flutter/material.dart';

import '../ds.dart';

/// Un pezzo che dipende da cosa c'è (le pagine di un potere, l'azione accanto a Transcri): se cambia,
/// prima rientra da dov'è uscito, poi esce quello nuovo; mai un cambio sul posto.
/// [id] dice cos'è (null = non c'è niente); [da] è il lato da cui esce.
class Rientra extends StatefulWidget {
  const Rientra({super.key, required this.id, required this.da, required this.child});

  final Object? id;
  final Alignment da;
  final Widget child;

  @override
  State<Rientra> createState() => _RientraState();
}

class _RientraState extends State<Rientra> with SingleTickerProviderStateMixin {
  late final _aperto = AnimationController(vsync: this, duration: Durata.normale, value: widget.id == null ? 0 : 1)
    ..addStatusListener((s) {
      if (s == AnimationStatus.dismissed) _cambia();
    });

  /// Quello che si vede: mentre rientra resta il vecchio.
  late Object? _idVisto = widget.id;
  late Widget _visto = widget.child;

  void _cambia() {
    setState(() {
      _idVisto = widget.id;
      _visto = widget.child;
    });
    if (_idVisto != null) _aperto.forward();
  }

  @override
  void didUpdateWidget(covariant Rientra prima) {
    super.didUpdateWidget(prima);
    if (widget.id == _idVisto) {
      _visto = widget.child;
      if (_idVisto != null) _aperto.forward();
    } else if (_aperto.isDismissed) {
      _cambia();
    } else {
      _aperto.reverse();
    }
  }

  @override
  void dispose() {
    _aperto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = CurvedAnimation(parent: _aperto, curve: Curves.easeInOutCubic);
    return ClipRect(
      child: AnimatedBuilder(
        animation: v,
        builder: (context, child) => Align(
          alignment: widget.da,
          widthFactor: v.value,
          child: Opacity(opacity: v.value, child: child),
        ),
        child: _visto,
      ),
    );
  }
}
