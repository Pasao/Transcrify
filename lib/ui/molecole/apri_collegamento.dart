import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../atomi.dart';
import '../ds.dart';

/// Un campo dove scrivi (una nota, una trascrizione) coi collegamenti che si aprono (7 nov: «i link non si aprono»).
/// Toccare un link nel campo ci mette il cursore, come per scriverci: subito sotto spunta un piccolo «Apri», che lo
/// apre con l'app giusta. Scrivere non cambia: il tasto sta sopra la pagina e non prende la tastiera.
class ApriCollegamento extends StatefulWidget {
  const ApriCollegamento({super.key, required this.testo, required this.child});

  final TextEditingController testo;

  /// Il campo.
  final Widget child;

  @override
  State<ApriCollegamento> createState() => _ApriCollegamentoState();
}

class _ApriCollegamentoState extends State<ApriCollegamento> {
  final _campo = GlobalKey();
  final _aggancio = LayerLink();
  final _portale = OverlayPortalController();

  /// Il collegamento dove sta il cursore, e dove sta il cursore nel campo (sotto si mette «Apri»).
  Pezzo? _qui;
  Rect? _dove;
  bool _acceso = false;

  @override
  void initState() {
    super.initState();
    widget.testo.addListener(_guarda);
  }

  @override
  void dispose() {
    widget.testo.removeListener(_guarda);
    super.dispose();
  }

  void _guarda() {
    final s = widget.testo.selection;
    final p = _acceso && s.isValid && s.isCollapsed ? Formato.collegamentoIn(widget.testo.text, s.baseOffset) : null;
    if (p == null) {
      _qui = null;
      if (_portale.isShowing) _portale.hide();
      return;
    }
    _qui = p;
    // Dove cade il link si sa a campo disegnato.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _qui != p) return;
      setState(() => _dove = PuntoNelCampo.cursore(_campo, p.inizio));
      if (!_portale.isShowing) _portale.show();
    });
  }

  void _apri() {
    final uri = _qui?.uri;
    if (uri == null) return;
    _portale.hide();
    Formattato.apri(uri);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _aggancio,
    child: OverlayPortal(
      controller: _portale,
      overlayChildBuilder: (_) {
        final dove = _dove;
        if (dove == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _aggancio,
            showWhenUnlinked: false,
            offset: Offset(dove.left, dove.bottom + Spazio.s1),
            // Toccarlo non è toccare fuori dal campo: la tastiera resta.
            child: TextFieldTapRegion(
              child: Tooltip(
                message: _qui?.uri?.toString() ?? '',
                child: Bottone('Apri', key: const ValueKey('apri collegamento'), tipo: TipoBottone.tenue, alto: false, icona: Icons.open_in_new_rounded, onPressed: _apri),
              ),
            ),
          ),
        );
      },
      // Solo col campo acceso: senza cursore non c'è niente da aprire.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (acceso) {
          _acceso = acceso;
          _guarda();
        },
        child: KeyedSubtree(key: _campo, child: widget.child),
      ),
    ),
  );
}
