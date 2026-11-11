import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
import 'molecole/fumetto.dart';
import 'molecole/piede_intro.dart';
import 'molecole/scheda_trascrizione.dart';
import 'molecole/volo_prima.dart';
import 'molecole/voce_in_barra.dart';
import 'theme.dart';
import 'transcri.dart';

/// L'ultima pagina dell'introduzione (7 nov, sua idea): prima di entrare, provi Transcri davvero. Detta dentro
/// l'app come dal nido (niente permesso di stare sopra le altre app): tocchi «Prova» e parli; dopo un secondo
/// (10 nov, sua idea) Transcri va di lato, sul bordo come la pillola, e un fumetto lo indica: «Io sto qui…». Lo
/// tieni premuto (o tocchi «Stop») e la trascrizione si fa come sempre (negli appunti e nella lista). Pronta, al
/// centro c'è la scheda «Ecco la tua prima trascrizione»; con «Entra» la scheda vola al suo posto nella lista
/// ([VoloPrima]) e Transcri torna nel suo nido ([Shell.atterra]).
/// 10 nov, ultimo giro: si parte anche toccando lui; l'anello della voce è più largo e staccato dal corpo; di lato
/// diventa la pillola del bordo ([PillolaBordo]); il titolo «Ecco la tua prima trascrizione» sta sopra la scheda, che
/// è quella vera della lista ([SchedaTrascrizione]); con «Entra» la pillola se ne va e la scheda vola.
/// 10 nov, giro finale (suo: «la pillola vera, non una finta ferma lì»): con il permesso di stare sopra le altre app
/// parte la pillola vera, già in ascolto, dal posto di Transcri: la trascini, la tieni premuta per spegnerla, la tocchi
/// per il Floater, o tocchi «Stop» qui. Senza il permesso lo chiede ([chiediSopraLeApp]); con «Non ora» ascolta qui
/// come prima, con la pillola del bordo disegnata.
/// 11 nov (suo, quarto giro): la pillola vera sta sul bordo destro, in alto ma non in cima ([_Palco.alto]); sotto di lei
/// il fumetto, poi la frase da leggere. Le fasi le fa avanzare lui («Avanti» nel fumetto, o toccandolo), mai un tempo:
/// «Sono qui. Leggi la frase qui sotto.», poi «Fatto? Ora tienimi premuto per fermarmi…»; fermata «Ricevuto:
/// trascrivo…», poi la prima trascrizione. Tenerla premuta la ferma in qualsiasi momento (lo dice il fumetto).
/// Chi non vuole provare ha «Salta». Senza chiave, senza microfono o se Groq non risponde lo dice in una riga,
/// e si può saltare lo stesso.
class ProvaTranscri extends StatefulWidget {
  const ProvaTranscri({super.key, required this.haChiave, required this.onFine, required this.onIndietro});

  /// C'è la chiave Groq: senza, non si può trascrivere.
  final bool haChiave;

  /// Si entra nell'app: [provata] se la prima trascrizione è appena arrivata.
  final ValueChanged<bool> onFine;

  /// Torna alla chiave (freccia, gesto indietro, «Metti la chiave»).
  final VoidCallback onIndietro;

  @override
  State<ProvaTranscri> createState() => _ProvaTranscriState();
}

class _ProvaTranscriState extends State<ProvaTranscri> {
  /// La fase della prova mentre ascolta: 0 «leggi la frase», 1 «ora fermami». La fa avanzare lui.
  int _fase = 0;

  /// Il palco: la pillola vera va sul bordo destro alla sua altezza ([_Palco.alto]).
  final _palco = GlobalKey();

  /// La frase da leggere nella prova: otto secondi circa, detta con calma.
  static const frase = 'Ciao Transcrify, questa è la mia prima nota: domani devo chiamare Marta e comprare il pane.';

  /// Hai toccato «Stop»: da qui si aspetta la trascrizione.
  bool _mandata = false;

  /// Cosa non è andato, in una riga.
  String? _problema;

  /// Transcri sta di lato, sul bordo: un secondo dopo che ha cominciato ad ascoltare ([Durata.provaDiLato]).
  bool _diLato = false;
  Timer? _vaDiLato;

  /// La prima trascrizione, quando è pronta: la sua scheda al centro.
  Entry? _prima;
  final _scheda = GlobalKey();

  /// Hai toccato «Entra»: la pillola se ne va, vola solo la scheda.
  bool _entrato = false;

  /// La pillola vera è fuori, sul bordo dello schermo: qui Transcri non si disegna.
  bool _fuori = false;

  /// Ha cominciato ad ascoltare: se poi si ferma dalla pillola (tenuta premuta, «Stop» nel Floater) vale come «Stop».
  bool _ascoltato = false;

  /// Transcri al centro: da lì parte la pillola vera.
  final _transcri = GlobalKey();

  @override
  void initState() {
    super.initState();
    Core.ascoltaNativo();
    Core.live.addListener(_cambia);
  }

  @override
  void dispose() {
    _vaDiLato?.cancel();
    Core.live.removeListener(_cambia);
    _vista.dispose();
    // Uscita da un'altra strada (la pagina se ne va da sola): la pillola guidata non resta fuori.
    if (_fuori) Core.stopPill().catchError((_) {});
    super.dispose();
  }

  /// Lo stato che la pagina mostra: cambia solo con fase, secondi, pausa ed errore, non col volume della voce, che
  /// arriva a ogni fotogramma (11 nov, suo: «l'onda va a scatti»). L'onda e l'anello lo leggono da soli.
  late final _vista = ValueNotifier<Live>(Core.live.value);

  void _cambia() {
    final live = Core.live.value;
    if (!mounted) return;
    final v = _vista.value;
    if (v.phase != live.phase || v.seconds != live.seconds || v.paused != live.paused || v.error != live.error) _vista.value = live;
    if (live.listening) _ascoltato = true;
    // Fermato dalla pillola vera (tenuta premuta, o «Stop» nel Floater): come «Stop» qui.
    if (_ascoltato && live.phase == 'PROCESSING') {
      _ascoltato = false;
      _mandata = true;
    }
    // Ascolta: tra un secondo va di lato (la pillola disegnata; quella vera è già sul bordo). Smette prima: resta dov'è.
    if (live.listening && !_fuori) {
      _vaDiLato ??= Timer(Durata.provaDiLato, () {
        if (mounted) setState(() => _diLato = true);
      });
    } else {
      _vaDiLato?.cancel();
      _vaDiLato = null;
    }
    // Un errore si dice sempre (anche se il microfono non parte); la fine solo dopo «Stop».
    final problema = switch (live.phase) {
      'ERROR' || 'LIMITED' => live.error ?? 'Groq non ha risposto. Riprova, o salta: potrai provare dall\'app.',
      'IDLE' when _mandata => 'Non ho sentito niente. Riprova, un po\' più vicino.',
      _ => null,
    };
    if (live.phase == 'SUCCESS' && _mandata) {
      _mandata = false;
      _mostraPrima();
    } else if (problema != null) {
      setState(() {
        _mandata = false;
        _problema = problema;
        _diLato = false;
      });
    }
  }

  /// La trascrizione è pronta: al centro la sua scheda, Transcri resta di lato. Se non si legge, si entra e basta.
  Future<void> _mostraPrima() async {
    Entry? prima;
    try {
      final voci = await Core.history();
      prima = voci.isEmpty ? null : voci.reduce((a, b) => b.at.isAfter(a.at) ? b : a);
    } catch (_) {
      // Senza la lista si entra lo stesso: la trascrizione è già lì.
    }
    if (!mounted) return;
    if (prima == null || prima.text.trim().isEmpty) return widget.onFine(true);
    HapticFeedback.mediumImpact();
    setState(() {
      _prima = prima;
      _diLato = true;
    });
  }

  /// La scheda della prima trascrizione: quella della lista, come la vedrai lì (e la copia che vola).
  /// Nella prova non si butta e non si cambia (11 nov, suo): solo «Entra», anche toccandola.
  Widget _schedaDi(Entry e, {Key? key}) => SchedaTrascrizione(key: key, entry: e, onOpen: _entra);

  /// «Entra»: la scheda vola al suo posto nella lista, e si entra.
  void _entra() {
    final scheda = _scheda.currentContext, prima = _prima;
    setState(() => _entrato = true);
    _ritira();
    if (scheda != null && prima != null) VoloPrima.parti(context, da: dovSta(scheda), copia: _schedaDi(prima));
    widget.onFine(true);
  }

  /// L'azione in basso a destra, per quello che sta succedendo.
  (String, VoidCallback?) _principale(Live live) {
    if (!widget.haChiave) return ('Metti la chiave', widget.onIndietro);
    if (_prima != null) return ('Entra', _entra);
    if (_mandata || live.phase == 'PROCESSING') return ('Trascrivo…', null);
    if (live.listening) return ('Stop', _stop);
    return (_problema == null ? 'Prova' : 'Riprova', _chiede ? null : _prova);
  }

  /// Il microfono si sta chiedendo: «Prova» resta spento, un secondo tocco non apre un'altra richiesta.
  bool _chiede = false;

  Future<void> _prova() async {
    setState(() {
      _problema = null;
      _chiede = true;
      _fase = 0;
    });
    var pronto = false;
    try {
      pronto = await microfonoPronto();
      if (pronto) await _parti();
    } catch (_) {
      if (mounted) setState(() => _problema = 'Transcri non è partito. Riprova, o salta: potrai provare dall’app.');
    }
    if (!mounted) return;
    setState(() {
      _chiede = false;
      if (!pronto) _problema ??= 'Senza microfono Transcri non ti sente. Puoi permetterlo più tardi.';
    });
  }

  /// Comincia ad ascoltare: con la pillola vera, se può stare sopra le altre app; se no lo chiede, e con «Non ora»
  /// ascolta qui nella pagina. Aperta la schermata del permesso, si aspetta che torni e tocchi di nuovo «Prova».
  Future<void> _parti() async {
    // Se il nativo non sa rispondere, si ascolta qui.
    final sopra = await Core.canDrawOverlays().catchError((_) => false);
    if (!sopra) {
      if (!mounted) return;
      if (await chiediSopraLeApp(context)) {
        if (mounted) setState(() => _problema = 'Accendi «Mostra sopra altre app», torna qui e tocca Prova.');
        return;
      }
    }
    HapticFeedback.heavyImpact();
    final casa = _transcri.currentContext, palco = _palco.currentContext;
    if (sopra && casa != null && casa.mounted && palco != null && palco.mounted) {
      final (centro, rettangolo) = inPixel(casa);
      final (_, p) = inPixel(palco);
      final alto = p[1] + (p[3] - p[1]) * _Palco.alto;
      final schermo = MediaQuery.sizeOf(palco).height * MediaQuery.devicePixelRatioOf(palco);
      // Guidata (11 nov): ferma sul bordo destro, in alto nel palco ([_Palco.alto]); il fumetto sotto di lei, poi la
      // frase. Il lato lo dice [guida], non il punto da cui parte: prima si ricavava dal centro di Transcri, che sta
      // due punti a sinistra del centro dello schermo, e la pillola finiva a sinistra. Il suo posto salvato non cambia.
      if (await Core.startPill(centro.dx, centro.dy, home: rettangolo, ascolta: true, guida: alto / schermo) == null) {
        if (mounted) setState(() => _fuori = true);
        return;
      }
    }
    await Core.listen();
  }

  /// La pillola vera se ne va (entrando, o lasciando la prova): Transcri torna nel nido dell'app.
  void _ritira() {
    if (!_fuori) return;
    _fuori = false;
    Core.stopPill().catchError((_) {});
  }

  void _stop() {
    if (_mandata) return;
    HapticFeedback.mediumImpact();
    setState(() => _mandata = true);
    Core.stopListening().catchError((_) {
      if (mounted) {
        setState(() {
          _mandata = false;
          _problema = 'Non sono riuscito a fermarmi. Riprova, o salta.';
        });
      }
    });
  }

  /// Si esce dalla prova (avanti o indietro): se stava ascoltando, quello che hai detto si butta.
  void _lascia() {
    if (Core.live.value.listening) Core.discardListening().catchError((_) {});
    _ritira();
  }

  void _salta() {
    _lascia();
    widget.onFine(false);
  }

  void _indietro() {
    _lascia();
    widget.onIndietro();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _indietro();
      },
      child: Paper(
        child: ValueListenableBuilder<Live>(
          valueListenable: _vista,
          builder: (context, live, _) {
            final ascolta = live.listening;
            final lavora = _mandata || live.phase == 'PROCESSING';
            final (principale, azione) = _principale(live);
            // Toccare lui fa come «Prova» (10 nov): solo quando «Prova» si può toccare.
            final provabile = widget.haChiave && _prima == null && !lavora && !ascolta && !_chiede;
            // La prova guidata (11 nov): mentre ascolta e trascrive restano chiari la pillola, il fumetto e la frase; il
            // resto si spegne ([Velo.guida]). «Salta» in fondo resta com'è.
            final guidata = (ascolta || lavora) && _prima == null && (_diLato || _fuori);
            final avviso = !widget.haChiave ? 'Per trascrivere serve la chiave Groq: puoi metterla adesso o più tardi.' : _problema;
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Indietro', onPressed: _indietro),
              ),
              bottomNavigationBar: PiedeIntro(conta: '3 di 3', principale: principale, onPrincipale: azione, secondario: 'Salta', onSecondario: _salta),
              // Su un telefono basso o col testo grande si scorre; se no riempie, con Transcri al centro.
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimatedOpacity(
                            opacity: guidata ? Velo.guida : 1,
                            duration: Durata.lenta,
                            curve: Curva.standard,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Spazio.s6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: Spazio.s2,
                                children: [
                                  Text(_prima == null ? 'Provalo adesso.' : 'Fatto.', style: Testo.titoloPagina.copyWith(color: c.testo)),
                                  Text(switch ((_prima, ascolta)) {
                                    (_?, _) => 'È già negli appunti. Entra: la trovi nella lista.',
                                    (_, true) => 'Ti ascolto. Quando hai finito, tienimi premuto o tocca Stop.',
                                    _ => 'Tocca Transcri: va sul bordo e ti ascolta.',
                                  }, style: Testo.testo.copyWith(color: c.testoSecondario)),
                                ],
                              ),
                            ),
                          ),
                          // Lui disegnato al doppio al centro, con l'anello: il posto che prende è tutto, così non esce sopra le parole.
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: _Transcri.ingombro),
                              child: _Palco(
                                key: _palco,
                                diLato: _diLato,
                                transcri: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: provabile ? _prova : null,
                                  // Tienilo premuto per spegnerlo (10 nov); «Stop» resta in basso.
                                  onLongPress: ascolta ? _stop : null,
                                  child: AnimatedSwitcher(
                                    duration: Durata.normale,
                                    child: switch ((_diLato, _entrato || _fuori)) {
                                      // Entrato, o la pillola vera è fuori: qui non c'è.
                                      (_, true) => const SizedBox.shrink(),
                                      // Di lato è la pillola del bordo; il tocco resta largo un dito.
                                      (true, _) => const SizedBox.square(dimension: Misura.tocco, child: Align(alignment: Alignment.centerRight, child: PillolaBordo())),
                                      _ => _Transcri(key: _transcri, fase: lavora ? 'PROCESSING' : (ascolta ? 'RECORDING' : null)),
                                    },
                                  ),
                                ),
                                // Accanto alla pillola (disegnata o vera), a passi: prima «parla», poi «tienimi premuto».
                                // Le fasi (11 nov): la frase; «Avanti», fermami; fermata (l'evento), trascrivo; poi la scheda.
                                fumetto: switch ((lavora, _fase)) {
                                  (true, _) => 'Ricevuto: trascrivo…',
                                  (_, 0) => 'Leggi la frase qui sotto.',
                                  _ when _fuori => 'Ora tienimi premuto per fermarmi, oppure aprimi e tocca Stop.',
                                  _ => 'Ora tienimi premuto per fermarmi, oppure tocca Stop.',
                                },
                                // In ogni fase si può fermare: lo dice sotto, finché non è la fase che lo chiede.
                                sotto: !lavora && _fase == 0 ? 'Puoi fermarmi quando vuoi: tienimi premuto.' : null,
                                onAvanti: !lavora && _fase == 0 ? () => setState(() => _fase = 1) : null,
                                conFumetto: guidata,
                                scheda: _prima == null ? null : _PrimaScheda(_schedaDi(_prima!, key: _scheda)),
                                // Cosa dire (11 nov, suo): una frase da leggere ad alta voce, sotto il fumetto, mentre ascolta.
                                frase: ascolta && (_diLato || _fuori) ? _ProvaTranscriState.frase : null,
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: guidata ? Velo.guida : 1,
                            duration: Durata.lenta,
                            curve: Curva.standard,
                              child: Padding(
                              padding: const EdgeInsets.fromLTRB(Spazio.s6, 0, Spazio.s6, Spazio.s4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Il tempo e l'onda, come nella barra della trascrizione: si vede che sta registrando.
                                  if (ascolta) ...[
                                    Text(VoceInBarra.tempo(live.seconds), style: Testo.orario.copyWith(color: c.testoSecondario), textAlign: TextAlign.center),
                                    const SizedBox(height: Spazio.s2),
                                    const Center(child: OndaVoce(larga: Spazio.s10 * 2, alta: Spazio.s5)),
                                  ],
                                  if (avviso != null) Text(avviso, style: Testo.piccolo.copyWith(color: c.testoSecondario), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Dove sta Transcri nella prova: al centro, o (di lato) sul bordo destro come la pillola, col [fumetto] che lo
/// indica; quando la prima trascrizione è pronta, al centro la sua [scheda].
class _Palco extends StatelessWidget {
  const _Palco({
    super.key,
    required this.diLato,
    required this.transcri,
    required this.fumetto,
    required this.conFumetto,
    this.scheda,
    this.frase,
    this.sotto,
    this.onAvanti,
  });

  /// Dove sta la pillola (vera o disegnata) nel palco, dall'alto: in alto, ma non in cima (11 nov, suo).
  static const alto = 0.12;
  static const _altezza = Alignment(1, -1 + 2 * alto);

  /// La riga piccola sotto il fumetto, e «Avanti» per passare alla fase dopo (null: non ci sono).
  final String? sotto;
  final VoidCallback? onAvanti;

  /// La frase da leggere, al centro (null: non c'è).
  final String? frase;

  /// [conFumetto]: il fumetto accanto alla pillola, sul bordo destro, si vede.
  final bool diLato, conFumetto;

  /// Cosa dice il fumetto, il passo di adesso.
  final String fumetto;
  final Widget transcri;
  final Widget? scheda;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedAlign(
          alignment: diLato ? _altezza : Alignment.center,
          duration: Durata.lenta,
          curve: Curva.standard,
          child: Padding(padding: const EdgeInsets.only(right: Spazio.s1), child: transcri),
        ),
        // Sotto la pillola il fumetto, con la freccia che la indica; sotto ancora, con respiro, la frase da leggere,
        // grande. Spento, il fumetto non prende i tocchi (starebbe sopra Transcri).
        // Posizionato: il palco non chiede quanto è alto (sta in un SliverFillRemaining che lo misura).
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: const _SottoPillola(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IgnorePointer(
                      ignoring: !conFumetto,
                      child: AnimatedOpacity(
                        opacity: conFumetto ? 1 : 0,
                        duration: Durata.normale,
                        child: Align(alignment: Alignment.centerRight, child: _fumetto(context)),
                      ),
                    ),
                    // La frase arriva e se ne va piano, non di colpo.
                    AnimatedSwitcher(
                      duration: Durata.lenta,
                      switchInCurve: Curva.standard,
                      switchOutCurve: Curva.uscita,
                      child: frase == null
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              key: const ValueKey('frase'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: Spazio.s8),
                                Text('Leggi ad alta voce', textAlign: TextAlign.center, style: Testo.etichetta.copyWith(color: c.testoSecondario)),
                                const SizedBox(height: Spazio.s2),
                                Text('«$frase»', textAlign: TextAlign.center, style: Testo.titoloSezione.copyWith(color: c.testo)),
                              ],
                            ),
                    ),
                  ],
                ),
          ),
        ),
        if (scheda case final scheda?)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spazio.s6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Durata.normale,
                curve: Curva.standard,
                builder: (context, t, figlio) => Opacity(opacity: t, child: Transform.scale(scale: Scala.scelta + (1 - Scala.scelta) * t, child: figlio)),
                child: scheda,
              ),
            ),
          ),
      ],
    );
  }

  /// Il fumetto: la freccia in su verso la pillola, quello che c'è da fare adesso, la riga piccola ([sotto]) e
  /// «Avanti» ([onAvanti]: toccando il fumetto si passa alla fase dopo).
  Widget _fumetto(BuildContext context) {
    final c = context.col;
    final testo = c.suFloater;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Misura.tavolozza),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: (Misura.tondo - Misura.iconaMedia) / 2 - Spazio.s4 + Spazio.s1),
            child: Icon(Icons.arrow_upward_rounded, size: Misura.iconaMedia, color: c.testo),
          ),
          Semantics(
            button: onAvanti != null,
            child: GestureDetector(
              onTap: onAvanti,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Spazio.s3, vertical: Spazio.s2),
                decoration: BoxDecoration(color: c.floater, borderRadius: BorderRadius.circular(Raggio.campo), boxShadow: Ombra.sospeso),
                // Sempre lì, sotto la pillola: cambia solo quello che dice, con una dissolvenza calma.
                child: AnimatedSize(
                  duration: Durata.normale,
                  curve: Curva.standard,
                  alignment: Alignment.topRight,
                  child: AnimatedSwitcher(
                    duration: Durata.lenta,
                    switchInCurve: Curva.standard,
                    switchOutCurve: Curva.uscita,
                    layoutBuilder: (ora, prima) => Stack(alignment: Alignment.topLeft, children: [...prima, ?ora]),
                    child: Column(
                    key: ValueKey(fumetto),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Spazio.s1,
                    children: [
                      Text(fumetto, style: Testo.etichetta.copyWith(color: testo)),
                      if (sotto case final sotto?) Text(sotto, style: Testo.piccolo.copyWith(color: testo)),
                      if (onAvanti != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Avanti', style: Testo.etichetta.copyWith(color: testo, fontWeight: FontWeight.w600)),
                              Icon(Icons.chevron_right_rounded, size: Misura.iconaMedia, color: testo),
                            ],
                          ),
                        ),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dove stanno il fumetto e la frase: sotto la pillola ([_Palco.alto] del palco, più mezza pillola e un respiro), tra
/// i margini; quello che non ci sta va sotto, senza spingere niente.
class _SottoPillola extends SingleChildLayoutDelegate {
  const _SottoPillola();

  static const _sinistra = Spazio.s6, _destra = Spazio.s4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(maxWidth: (c.maxWidth - _sinistra - _destra).clamp(0, double.infinity));

  @override
  Offset getPositionForChild(Size palco, Size figlio) => Offset(_sinistra, palco.height * _Palco.alto + Misura.tondo / 2 + Spazio.s2);

  @override
  bool shouldRelayout(_SottoPillola old) => false;
}

/// La prima trascrizione al centro: il titolo sopra, fuori, e sotto la sua scheda della lista.
class _PrimaScheda extends StatelessWidget {
  const _PrimaScheda(this.scheda);

  final Widget scheda;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: Spazio.s3,
    children: [
      Text('Ecco la tua prima trascrizione', textAlign: TextAlign.center, style: Testo.titoloSezione.copyWith(color: context.col.testo)),
      scheda,
    ],
  );
}

/// Transcri nella prova, grande al centro: attorno l'anello della voce, staccato dal suo corpo da un vuoto del colore
/// della pagina (10 nov: «più grande, che non tocchi il bordo»); si allarga con la voce mentre ascolta e ondeggia
/// mentre lavora.
class _Transcri extends StatelessWidget {
  const _Transcri({super.key, required this.fase});

  /// 'RECORDING', 'PROCESSING' o null (fermo).
  final String? fase;

  static const scala = 2.0;

  /// L'anello e il vuoto: oltre il bordo del corpo di [Misura.anelloVoce] e [Misura.anelloVoceStacco].
  static const _anello = Misura.tondo + Misura.anelloVoce * 2, _vuoto = Misura.tondo + Misura.anelloVoceStacco * 2;

  /// Quanto esce, sopra e sotto, dal suo posto: disegnato in grande con l'anello, non va sopra le parole.
  static const ingombro = (_anello * scala - Misura.tondo) / 2;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: scala,
    child: SizedBox.square(
      dimension: Misura.tondo,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (fase != null) ...[
            OverflowBox(maxWidth: _anello, maxHeight: _anello, child: VoiceCircle(phase: fase!, size: _anello)),
            OverflowBox(
              maxWidth: _vuoto,
              maxHeight: _vuoto,
              child: DecoratedBox(
                decoration: BoxDecoration(color: context.col.pagina, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: _vuoto),
              ),
            ),
          ],
          const TranscriCorpo(),
        ],
      ),
    ),
  );
}
