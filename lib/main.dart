import 'package:flutter/material.dart';

import 'core/native.dart';
import 'ui/home.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

void main() => runApp(const TranscrifyApp());

class TranscrifyApp extends StatelessWidget {
  const TranscrifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transcrify',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const _Root(),
    );
  }
}

enum _Step { loading, intro, key, home }

/// Primo avvio: cos'è, poi la chiave, poi l'app. I permessi li chiede la pillola quando serve.
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
    _decide();
  }

  Future<void> _decide() async {
    final s = await Core.state();
    if (!mounted) return;
    setState(() => step = s.hasKey ? _Step.home : _Step.intro);
  }

  /// Se la chiave c'è già (introduzione rivista): la pagina della chiave offre di tenerla.
  bool hasKey = false;

  /// Dopo l'introduzione si passa sempre dalla chiave: così "Come funziona" mostra tutto il percorso.
  Future<void> _afterIntro() async {
    final s = await Core.state();
    if (mounted) {
      setState(() {
        hasKey = s.hasKey;
        step = _Step.key;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (step) {
        _Step.loading => const Scaffold(key: ValueKey(0)),
        _Step.intro => IntroPage(key: const ValueKey(1), onNext: _afterIntro),
        _Step.key => KeyPage(
            key: const ValueKey(2),
            onSaved: _decide,
            onBack: () => setState(() => step = _Step.intro),
            onKeep: hasKey ? () => setState(() => step = _Step.home) : null,
          ),
        _Step.home => HomePage(
            key: const ValueKey(3),
            onKeyRemoved: _decide,
            onReplayIntro: () => setState(() => step = _Step.intro),
          ),
      },
    );
  }
}
