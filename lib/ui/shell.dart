import 'dart:async';

import 'package:flutter/material.dart';

import '../core/native.dart';
import 'dock.dart';
import 'molecole/colonna_poteri.dart';
import 'molecole/foglio_in_attesa.dart';
import 'molecole/intestazione.dart';
import 'molecole/riga_in_attesa.dart';
import 'onboarding.dart';
import 'pensieri.dart';
import 'settings.dart';
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

  /// «Riprova» sta trascrivendo le registrazioni in attesa.
  bool riprovando = false;

  /// La pagina è scorsa: il titolo si rimpicciolisce.
  bool ridotta = false;

  /// La colonna dei poteri è aperta (un tocco sul medaglione).
  bool colonna = false;

  /// Quanto stai tirando su il medaglione (0 → 1 = abbastanza per cambiare): sopra compare il nome di chi arriva.
  double tira = 0;

  /// Il nome del potere appena cambiato, per un attimo.
  bool nomeVisibile = false;
  Timer? _nome;

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
    _nome?.cancel();
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
      Colori.usa(s.tokenChiaro, s.tokenScuro);
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
              style: Theme.of(sheet).textTheme.bodyMedium?.copyWith(color: context.col.testoSecondario),
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
    colonna = false;
    ridotta = false;
  });

  /// «Riprova»: trascrive quello che è rimasto indietro.
  Future<void> _riprova() async {
    if (riprovando) return;
    setState(() => riprovando = true);
    await Core.flushWaiting();
    if (!mounted) return;
    setState(() => riprovando = false);
    Core.refresh();
  }

  /// Il titolo si riduce quando la pagina scorre in verticale (le liste di lato non contano).
  bool _scorre(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final r = n.metrics.pixels > Spazio.s6;
      if (r != ridotta) setState(() => ridotta = r);
    }
    return false;
  }

  /// Tirato su abbastanza: il prossimo potere, e il suo nome resta un attimo.
  void _prossimo() {
    _go(power.step(1));
    setState(() => nomeVisibile = true);
    _nome?.cancel();
    _nome = Timer(Durata.etichetta, () {
      if (mounted) setState(() => nomeVisibile = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = Dock.height + MediaQuery.paddingOf(context).bottom;
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
                  Intestazione(
                    titolo: power.label,
                    ridotta: ridotta,
                    sotto: waiting > 0
                        ? RigaInAttesa(quante: waiting, riprovando: riprovando, onRiprova: _riprova, onApri: () => apriInAttesa(context, onRiprova: _riprova))
                        : null,
                    accanto: waiting > 0 ? InAttesaCorto(quante: waiting) : null,
                    azioni: [
                      if (sandbox) const Padding(padding: EdgeInsets.only(right: Spazio.s1), child: ChipStato('Dati finti', tipo: TipoChip.azione)),
                      IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings_rounded), tooltip: 'Impostazioni'),
                    ],
                  ),
                  Expanded(
                    // Cambiando potere la pagina sfuma nell'altra, senza scorrere di lato.
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _scorre,
                      child: AnimatedSwitcher(duration: Durata.normale, child: page),
                    ),
                  ),
                ],
              ),
            ),
            // La colonna aperta: un velo leggero sopra la pagina, toccandolo si richiude.
            if (colonna)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => colonna = false),
                  child: ColoredBox(color: context.col.floater.withValues(alpha: 0.12)),
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
                    onTocco: () => setState(() => colonna = !colonna),
                    onProssimo: _prossimo,
                    onTira: (t) => setState(() => tira = t),
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
                      // Transcri dorme (minuti finiti): l'Utilizzo dice quando tornano.
                      onAsleep: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsagePage())),
                    ),
                  ),
                ),
              ),
            ),
            // Sopra il medaglione: la colonna (tocco), o il nome di chi arriva mentre lo tiri su e
            // di quello appena arrivato.
            Positioned(
              left: Spazio.s3,
              bottom: MediaQuery.paddingOf(context).bottom + Spazio.s3 + Misura.isola + Spazio.s2,
              child: AnimatedSwitcher(
                duration: Durata.veloce,
                child: colonna
                    ? ColonnaPoteri(attuale: power, onScegli: _go)
                    : tira > 0 || nomeVisibile
                        ? IgnorePointer(
                            child: Opacity(
                              opacity: nomeVisibile ? 1 : tira.clamp(0, 1).toDouble(),
                              child: EtichettaSospesa((nomeVisibile ? power : power.step(1)).label, key: ValueKey(nomeVisibile ? power : power.step(1))),
                            ),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
