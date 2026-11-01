import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'dock.dart';
import 'onboarding.dart';
import 'pensieri.dart';
import 'settings.dart';
import 'status.dart';
import 'theme.dart';
import 'transcri.dart';
import 'trascrivi.dart';

/// L'app: in cima il nome del potere in cui sei e le impostazioni, in mezzo la sua pagina,
/// in fondo il Dock. Transcri ha la sua casa nel Dock, uguale in ogni potere.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.onReplayIntro});

  final VoidCallback onReplayIntro;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  Power power = Power.trascrivi;

  /// In Pensieri: 0 Note, 1 Argomenti.
  int thoughts = 0;
  bool pillOn = false;
  bool hasKey = true;

  /// Dati finti accesi: lo dice sempre, in alto.
  bool sandbox = false;
  DateTime? limitedUntil;
  int waiting = 0;

  /// La colonna dei poteri è aperta.
  bool switching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Core.addListener(_load);
    Core.live.addListener(_liveChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Core.removeListener(_load);
    Core.live.removeListener(_liveChanged);
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
    final w = await Core.waiting();
    if (!mounted || n != _loads) return;
    setState(() {
      waiting = w.length;
      pillOn = s.pillOn;
      sandbox = s.sandbox;
      _liveChanged();
      hasKey = s.hasKey;
      transcriColors = [s.accentA, s.accentB];
      transcriRed = s.stateRed;
      transcriGreen = s.stateGreen;
      if (s.accentMain != Tokens.blue) Tokens.useAccent(s.accentMain, s.accentSecond);
      limitedUntil = s.limited == null ? null : s.resetAt;
    });
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (result == 'intro') widget.onReplayIntro();
    Core.refresh();
  }

  /// Senza chiave Transcri non può trascrivere: lo dice, e la chiave si mette da qui.
  Future<void> _needKey() async {
    final add = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prima, una chiave Groq', style: display(context, size: 22)),
            const SizedBox(height: 8),
            Text(
              'Transcri trascrive con Groq. La chiave è gratis e si prende in due minuti.',
              style: Theme.of(sheet).textTheme.bodyMedium?.copyWith(color: context.tk.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Prendi la chiave')),
          ],
        ),
      ),
    );
    if (add != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => KeyPage(onSaved: () => Navigator.of(ctx).pop(), onClose: () => Navigator.of(ctx).pop()),
      ),
    );
    Core.refresh();
  }

  final _nest = GlobalKey<TranscriNestState>();

  /// Transcri sta ascoltando dal Dock.
  final _heard = ValueNotifier<bool>(false);

  void _liveChanged() => _heard.value = Core.live.value.listening && Core.live.value.appendTo == null && !pillOn;

  /// L'azione accanto a Transcri: mentre ascolta è il tasto per fermarlo; altrimenti dipende dal potere.
  (IconData, String, VoidCallback)? _action(bool heard) {
    if (heard) return (Icons.stop_rounded, 'Ferma e trascrivi', Core.stopListening);
    return switch (power) {
      Power.pensieri => (Icons.edit_rounded, 'Scrivi', () => openNote(context)),
      Power.trascrivi => pillOn ? null : (Icons.mic_rounded, 'Detta qui', () => _nest.currentState?.listen()),
    };
  }

  void _go(Power p) => setState(() {
    power = p;
    switching = false;
  });

  @override
  Widget build(BuildContext context) {
    final bottom = Dock.height + MediaQuery.paddingOf(context).bottom;
    final status = Status(limitedUntil: limitedUntil, waiting: waiting, hasKey: hasKey);
    final page = switch (power) {
      Power.trascrivi => TrascriviPage(key: const ValueKey(Power.trascrivi), bottom: bottom),
      Power.pensieri =>
        thoughts == 0
            ? PensieriPage(key: const ValueKey('note'), bottom: bottom)
            : ArgomentiPage(key: const ValueKey('argomenti'), bottom: bottom),
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
                        if (sandbox)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Tokens.blue.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                            child: Text('Dati finti', style: TextStyle(color: Tokens.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        // Se qualcosa non va o aspetta, lo dice qui, accanto alle impostazioni.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: status.any
                              ? Padding(
                                  key: ValueKey(status.short),
                                  padding: const EdgeInsets.only(right: 4),
                                  child: StatusChip(status: status, onTap: () => showStatus(context)),
                                )
                              : const SizedBox.shrink(),
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
                child: ValueListenableBuilder<bool>(
                  // Solo quando comincia o smette di ascoltare: il volume non ridisegna tutto il Dock.
                  valueListenable: _heard,
                  builder: (context, heard, _) => Dock(
                    power: power,
                    onSwitch: () => setState(() => switching = !switching),
                    onStep: (by) => _go(power.step(by)),
                    action: _action(heard),
                    pages: power == Power.pensieri
                        ? const [(Icons.notes_rounded, 'Note'), (Icons.bubble_chart_rounded, 'Argomenti')]
                        : const [],
                    page: thoughts,
                    onPage: (i) => setState(() => thoughts = i),
                    nest: TranscriNest(
                      key: _nest,
                      on: pillOn,
                      limitedUntil: limitedUntil,
                      onChanged: Core.refresh,
                      onNeedKey: hasKey ? null : _needKey,
                      onAsleep: () => showStatus(context),
                    ),
                  ),
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
