import 'package:flutter/material.dart';

import '../core/native.dart';
import 'onboarding.dart';
import 'prova_transcri.dart';
import 'theme.dart';

/// Cosa serve sapere all'avvio: se c'è la chiave e se l'introduzione si è già vista.
typedef StatoAvvio = ({bool hasKey, bool introSeen});

/// Primo avvio: cos'è, poi la chiave, poi la prova di Transcri (7 nov), poi l'app. Ogni pagina si salta con «Salta»
/// in basso a sinistra: la chiave si mette quando serve (Transcri la chiede). I permessi li chiede chi li usa.
/// Indietro (freccia o gesto) torna sempre alla pagina prima; dalla prima non si torna da nessuna parte.
/// Se il nativo non risponde, non resta mai sul bianco: si parte dall'introduzione.
/// - [casa]: l'app vera ([atterra]: si arriva dalla prova riuscita, Transcri torna nel nido; [rivedi]: rivedere
///   l'introduzione dalle impostazioni).
class Avvio extends StatefulWidget {
  const Avvio({super.key, required this.casa, this.leggi = _leggiDalNativo, this.segnaVista = Core.setIntroSeen});

  final Widget Function(bool atterra, VoidCallback rivedi) casa;

  /// Come si legge lo stato (nelle prove: finto).
  final Future<StatoAvvio> Function() leggi;

  /// Come si segna l'introduzione vista.
  final Future<void> Function() segnaVista;

  static Future<StatoAvvio> _leggiDalNativo() async {
    final s = await Core.state();
    return (hasKey: s.hasKey, introSeen: s.introSeen);
  }

  @override
  State<Avvio> createState() => _AvvioState();
}

enum _Fase { carica, intro, chiave, prova, casa }

class _AvvioState extends State<Avvio> {
  _Fase passo = _Fase.carica;

  /// C'è la chiave Groq (per la prova).
  bool hasKey = false;

  /// Si entra dalla prova riuscita: Transcri torna nel nido.
  bool atterra = false;

  @override
  void initState() {
    super.initState();
    // Accendere o spegnere la prova «utente nuovo» fa ripartire l'app dall'inizio.
    Core.preview.addListener(_inizia);
    _inizia();
  }

  @override
  void dispose() {
    Core.preview.removeListener(_inizia);
    super.dispose();
  }

  /// Lo stato, o (se il nativo non risponde) quello di un primo avvio.
  Future<StatoAvvio> _stato() async {
    try {
      return await widget.leggi();
    } catch (_) {
      return (hasKey: false, introSeen: false);
    }
  }

  /// L'introduzione si vede la prima volta; dopo, solo se la chiedi dalle impostazioni.
  Future<void> _inizia() async {
    final s = await _stato();
    if (!mounted) return;
    setState(() => passo = s.hasKey || s.introSeen ? _Fase.casa : _Fase.intro);
  }

  /// Dalla chiave (messa o saltata) alla prova.
  Future<void> _prova() async {
    final s = await _stato();
    if (!mounted) return;
    setState(() {
      hasKey = s.hasKey;
      passo = _Fase.prova;
    });
  }

  Future<void> _casa([bool provata = false]) async {
    try {
      await widget.segnaVista();
    } catch (_) {
      // Non segnata: la prossima volta si rivede, ma adesso si entra.
    }
    if (!mounted) return;
    setState(() {
      atterra = provata;
      passo = _Fase.casa;
    });
  }

  void _vai(_Fase p) => setState(() => passo = p);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Durata.normale,
      child: switch (passo) {
        _Fase.carica => const Paper(key: ValueKey(0), child: Scaffold()),
        _Fase.intro => IntroPage(key: const ValueKey(1), onNext: () => _vai(_Fase.chiave), onClose: _casa),
        _Fase.chiave => KeyPage(key: const ValueKey(2), onSaved: _prova, onClose: _prova, onBack: () => _vai(_Fase.intro)),
        _Fase.prova => ProvaTranscri(key: const ValueKey(4), haChiave: hasKey, onFine: _casa, onIndietro: () => _vai(_Fase.chiave)),
        _Fase.casa => KeyedSubtree(key: const ValueKey(3), child: widget.casa(atterra, () => _vai(_Fase.intro))),
      },
    );
  }
}
