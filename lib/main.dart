import 'package:flutter/material.dart';

import 'core/native.dart';
import 'ui/shell.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prima di disegnare: i colori del telefono, così l'app non parte blu per poi cambiare.
  try {
    final s = await Core.state();
    Colori.usa(s.tokenChiaro, s.tokenScuro);
  } catch (_) {}
  runApp(const TranscrifyApp());
}

class TranscrifyApp extends StatelessWidget {
  const TranscrifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Un colore solo per tutto: se cambia (nuovo sfondo), si ridisegna l'app intera.
    return ValueListenableBuilder<int>(
        valueListenable: Colori.versione,
        builder: (context, _, _) => MaterialApp(
          title: 'Transcrify',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const _Root(),
        ),
    );
  }
}

enum _Step { loading, intro, key, home }

/// Primo avvio: cos'è, poi la chiave, poi l'app. Ognuna delle due pagine si può saltare con la X:
/// la chiave si mette quando serve (Transcri la chiede). I permessi li chiede la pillola quando serve.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  _Step step = _Step.loading;

  @override
  void initState() {
    super.initState();
    // Accendere o spegnere la prova «utente nuovo» fa ripartire l'app dall'inizio.
    Core.preview.addListener(_start);
    _start();
  }

  @override
  void dispose() {
    Core.preview.removeListener(_start);
    super.dispose();
  }

  /// L'introduzione si vede la prima volta; dopo, solo se la chiedi dalle impostazioni.
  Future<void> _start() async {
    final s = await Core.state();
    if (!mounted) return;
    setState(() => step = s.hasKey || s.introSeen ? _Step.home : _Step.intro);
  }

  Future<void> _home() async {
    await Core.setIntroSeen();
    if (mounted) setState(() => step = _Step.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Durata.normale,
      child: switch (step) {
        _Step.loading => const Paper(key: ValueKey(0), child: Scaffold()),
        _Step.intro => IntroPage(key: const ValueKey(1), onNext: () => setState(() => step = _Step.key), onClose: _home),
        _Step.key => KeyPage(key: const ValueKey(2), onSaved: _home, onClose: _home, onBack: () => setState(() => step = _Step.intro)),
        _Step.home => Shell(key: const ValueKey(3), onReplayIntro: () => setState(() => step = _Step.intro)),
      },
    );
  }
}
