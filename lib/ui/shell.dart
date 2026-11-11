import 'dart:async';

import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/proposte_colore.dart';
import 'cartelle.dart';
import 'common.dart';
import 'azioni_pagina.dart';
import 'da_sistemare.dart';
import 'dock.dart';
import 'molecole/colonna_poteri.dart';
import 'filtri_trascrivi.dart';
import 'molecole/intestazione.dart';
import 'molecole/riga_in_attesa.dart';
import 'onboarding.dart';
import 'pensieri.dart';
import 'settings.dart';
import 'theme.dart';
import 'transcri.dart';
import 'trascrivi.dart';
import 'trascrizione_aperta.dart';

/// L'app: in cima il nome del potere in cui sei e le impostazioni, in mezzo la sua pagina,
/// in fondo il Dock. Transcri ha la sua casa nel Dock, uguale in ogni potere.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.onReplayIntro, this.atterra = false});

  final VoidCallback onReplayIntro;

  /// Si entra dalla prova dell'introduzione: Transcri torna nel nido col suo atterraggio (il sobbalzo e la luce).
  final bool atterra;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  Power power = Power.trascrivi;

  /// In Pensieri: 0 Note, 1 Argomenti.
  int thoughts = 0;

  /// Le Note senza la pagina Argomenti (7 nov: «nelle Note solo le note»): torna solo dalle prove.
  void _argomentiCambiati() => setState(() {
    if (!Core.mostraArgomenti.value) thoughts = 0;
  });

  /// In Trascrivi: 0 le trascrizioni, 1 le cartelle.
  int trascrizioni = 0;
  bool pillOn = false;
  bool hasKey = true;

  /// Dati finti accesi: lo dice sempre, in alto.
  bool sandbox = false;
  DateTime? limitedUntil;
  int waiting = 0;

  /// «Riprova» sta trascrivendo le registrazioni in attesa.
  bool riprovando = false;

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
    Core.mostraArgomenti.addListener(_argomentiCambiati);
    _load();
    if (widget.atterra) WidgetsBinding.instance.addPostFrameCallback((_) => _nest.currentState?.atterra());
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Core.removeListener(_load);
    Core.live.removeListener(_liveChanged);
    Core.mostraArgomenti.removeListener(_argomentiCambiati);
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
  });

  /// Si sta scegliendo (in qualunque pagina): il Dock si fa da parte.
  ValueNotifier<bool> get _scegliendo => Scelta.attiva;

  /// «Seleziona» nel ⋮: comincia a scegliere nella pagina in cui sei (null dove non si sceglie: Argomenti).
  VoidCallback? get _seleziona => switch (power) {
    Power.trascrivi => trascrizioni == 0 || !CartellePage.mostra.value ? () => TrascriviPage.scegliendo.value = true : null,
    Power.pensieri => null,
  };

  /// «Riprova»: trascrive quello che è rimasto indietro.
  Future<void> _riprova() async {
    if (riprovando) return;
    setState(() => riprovando = true);
    await Core.flushWaiting();
    if (!mounted) return;
    setState(() => riprovando = false);
    Core.refresh();
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

  /// La zona sotto il titolo: le registrazioni in attesa e (10 nov), in Trascrivi, le proposte di colore, in una riga
  /// sola; ognuna apre la pagina «Da sistemare» sulla sua parte; scorrendo, accanto al titolo nella pillola, i loro
  /// segni corti. Niente da dire: null.
  (Widget?, Widget?) _sottoTitolo(bool listaTrascrizioni) {
    final voci = TrascriviPage.tutte.value;
    final proposte = listaTrascrizioni ? ProposteColore.con(voci) : const <(PropostaColore, Entry)>[];
    if (waiting == 0 && proposte.isEmpty) return (null, null);
    void apri(DaSistemare parte) => apriDaSistemare(context, parte: parte, onRiprova: _riprova, voci: listaTrascrizioni ? voci : const [], onApri: openEntry);
    return (
      RigaInAttesa(quante: waiting, proposte: proposte.length, riprovando: riprovando, onRiprova: _riprova, onApri: apri),
      InAttesaCorto(quante: waiting, proposte: proposte.length, onApri: apri),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = Dock.height + MediaQuery.paddingOf(context).bottom;
    // Le cartelle (6 nov, giro 7) si vedono solo dalle prove: i colori come filtri ne fanno le veci.
    final cartelle = power == Power.trascrivi && trascrizioni == 1 && CartellePage.mostra.value;
    final listaTrascrizioni = power == Power.trascrivi && !cartelle;
    final page = switch (power) {
      Power.trascrivi =>
        cartelle
            ? CartellePage(key: const ValueKey('cartelle'), bottom: bottom)
            : TrascriviPage(key: const ValueKey(Power.trascrivi), bottom: bottom),
      Power.pensieri =>
        thoughts == 0 || !Core.mostraArgomenti.value
            ? PensieriPage(key: const ValueKey('note'), bottom: bottom)
            : ArgomentiPage(key: const ValueKey('argomenti'), bottom: bottom),
    };
    // Cambiando potere o pagina la nuova sale appena mentre compare, la vecchia sfuma.
    final pagina = AnimatedSwitcher(
      duration: Durata.normale,
      switchInCurve: Curva.standard,
      switchOutCurve: Curva.uscita,
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: w),
      ),
      child: page,
    );
    return Paper(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              // In cima la barra, che scorrendo diventa due pillole sopra la pagina (come il Dock in fondo).
              // In Trascrivi, sotto il titolo, i filtri della lista (si ridisegna solo l'intestazione: la pagina è la stessa).
              child: ListenableBuilder(
                // Anche le proposte di colore, sotto il titolo con le registrazioni in attesa.
                listenable: Listenable.merge([FiltriTrascrivi.cambia, ProposteColore.tutte, TrascriviPage.tutte]),
                builder: (context, _) {
                  final sottoTitolo = _sottoTitolo(listaTrascrizioni);
                  return Intestazione(
                    titolo: cartelle ? 'Cartelle' : power.label,
                    pagina: page.key,
                    segno: sandbox ? const ChipStato('Dati finti', tipo: TipoChip.azione) : null,
                    sotto: sottoTitolo.$1,
                    accanto: sottoTitolo.$2,
                    // La lente e il ⋮ (sua scelta, 6 nov): «Seleziona» dove si può scegliere, e le impostazioni.
                    // In Trascrivi, prima, il tasto «Filtri» (solo se c'è qualcosa da filtrare).
                    azioni: [
                      if (listaTrascrizioni) ?FiltriTrascrivi.tasto(),
                      ...azioniPagina(context, onSeleziona: _seleziona, onImpostazioni: _openSettings),
                    ],
                    filtri: listaTrascrizioni ? FiltriTrascrivi.accesi() : null,
                    child: pagina,
                  );
                },
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
                child: ListenableBuilder(
                  // Solo quando comincia o smette di ascoltare, o di scegliere: il volume non ridisegna tutto il Dock.
                  listenable: Listenable.merge([_heard, _scegliendo]),
                  builder: (context, _) => Dock(
                    power: power,
                    // Mentre si sceglie, al posto del Dock c'è la barra delle scelte.
                    nascosto: _scegliendo.value,
                    onTocco: () => setState(() => colonna = !colonna),
                    onProssimo: _prossimo,
                    onTira: (t) => setState(() => tira = t),
                    action: _action(_heard.value),
                    pages: switch (power) {
                      // Una pagina sola: la pillola delle pagine non c'è.
                      Power.pensieri => [(Icons.notes_rounded, 'Note'), if (Core.mostraArgomenti.value) (Icons.bubble_chart_rounded, 'Argomenti')],
                      Power.trascrivi => CartellePage.mostra.value ? const [(Icons.subject_rounded, 'Trascrizioni'), (Icons.folder_rounded, 'Cartelle')] : const [],
                    },
                    page: power == Power.pensieri ? thoughts : trascrizioni,
                    onPage: (i) => setState(() => power == Power.pensieri ? thoughts = i : trascrizioni = i),
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
              // La colonna spunta dal medaglione, come un fumetto dal suo tasto.
              child: AnimatedSwitcher(
                duration: Durata.normale,
                transitionBuilder: (w, a) => Spunta(animazione: a, da: Alignment.bottomLeft, child: w),
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
