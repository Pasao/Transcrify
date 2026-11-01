import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/native.dart';
import 'common.dart';
import 'theme.dart';

/// I permessi per dettare: si chiedono qui, la prima volta che serve Transcri.
Future<bool> transcriReady(BuildContext context) async {
  if (!await Permission.microphone.isGranted) {
    final s = await Permission.microphone.request();
    await Permission.notification.request();
    if (!s.isGranted) {
      if (s.isPermanentlyDenied) await openAppSettings();
      return false;
    }
  }
  if (!await Core.canDrawOverlays()) {
    if (!context.mounted) return false;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Un ultimo permesso'),
        content: const Text(
          'Per stare sul bordo dello schermo, Transcrify deve poter “mostrare sopra altre app”. '
          'Nella prossima schermata attivalo e torna qui.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non ora')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apri')),
        ],
      ),
    );
    if (go == true) await Core.openOverlaySettings();
    return false;
  }
  return true;
}

/// Il nido di Transcri: la sua casa tonda dentro l'isola di destra del Dock. Lì sta seduto, respira,
/// sbatte gli occhi e si guarda intorno. Toccando il nido esce e vola al bordo; toccandolo di
/// nuovo torna, atterra con un sobbalzo e il nido si illumina. Quando è fuori resta il suo contorno.
/// Tenendolo premuto ascolta restando qui: il suo cerchio diventa rosso e si allarga con la voce, come
/// la pillola. Se lo trascini fuori, o esci dall'app, continua dal bordo; se torna qui, continua da qui.
class TranscriNest extends StatefulWidget {
  const TranscriNest({super.key, required this.on, required this.limitedUntil, required this.onChanged, this.onNeedKey, this.onAsleep});

  /// Se dorme (minuti finiti): toccarlo dice perché e quando torna.
  final VoidCallback? onAsleep;

  /// Se manca la chiave Groq: toccarlo la chiede invece di farlo uscire.
  final VoidCallback? onNeedKey;

  final bool on;

  /// Se i minuti sono finiti: quando tornano. Il nido dorme fino ad allora.
  final DateTime? limitedUntil;
  final VoidCallback onChanged;

  @override
  State<TranscriNest> createState() => TranscriNestState();
}

class TranscriNestState extends State<TranscriNest> with TickerProviderStateMixin {
  static const _outroMs = 640; // come OUTRO_MS nel nativo
  /// Quanto è grande la casa: la stessa misura delle altre isole del Dock.
  static const slot = dockRound;

  /// Quanto è grande Transcri dentro la casa: abbastanza margine perché l'anello colorato si legga.
  static const _inNest = 0.76;

  // 0 = a riposo, 1 = schiacciato fino in fondo; al rilascio torna con una molla che rimbalza.
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  // Il ritorno a casa: sobbalzo di Transcri e luce nel nido.
  late final _land = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  // La rincorsa prima di uscire: si gonfia, e la bolla nativa parte da quella misura.
  late final _swell = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
  final _transcriKey = GlobalKey();
  bool busy = false;
  bool? shownOn;

  /// Trascinandolo da fuori, Transcri è sopra il nido: la casa si accende per accoglierlo.
  bool _hot = false;

  @override
  void initState() {
    super.initState();
    Core.onNestHot((hot) {
      if (mounted) setState(() => _hot = hot);
    });
    Core.live.addListener(_liveChanged);
  }

  String _phase = 'IDLE';

  void _liveChanged() {
    final live = Core.live.value;
    if (live.phase == _phase) return;
    // Fuori lo dice la pillola; qui nessuno lo direbbe. L'audio resta in coda.
    if (live.phase == 'ERROR' && !(shownOn ?? widget.on) && live.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error!)));
    }
    setState(() => _phase = live.phase);
  }

  /// Cosa sta facendo qui nel Dock: null se è fermo, o se è fuori e lo dice la pillola.
  String? get _working => !(shownOn ?? widget.on) && const {'RECORDING', 'PROCESSING', 'SUCCESS'}.contains(_phase) ? _phase : null;

  bool get _listening => _working == 'RECORDING';

  /// Comincia ad ascoltare restando nel Dock.
  Future<void> listen() async {
    if (_blocked) return widget.onAsleep?.call();
    if (widget.onNeedKey != null) return widget.onNeedKey!();
    if (!await transcriReady(context)) return;
    HapticFeedback.heavyImpact();
    await Core.listen();
  }

  @override
  void dispose() {
    Core.live.removeListener(_liveChanged);
    Core.onNestHot(null);
    Core.setNest(null);
    _carried?.remove();
    _press.dispose();
    _land.dispose();
    _swell.dispose();
    super.dispose();
  }

  /// Centro e rettangolo di Transcri nel nido, in pixel fisici dello schermo.
  (Offset, List<double>) _home() {
    final box = _transcriKey.currentContext!.findRenderObject() as RenderBox;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final tl = box.localToGlobal(Offset.zero) * ratio;
    final br = box.localToGlobal(box.size.bottomRight(Offset.zero)) * ratio;
    final c = Offset((tl.dx + br.dx) / 2, (tl.dy + br.dy) / 2);
    return (c, [tl.dx, tl.dy, br.dx, br.dy]);
  }

  /// Spento solo se i minuti sono finiti e Transcri è a casa: richiamarlo si può sempre.
  bool get _blocked => widget.limitedUntil != null && !(_wantOut ?? widget.on);

  /// Dove l'ultimo tocco vuole Transcri: fuori (true) o a casa (false). Null = nessun tocco in corso.
  bool? _wantOut;

  /// Ogni tocco apre una generazione nuova. I passi ancora in sospeso di quella vecchia
  /// se ne accorgono e si fermano: così un tocco può interrompere un'animazione a metà.
  int _gen = 0;

  void _down() {
    if (_blocked) return;
    HapticFeedback.selectionClick();
    _press.animateTo(1, curve: Curves.easeOut);
  }

  /// Il rilascio: il nido rimbalza e, nel rimbalzo, Transcri parte (o torna).
  /// Funziona anche a metà di un volo: il nuovo parte da dove si trova la bolla.
  void _release() {
    // Sta ascoltando qui: il tocco ferma e manda.
    if (_listening) {
      HapticFeedback.mediumImpact();
      _press.animateBack(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
      Core.stopListening();
      return;
    }
    if (_blocked) {
      HapticFeedback.selectionClick();
      return widget.onAsleep?.call();
    }
    if (widget.onNeedKey != null) {
      _press.animateBack(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
      return widget.onNeedKey!();
    }
    _press.animateBack(0, duration: const Duration(milliseconds: 520), curve: Curves.elasticOut);
    _go();
  }

  void _cancel() => _press.animateBack(0, duration: const Duration(milliseconds: 200));

  Future<void> _go() async {
    final out = !(_wantOut ?? widget.on);
    _wantOut = out;
    final g = ++_gen;
    busy = true;
    if (out) {
      await _launch(g);
    } else {
      await _recall(g);
    }
    // Solo l'ultima generazione chiude: se nel frattempo c'è stato un altro tocco, tocca a lui.
    if (g != _gen || !mounted) return;
    busy = false;
    _wantOut = null;
    widget.onChanged();
  }

  // Lo stato mostrato resta quello voluto finché l'app non conferma lo stesso: niente testo che scatta.
  @override
  void didUpdateWidget(covariant TranscriNest old) {
    super.didUpdateWidget(old);
    // Rientrato da solo (trascinato nel nido): atterra come quando lo richiami tu.
    if (old.on && !widget.on && !busy && shownOn == null) _landed();
    if (!busy && shownOn != null && shownOn == widget.on) shownOn = null;
  }

  /// L'arrivo nel nido: la bolla nativa ci si è tuffata dentro, qui lui rispunta.
  /// Il nido ne sente il peso: si schiaccia all'impatto e torna su con una molla, come quando lo premi tu.
  void _landed() {
    HapticFeedback.mediumImpact();
    _hot = false;
    _land.forward(from: 0);
    _press.value = 1;
    _press.animateBack(0, duration: const Duration(milliseconds: 620), curve: Curves.elasticOut);
  }

  /// Dice al nativo dov'è il nido, solo finché questa pagina è quella in primo piano.
  void _reportNest(bool visible) {
    if (!mounted) return;
    if (!visible || _transcriKey.currentContext == null) {
      Core.setNest(null);
      return;
    }
    Core.setNest(_home().$2);
  }

  Future<void> _launch(int g) async {
    if (!await transcriReady(context)) return;
    if (g != _gen) return;
    await _swell.animateTo(1, curve: Curves.easeOutCubic);
    if (g != _gen || !mounted) return;
    // Il rettangolo misurato è già quello gonfio: la trasformazione conta.
    final (c, home) = _home();
    HapticFeedback.lightImpact();
    await Core.startPill(c.dx, c.dy, home: home);
    // La bolla nativa compare in qualche fotogramma: il nido si svuota solo quando lei lo copre già.
    await Future.delayed(const Duration(milliseconds: 90));
    if (g != _gen || !mounted) return;
    setState(() => shownOn = true);
    _swell.value = 0;
    await Future.delayed(const Duration(milliseconds: 540));
  }

  Future<void> _recall(int g) async {
    final (c, home) = _home();
    // Finché vola il nido resta vuoto; si riempie quando arriva.
    setState(() => shownOn = true);
    await Core.stopPill(x: c.dx, y: c.dy, home: home);
    await Future.delayed(const Duration(milliseconds: _outroMs - 20));
    if (g != _gen || !mounted) return;
    setState(() {
      shownOn = false;
      _landed();
    });
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // --- Tirarlo fuori a mano ---

  OverlayEntry? _carried;
  Offset _carryAt = Offset.zero;

  /// Il dito è ancora giù: se si alza mentre si chiedono i permessi, non c'è più niente da portare.
  bool _holding = false;

  /// Teneva premuto mentre già ascoltava: se non lo porta via, al rilascio si ferma.
  bool _stopOnRelease = false;

  void _holdStart(Offset at) {
    _holding = true;
    _carryAt = at;
    _stopOnRelease = _listening;
    if (_listening) {
      HapticFeedback.mediumImpact();
    } else if (!(shownOn ?? widget.on) && !busy) {
      listen();
    }
  }

  void _holdMove(LongPressMoveUpdateDetails d) {
    if (_carried == null && d.offsetFromOrigin.distance > 14) _grab(d.globalPosition);
    _carry(d.globalPosition);
  }

  void _holdEnd(Offset at) {
    _holding = false;
    if (_carried != null) {
      _drop(at);
    } else if (_stopOnRelease) {
      Core.stopListening();
    }
  }

  void _panStart(Offset at) {
    _holding = true;
    _stopOnRelease = false;
    _grab(at);
  }

  void _panEnd() {
    _holding = false;
    _drop(_carryAt);
  }

  Future<void> _grab(Offset at) async {
    if (_blocked || (shownOn ?? widget.on) || busy) return;
    if (widget.onNeedKey != null) return widget.onNeedKey!();
    if (!await transcriReady(context)) return;
    if (!mounted || !_holding) return;
    HapticFeedback.mediumImpact();
    _press.animateBack(0);
    _carryAt = at;
    _carried = OverlayEntry(
      builder: (_) => Positioned(
        left: _carryAt.dx - _Transcri.w / 2,
        top: _carryAt.dy - _Transcri.h / 2,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1.15,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_listening) const VoiceCircle(phase: 'RECORDING', size: _Transcri.w + 12),
                _Transcri(away: false, sleeping: false, land: _land),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_carried!);
    setState(() {});
  }

  void _carry(Offset at) {
    _carryAt = at;
    _carried?.markNeedsBuild();
  }

  Future<void> _drop(Offset at) async {
    final entry = _carried;
    if (entry == null) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final c = at * ratio;
    // Lasciato sopra casa sua: non è uscito.
    if ((c - _home().$1).distance < slot * ratio) {
      entry.remove();
      _carried = null;
      setState(() {});
      return;
    }
    final hw = _Transcri.w * ratio / 2, hh = _Transcri.h * ratio / 2;
    final g = ++_gen;
    busy = true;
    _wantOut = true;
    setState(() => shownOn = true);
    await Core.startPill(c.dx, c.dy, home: [c.dx - hw, c.dy - hh, c.dx + hw, c.dy + hh], place: true);
    // Sparisce la copia sotto il dito quando la bolla nativa è già lì.
    await Future.delayed(const Duration(milliseconds: 90));
    entry.remove();
    _carried = null;
    if (!mounted) return;
    setState(() {});
    if (g != _gen) return;
    busy = false;
    _wantOut = null;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final on = shownOn ?? widget.on;
    final sleeping = _blocked;
    // Una pagina sopra (impostazioni, una nota aperta): il nido non si vede, non si rientra lì.
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportNest(visible));
    // Il nido è neutro: il colore lo porta Transcri. Quando è fuori il nido resta vuoto.
    final home = (!on && !sleeping) || _hot;
    // Il posto di Transcri. Toccandolo si gonfia un attimo (prende la rincorsa) e da lì parte.
    final face = SizedBox(
      width: slot,
      height: slot,
      child: Center(
        child: AnimatedBuilder(
          animation: _swell,
          // Un po' più piccolo della sua casa: intorno resta un anello del suo colore, che si vede.
          builder: (context, child) => Transform.scale(scale: _inNest * (1 + 0.3 * _swell.value), child: child),
          child: KeyedSubtree(
            key: _transcriKey,
            child: _Transcri(away: on || _carried != null, sleeping: sleeping, land: _land),
          ),
        ),
      ),
    );
    final nest = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: slot,
      height: slot,
      decoration: BoxDecoration(gradient: _fill(islandColor(context), home), shape: BoxShape.circle),
      child: face,
    );
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapUp: (_) => _release(),
      onTapCancel: _cancel,
      // Tenuto fermo ascolta; mosso subito lo porti fuori. Come la pillola sul bordo.
      onLongPressStart: (d) => _holdStart(d.globalPosition),
      onLongPressMoveUpdate: _holdMove,
      onLongPressEnd: (d) => _holdEnd(d.globalPosition),
      onPanStart: (d) => _panStart(d.globalPosition),
      onPanUpdate: (d) => _carry(d.globalPosition),
      onPanEnd: (_) => _panEnd(),
      onPanCancel: _panEnd,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          // Premuto: il nido si abbassa appena. La molla elastica lo fa rimbalzare.
          final v = _press.value;
          return Transform.scale(scaleX: 1 - v * 0.02, scaleY: 1 - v * 0.06, child: child);
        },
        child: AnimatedScale(
          // Transcri sopra il nido: la casa si gonfia appena, pronta ad accoglierlo.
          scale: _hot ? 1.04 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_working != null && _carried == null) VoiceCircle(phase: _working!, size: slot),
              nest,
            ],
          ),
        ),
      ),
    );
  }

  /// Il fondo del nido: con lui a casa prende i suoi colori, tutto; quando esce si spegne. Niente alone.
  /// Mentre lavora il fondo è il suo cerchio, sotto: il nido si fa da parte.
  Gradient _fill(Color base, bool home) => LinearGradient(
    colors: [
      for (final c in transcriColors)
        _working != null ? base.withValues(alpha: 0) : (home ? Color.alphaBlend(c.withValues(alpha: 0.24), base) : base),
    ],
  );
}

/// Transcri a casa: una capsula bianca con due occhi. Respira, ogni tanto sbatte gli occhi,
/// si guarda intorno e fa un piccolo saltello. Quando è fuori resta il suo contorno;
/// quando dorme (minuti finiti) ha gli occhi chiusi e sta fermo.
class _Transcri extends StatefulWidget {
  const _Transcri({required this.away, required this.sleeping, required this.land});

  static const w = 46.0, h = 40.0;
  static const radius = 17.0;

  final bool away, sleeping;
  final Animation<double> land;

  @override
  State<_Transcri> createState() => _TranscriState();
}

class _TranscriState extends State<_Transcri> with SingleTickerProviderStateMixin {
  // Un ciclo di vita di 7 secondi: dentro ci sono respiro, battito d'occhi, sguardo e saltello.
  late final _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 7000))..repeat();

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _Transcri.w,
      height: _Transcri.h,
      child: AnimatedBuilder(
        animation: Listenable.merge([_life, widget.land]),
        builder: (context, _) => CustomPaint(
          painter: _TranscriPainter(
            t: _life.value,
            land: widget.land.value,
            away: widget.away,
            sleeping: widget.sleeping,
            outline: context.tk.faint,
          ),
        ),
      ),
    );
  }
}

class _TranscriPainter extends CustomPainter {
  _TranscriPainter({required this.t, required this.land, required this.away, required this.sleeping, required this.outline});

  final double t, land;
  final bool away, sleeping;
  final Color outline;

  /// 0→1→0 dentro la finestra [a, b] del ciclo.
  double _bump(double a, double b) {
    if (t < a || t > b) return 0;
    return math.sin((t - a) / (b - a) * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (away) {
      // Il posto vuoto: contorno tratteggiato.
      final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_Transcri.radius)));
      final paint = Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final m in path.computeMetrics()) {
        // Trattini tutti uguali anche dove il contorno si chiude: il passo si adatta alla lunghezza.
        final n = (m.length / 6).round();
        final step = m.length / n;
        for (var i = 0; i < n; i++) {
          canvas.drawPath(m.extractPath(i * step, i * step + step / 2), paint);
        }
      }
      return;
    }
    final alive = !sleeping;
    // Respiro: due respiri per ciclo. Saltello verso la fine. Atterraggio: schiacciato e poi su.
    final breath = alive ? math.sin(t * math.pi * 4) * 0.025 : math.sin(t * math.pi * 2) * 0.012;
    final hop = alive ? _bump(0.88, 0.95) : 0.0;
    // Il ritorno: la bolla nativa si tuffa nel nido e sparisce; da lì lui rispunta piccolo,
    // si gonfia un attimo oltre la sua misura (si riprende il posto) e si sistema.
    final pop = land == 0 || land == 1 ? 1.0 : 0.4 + 0.6 * Curves.easeOutBack.transform(land);
    final sy = 1 + breath - hop * 0.04;
    final sx = 1 - breath * 0.6 + hop * 0.02;
    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.scale(pop);
    canvas.translate(-w / 2, -h / 2);
    canvas.translate(w / 2, h);
    canvas.scale(sx, sy);
    canvas.translate(-w / 2, -h - hop * 6);
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_Transcri.radius));
    canvas.drawRRect(
      body.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [for (final c in transcriColors) c.withValues(alpha: sleeping ? 0.5 : 1)],
        ).createShader(Offset.zero & size),
    );

    // Gli occhi: sbatte due volte per ciclo, guarda a destra e poi a sinistra.
    final look = alive ? (_bump(0.40, 0.58) * 2.2 - _bump(0.62, 0.76) * 2.2) : 0.0;
    final blink = alive ? math.max(_bump(0.20, 0.235), _bump(0.71, 0.745)) : 1.0;
    final eye = Paint()..color = Colors.white;
    // Stesse proporzioni degli occhi che disegna la parte nativa in volo: non cambia personaggio.
    final ey = h * 0.36;
    final r = math.min(w, h) * 0.075;
    for (final dx in [-w * 0.17, w * 0.17]) {
      final c = Offset(w / 2 + dx + look, ey);
      if (blink > 0.85 || sleeping) {
        // Occhi chiusi: un trattino.
        canvas.drawLine(
          c - Offset(r * 1.2, 0),
          c + Offset(r * 1.2, 0),
          eye
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 2.4 * (1 - blink)), eye);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TranscriPainter old) =>
      old.t != t || old.land != land || old.away != away || old.sleeping != sleeping || old.outline != outline;
}
