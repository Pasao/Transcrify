import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cambio_colore.dart';
import '../../core/native.dart';
import '../../core/regole_colori.dart';
import '../atomi.dart';
import '../ds.dart';
import 'conferma.dart';

/// La rosa dei colori: la sola scelta del colore (7 nov, sua: «la rosa la amo»; via la fila che scorreva di lato, «non
/// ti ricordi che colore hai scelto»). La apre `apriSceltaColore` (`scelta_colore.dart`).
///
/// - Due anelli intorno al centro: dentro otto colori più chiari, fuori i sedici vivi del giro ([Tinte.rosaDentro],
///   [Tinte.rosaFuori]). Quello scelto ha l'anello e la spunta.
/// - Al centro la ✕: senza colore.
/// - Il dito che scorre sulla rosa accende il colore che ha sotto e in alto ne dice il nome (il tuo, o quello della
///   tavolozza); lasciandolo lì, lo sceglie. Anche un tocco sceglie.
/// - Ogni colore scelto si vede subito sulle schede ([CambioColore.prova]), ma è una prova: «Annulla» rimette tutto
///   com'era (anche i nomi), «Fatto» lo tiene; così anche «indietro» e un tocco fuori (si tiene, e dopo c'è la pillola
///   per annullare). Finito il movimento di chiusura, [onChiusa] dice se tenere.
/// - Un colore già usato ha un puntino pieno appena fuori (verso il bordo); scorrendoci sopra, quante ne ha.
/// - Sotto, col colore scelto, il campo piccolo per il suo nome (si vede nelle cartelle). Solo quello (10 nov: «troppa
///   roba»): la regola e «Offusca sempre» stanno nelle Impostazioni → Etichette.
/// - I colori che hai già scelto (con un nome, una regola o delle trascrizioni) sono pieni; gli altri, liberi, più
///   piccoli e velati ([Misura.rosaLibera]): così sai subito quali hai.
/// - Aprendosi i due anelli escono dal centro come due strati che si muovono insieme, e arrivano insieme; chiudendosi
///   rientrano al contrario.
class Tavolozza extends StatefulWidget {
  const Tavolozza({super.key, required this.cambio, required this.onCambiati, required this.onChiusa, this.usi = const {}});

  final CambioColore cambio;

  /// Quante trascrizioni ha già ogni colore ([Segni.usi]): quelli in uso hanno un puntino appena fuori, e scorrendoci
  /// sopra il nome dice quante sono («Relazioni · 12»). Gli altri sono liberi.
  final Map<Colore, int> usi;

  /// Dopo ogni colore provato: chi l'ha aperta ridisegna le sue schede.
  final VoidCallback onCambiati;

  /// Chiusa: true se si tiene quello che hai cambiato, false per «Annulla».
  final ValueChanged<bool> onChiusa;

  /// Quanto è larga la rosa: l'anello di fuori e il tocco dei suoi puntini.
  static const lato = 2 * Misura.rosaFuori + Misura.bottoneBasso;

  /// Dove sta il puntino [i] di un anello di [quanti] a distanza [raggio] dal centro: dall'alto, in senso orario.
  static Offset posto(int i, int quanti, double raggio) => Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / quanti, raggio);

  @override
  State<Tavolozza> createState() => _TavolozzaState();
}

class _TavolozzaState extends State<Tavolozza> with SingleTickerProviderStateMixin {
  late final _apri = AnimationController(vsync: this, duration: Durata.rosa)..forward();

  /// Dentro: piano, su tutto il tempo. Fuori: parte dopo (e, chiudendo, aspetta), più svelto. Arrivano insieme.
  late final _dentro = CurvedAnimation(parent: _apri, curve: Curva.standard, reverseCurve: Curva.uscita);
  late final _fuori = CurvedAnimation(parent: _apri, curve: Curva.rosaFuoriApre, reverseCurve: Curva.rosaFuoriChiude);

  final _nome = TextEditingController();

  /// Il colore sotto il dito mentre scorre ((null,): la ✕ del centro); null se il dito non c'è o non è su un colore.
  (Colore?,)? _sotto;
  bool _chiudendo = false;

  /// Hai dato un colore (o tolto con la ✕): chiudendo, la rosa se ne va più svelta ([Durata.rosaVia]).
  bool _dato = false;

  CambioColore get _cambio => widget.cambio;

  @override
  void initState() {
    super.initState();
    _leggiNome();
  }

  @override
  void dispose() {
    _dentro.dispose();
    _fuori.dispose();
    _apri.dispose();
    _nome.dispose();
    super.dispose();
  }

  void _leggiNome() => _nome.text = Segni.nomi.value[_cambio.comune?.chiave] ?? '';

  /// Il nome scritto si salva quando cambi colore o con «Fatto», solo se è cambiato («Annulla» rimette i nomi com'erano).
  Future<void> _salvaNome() async {
    final c = _cambio.comune;
    if (c != null && _nome.text.trim() != (Segni.nomi.value[c.chiave] ?? '')) await Segni.nomina(c, _nome.text);
  }

  /// Un colore già tuo: ha un nome, una regola o delle trascrizioni (o è quello scelto adesso).
  bool _tuo(Colore c, bool scelto) =>
      scelto || Segni.nomi.value.containsKey(c.chiave) || RegoleColori.di(c) != null || (widget.usi[c] ?? 0) > 0;

  Future<void> _scegli(Colore? c) async {
    if (_chiudendo || (!_cambio.misti && c == _cambio.comune)) return;
    await _salvaNome();
    _dato = true;
    final prova = _cambio.prova(c);
    if (mounted) setState(_leggiNome);
    widget.onCambiati();
    await prova;
  }

  Future<void> _chiudi(bool tieni) async {
    if (_chiudendo) return;
    _chiudendo = true;
    if (tieni) await _salvaNome();
    if (_dato) _apri.reverseDuration = Durata.rosaVia;
    await _apri.reverse();
    widget.onChiusa(tieni);
  }

  /// Quale colore sta sotto [p] (dentro la rosa): il puntino più vicino, se il dito è nel suo tocco.
  (Colore?,)? _bersaglio(Offset p) {
    final d = p - const Offset(Tavolozza.lato / 2, Tavolozza.lato / 2);
    if (d.distance <= Misura.tondo / 2) return (null,);
    (Colore?,)? sotto;
    var vicino = Misura.bottoneBasso / 2;
    for (final (colori, raggio) in [(Tinte.rosaDentro, Misura.rosaDentro), (Tinte.rosaFuori, Misura.rosaFuori)]) {
      for (final (i, (tinta, luce)) in colori.indexed) {
        final quanto = (d - Tavolozza.posto(i, colori.length, raggio)).distance;
        if (quanto < vicino) (vicino, sotto) = (quanto, (Colore(tinta, luce),));
      }
    }
    return sotto;
  }

  void _scorri(Offset p) {
    final sotto = _bersaglio(p);
    if (sotto == _sotto) return;
    if (sotto != null) HapticFeedback.selectionClick();
    setState(() => _sotto = sotto);
  }

  void _lascia() {
    final sotto = _sotto;
    setState(() => _sotto = null);
    if (sotto != null) _scegli(sotto.$1);
  }

  /// Il nome di un colore: il tuo e quello della tavolozza («Relazioni · Blu 2»), o «Senza colore».
  static String _nomeDi(Colore? c) {
    if (c == null) return 'Senza colore';
    final suo = Segni.nomi.value[c.chiave], tavolozza = Tinte.nome(c.tinta, c.luce);
    return suo == null ? tavolozza : '$suo · $tavolozza';
  }

  /// In alto: il colore sotto il dito, se scorre; se no quello scelto (o «Colori diversi»).
  String get _titolo => switch (_sotto) {
    (final c?,) when (widget.usi[c] ?? 0) > 0 => '${Segni.nomi.value[c.chiave] ?? Tinte.nome(c.tinta, c.luce)} · ${widget.usi[c]}',
    (final c,) => _nomeDi(c),
    null when _cambio.misti => 'Colori diversi',
    null => _nomeDi(_cambio.comune),
  };

  /// Un anello: i [colori] in giro, a [raggio] dal centro quando [quanto] è 1.
  List<Widget> _anello(List<(int, int)> colori, double raggio, Animation<double> quanto) => [
    for (final (i, (tinta, luce)) in colori.indexed)
      // Ogni puntino nel suo tocco: in uno Stack crescerebbe fino a prendersi tutta la rosa.
      _esce(Tavolozza.posto(i, colori.length, raggio), quanto, SizedBox.square(dimension: Misura.bottoneBasso, child: _punto(Colore(tinta, luce)))),
    // Già in uso: il puntino appena fuori, che esce insieme al suo colore.
    for (final (i, (tinta, luce)) in colori.indexed)
      if ((widget.usi[Colore(tinta, luce)] ?? 0) > 0)
        _esce(
          Tavolozza.posto(i, colori.length, raggio + Misura.rosaUsoFuori),
          quanto,
          IgnorePointer(
            child: Container(
              key: ValueKey('in uso $tinta:$luce'),
              width: Misura.rosaUso,
              height: Misura.rosaUso,
              decoration: BoxDecoration(color: context.col.testo, shape: BoxShape.circle),
            ),
          ),
        ),
  ];

  /// [figlio] che esce dal centro fino a [dove] quando [quanto] è 1 (e compare mentre esce).
  static Widget _esce(Offset dove, Animation<double> quanto, Widget figlio) => AnimatedBuilder(
    animation: quanto,
    builder: (context, figlio) => Transform.translate(
      offset: dove * quanto.value,
      child: Opacity(opacity: quanto.value.clamp(0.0, 1.0), child: figlio),
    ),
    child: figlio,
  );

  /// Un colore della rosa, o (null) la ✕ del centro. Acceso (più grande) mentre il dito ci passa sopra.
  Widget _punto(Colore? colore) {
    final scelto = colore == null ? _cambio.ora.values.every((c) => c == null) : !_cambio.misti && colore == _cambio.comune;
    final tuo = colore == null || _tuo(colore, scelto);
    final base = PuntoColore.di(context, colore);
    return AnimatedScale(
      scale: _sotto != null && _sotto!.$1 == colore ? Misura.rosaSotto : (tuo ? Misura.rosaFerma : Misura.rosaLibera),
      duration: Durata.veloce,
      curve: Curva.standard,
      child: PuntoColore(
        tuo ? base : base.withValues(alpha: 1 - Misura.rosaLiberaVelo),
        etichetta: _nomeDi(colore),
        scelto: scelto,
        icona: colore == null ? Icons.close_rounded : null,
        misura: colore == null ? Misura.iconaGrande + Spazio.s2 : Misura.iconaGrande,
        onTap: () => _scegli(colore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final scelto = _cambio.comune;
    return PopScope(
      canPop: false,
      // «Indietro» e un tocco fuori: si chiude tenendo, col movimento della rosa.
      onPopInvokedWithResult: (uscita, _) {
        if (!uscita) _chiudi(true);
      },
      child: SizedBox(
        width: Misura.tavolozza,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spazio.s3, vertical: Spazio.s1),
              child: Text(
                _titolo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Testo.titoloScheda.copyWith(color: c.testo),
              ),
            ),
            Center(
              // Il dito sulla rosa è suo dal primo istante (anche se il fumetto scorre): scorrendo cerca il colore.
              child: RawGestureDetector(
                gestures: {
                  _Subito: GestureRecognizerFactoryWithHandlers<_Subito>(
                    _Subito.new,
                    (g) => g
                      ..onDown = ((d) => _scorri(d.localPosition))
                      ..onUpdate = ((d) => _scorri(d.localPosition))
                      ..onEnd = ((_) => _lascia())
                      ..onCancel = (() => setState(() => _sotto = null)),
                  ),
                },
                child: SizedBox.square(
                  dimension: Tavolozza.lato,
                  // Fuori sotto, dentro sopra, la ✕ sopra tutti: i puntini escono da sotto di lei.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._anello(Tinte.rosaFuori, Misura.rosaFuori, _fuori),
                      ..._anello(Tinte.rosaDentro, Misura.rosaDentro, _dentro),
                      SizedBox.square(dimension: Misura.tondo, child: _punto(null)),
                    ],
                  ),
                ),
              ),
            ),
            if (scelto != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spazio.s1),
                child: TextField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.sentences,
                  style: Testo.etichetta.copyWith(color: c.testo),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Che nome ha questa etichetta?',
                    prefixIcon: Icon(Icons.circle, size: Misura.iconaPiccola, color: PuntoColore.di(context, scelto)),
                  ),
                ),
              ),
            Conferma(principale: 'Fatto', onPrincipale: () => _chiudi(true), onAnnulla: () => _chiudi(false)),
          ],
        ),
      ),
    );
  }
}

/// Il trascinamento che prende il dito appena tocca: sulla rosa il dito cerca un colore, non fa scorrere il fumetto.
class _Subito extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
