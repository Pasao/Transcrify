import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'dock.dart';
import 'pensieri.dart';
import 'settings.dart';
import 'theme.dart';
import 'transcri.dart';
import 'trascrivi.dart';

/// L'app: in cima il nome del potere in cui sei e le impostazioni, in mezzo la sua pagina,
/// in fondo il Dock. Transcri ha la sua casa nel Dock, uguale in ogni potere.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.onKeyRemoved, required this.onReplayIntro});

  final VoidCallback onKeyRemoved;
  final VoidCallback onReplayIntro;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  Power power = Power.trascrivi;
  bool pillOn = false;
  DateTime? limitedUntil;

  /// La colonna dei poteri è aperta.
  bool switching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Core.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Core.removeListener(_load);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Il nativo dimentica il nido quando l'app va in pausa: al ritorno va detto di nuovo.
      Core.forgetNest();
      Core.refresh();
    }
  }

  /// Le letture si possono accavallare: vale solo l'ultima, così una vecchia non fa scattare il nido indietro.
  int _loads = 0;

  Future<void> _load() async {
    final n = ++_loads;
    final s = await Core.state();
    if (!mounted || n != _loads) return;
    setState(() {
      pillOn = s.pillOn;
      transcriColors = [s.accentA, s.accentB];
      if (s.accentMain != Tokens.blue) Tokens.useAccent(s.accentMain, s.accentSecond);
      limitedUntil = s.limited == null ? null : s.resetAt;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (result == 'removed') widget.onKeyRemoved();
    if (result == 'intro') widget.onReplayIntro();
    Core.refresh();
  }

  void _go(Power p) => setState(() {
    power = p;
    switching = false;
  });

  @override
  Widget build(BuildContext context) {
    final bottom = Dock.height + MediaQuery.paddingOf(context).bottom;
    final page = switch (power) {
      Power.trascrivi => TrascriviPage(key: const ValueKey(Power.trascrivi), bottom: bottom),
      Power.pensieri => PensieriPage(key: const ValueKey(Power.pensieri), bottom: bottom),
    };
    return Paper(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                            child: Text(power.label, key: ValueKey(power), style: display(context, size: 26)),
                          ),
                        ),
                        IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings_rounded), tooltip: 'Impostazioni'),
                      ],
                    ),
                  ),
                  Expanded(
                    // Cambiando potere la pagina sfuma nell'altra, senza scorrere di lato.
                    child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: page),
                  ),
                ],
              ),
            ),
            // La colonna aperta: un velo leggero sopra la pagina, toccandolo si richiude.
            if (switching)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => switching = false),
                  child: const ColoredBox(color: Color(0x1F000000)),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Dock(
                  power: power,
                  onSwitch: () => setState(() => switching = !switching),
                  onStep: (by) => _go(power.step(by)),
                  onWrite: power == Power.pensieri ? () => openNote(context) : null,
                  nest: TranscriNest(on: pillOn, limitedUntil: limitedUntil, onChanged: Core.refresh),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: bottom + 10,
              child: IgnorePointer(
                ignoring: !switching,
                child: AnimatedSlide(
                  offset: switching ? Offset.zero : const Offset(0, 0.15),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: switching ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: PowerColumn(current: power, onPick: _go),
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
