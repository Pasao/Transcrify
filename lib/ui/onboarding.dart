import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/native.dart';
import 'molecole/piede_intro.dart';
import 'theme.dart';

final _keyPattern = RegExp(r'^gsk_[A-Za-z0-9]{20,}$');

/// La chiave Groq con il minimo sforzo: apri Groq, crei, copi, torni.
/// Al ritorno la chiave si trova da sola negli appunti.
///
/// È la stessa pagina ovunque: nell'introduzione (con la freccia per tornare alla prima pagina, e «Salta» in basso a
/// sinistra: la chiave si potrà mettere quando serve) e dalle impostazioni per cambiarla (la X in alto a destra
/// chiude senza toccare niente). L'azione che serve adesso (Apri Groq, Usa questa chiave) sta in basso a destra.

/// La testata dell'introduzione è dipinta coi colori di Transcri: sopra va il bianco, e la sua ombra è nera.
/// Eccezione dichiarata al design system (non c'è un token «su Transcri»).
const _suTranscri = Colors.white; // ds:eccezione: sopra i colori di Transcri
const _ombraTranscri = Colors.black; // ds:eccezione: l'ombra del disegno di Transcri

class KeyPage extends StatefulWidget {
  const KeyPage({super.key, required this.onSaved, required this.onClose, this.onBack});

  final VoidCallback onSaved;

  /// La X (o «Salta» nell'introduzione): chiude senza cambiare niente.
  final VoidCallback onClose;

  /// Solo nell'introduzione: torna alla prima pagina (freccia in alto e gesto indietro).
  final VoidCallback? onBack;

  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> with WidgetsBindingObserver {
  final field = TextEditingController();
  String? found;
  bool wentToGroq = false;
  bool checking = false;
  bool manual = false;
  String? problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lookInClipboard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    field.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _lookInClipboard();
  }

  Future<void> _lookInClipboard() async {
    // Mentre controlla, o dopo che hai scelto di incollarla tu, gli appunti non cambiano quello che vedi.
    if (checking || manual) return;
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } catch (_) {
      return;
    }
    // La stessa chiave che Groq ha già rifiutato non torna su da sola.
    if (text != null && _keyPattern.hasMatch(text) && text != _rifiutata && mounted) {
      setState(() {
        found = text;
        problem = null;
      });
    }
  }

  /// L'ultima chiave che Groq non ha riconosciuto.
  String? _rifiutata;

  Future<void> _openGroq() async {
    setState(() {
      wentToGroq = true;
      problem = null;
    });
    var aperta = false;
    try {
      aperta = await launchUrl(Uri.parse('https://console.groq.com/keys'), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!aperta && mounted) setState(() => problem = 'Non riesco ad aprire Groq. Vai su console.groq.com/keys dal browser.');
  }

  Future<void> _use(String key) async {
    if (checking || key.isEmpty) return;
    setState(() {
      checking = true;
      problem = null;
    });
    String? error;
    try {
      error = await Core.checkKey(key);
      if (error == null) await Core.setKey(key);
    } catch (_) {
      error = 'Non riesco a controllarla adesso. Riprova tra poco.';
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        checking = false;
        if (error == 'Chiave non valida') _rifiutata = key;
        problem = error == 'Chiave non valida' ? 'Groq non riconosce questa chiave.' : error;
      });
      return;
    }
    // La chiave non resta negli appunti dopo averla usata.
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {}
    widget.onSaved();
  }

  /// Incollarla a mano: anche quando negli appunti ce n'era un'altra (magari quella sbagliata).
  void _incollaIo() => setState(() {
    manual = true;
    found = null;
    problem = null;
  });

  /// L'azione in basso a destra: quella che serve adesso. Mentre controlla, o col campo vuoto, spenta.
  (String, VoidCallback?) get _principale {
    if (found != null) return ('Usa questa chiave', checking ? null : () => _use(found!));
    if (manual) return ('Usa questa chiave', checking || field.text.trim().isEmpty ? null : () => _use(field.text.trim()));
    return ('Apri Groq', _openGroq);
  }

  static String _mask(String k) => '${k.substring(0, 4)}••••••••${k.substring(k.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Una chiave Groq.', style: display(context, size: 24)),
          const SizedBox(height: 6),
          Text('È gratis. Tre passi, il terzo lo facciamo noi.', style: t.bodyMedium?.copyWith(color: context.col.testoSecondario)),
          const SizedBox(height: 22),
          _Passo(n: 1, color: context.col.azione, text: 'Apri Groq e accedi, anche con Google.', done: wentToGroq || found != null),
          _Passo(n: 2, color: context.col.transcriB, text: 'Premi “Create API Key”, dagli un nome e copiala.', done: found != null),
          _Passo(n: 3, color: context.col.successo, text: 'Torna qui: la troviamo da soli negli appunti.', done: false),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: Durata.normale,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            child: found != null ? _FoundCard(key: const ValueKey('found'), masked: _mask(found!)) : const SizedBox.shrink(),
          ),
          if (problem != null) ...[const SizedBox(height: 12), Text(problem!, style: t.bodySmall?.copyWith(color: context.col.errore))],
          // Il primario sta in basso a destra (PiedeIntro); qui il secondario con il bordo.
          if (manual) ...[
            const SizedBox(height: 12),
            TextField(
              controller: field,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'gsk_…'),
              onChanged: (_) => setState(() => problem = null),
              onSubmitted: (v) => _use(v.trim()),
            ),
          ] else ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: checking ? null : _incollaIo,
              child: Text(found == null ? 'Ho già una chiave, la incollo io' : 'Incollo un’altra chiave'),
            ),
          ],
          const SizedBox(height: 20),
          Text('La chiave resta cifrata su questo telefono e parla solo con Groq.', style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );

    final close = IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Chiudi', onPressed: widget.onClose);
    final intro = widget.onBack != null;
    final (principale, onPrincipale) = _principale;
    return PopScope(
      // Nell'introduzione il gesto indietro torna alla prima pagina; altrove chiude.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) (widget.onBack ?? widget.onClose)();
      },
      child: Paper(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: widget.onBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Indietro', onPressed: widget.onBack),
            actions: intro ? null : [close, const SizedBox(width: 8)],
          ),
          body: SafeArea(child: ListView(children: [steps])),
          bottomNavigationBar: PiedeIntro(
            conta: intro ? '2 di 3' : null,
            principale: checking ? 'Controllo…' : principale,
            onPrincipale: onPrincipale,
            secondario: intro ? 'Salta' : null,
            onSecondario: widget.onClose,
          ),
        ),
      ),
    );
  }
}

/// L'apertura: un colore pieno, la pillola che respira sul bordo e la promessa.
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  /// Quanto è alta almeno, e quanto posto lascia sopra le parole per la bolla che vola.
  static const _alta = 380.0, _sopra = 120.0;

  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat(); // ds:eccezione: il movimento di Transcri

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Alta almeno [_alta]; col testo grande cresce lei (le parole non escono mai sopra, sotto la barra di stato).
    return Container(
      constraints: BoxConstraints(minHeight: _alta + top),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.col.azione, context.col.transcriB]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Raggio.foglio)),
      ),
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          // Una bolla nasce, vola al bordo e diventa la pillola, in loop.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(painter: _PillPainter(_c.value)),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, top + _sopra, 56, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transcrify',
                  style: orarioStyle(context, size: 13, color: _suTranscri.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Parla.\nÈ già '),
                      TextSpan(
                        text: 'copiato.',
                        style: display(
                          context,
                          size: 46,
                          strong: true,
                          color: _suTranscri,
                        ),
                      ),
                    ],
                  ),
                  style: display(context, size: 46, color: _suTranscri),
                ),
                const SizedBox(height: 12),
                Text(
                  'Transcri vive sul bordo di ogni app. Lo tocchi, detti, incolli.',
                  style: Testo.testoGrande.copyWith(
                    color: _suTranscri.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    double ease(double x) => 1 - math.pow(1 - x.clamp(0, 1), 3).toDouble();
    final fly = ease(t / 0.45);
    final settle = ease((t - 0.45) / 0.2);
    final fade = t > 0.9 ? (1 - (t - 0.9) / 0.1) : 1.0;

    final start = Offset(size.width * 0.3, size.height * 0.28);
    final end = Offset(size.width - 9, size.height * 0.34);
    final x = start.dx + (end.dx - start.dx) * fly;
    final y = start.dy + (end.dy - start.dy) * math.pow(fly, 2).toDouble();
    final w = 46 + (10 - 46) * settle;
    final h = 46 + (72 - 46) * settle;
    final breathe = settle >= 1 ? 0.7 + 0.3 * math.sin(t * math.pi * 6).abs() : 1.0;

    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: h), Radius.circular(math.min(w, h) / 2));
    canvas.drawRRect(
      rect.shift(const Offset(0, 6)),
      Paint()
        ..color = _ombraTranscri
            .withValues(alpha: 0.18 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = _suTranscri.withValues(alpha: 0.95 * fade * breathe),
    );
  }

  @override
  bool shouldRepaint(_PillPainter old) => old.t != t;
}

class _Passo extends StatelessWidget {
  const _Passo({required this.n, required this.text, required this.done, required this.color});

  final int n;
  final String text;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: Durata.normale,
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? color : color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: done
                ? Icon(Icons.check_rounded, size: Misura.iconaPiccola, color: context.col.suAzione)
                : Text('$n', style: Testo.etichetta.copyWith(color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({super.key, required this.masked});

  final String masked;

  @override
  Widget build(BuildContext context) {
    // B6 «ChiaveTrovata»: una scheda neutra, verde solo la spunta; «Usa questa chiave» è il principale, in basso.
    return Scheda(
      padding: const EdgeInsets.all(Spazio.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: Misura.iconaPiccola, color: context.col.successo),
              const SizedBox(width: Spazio.s2),
              Flexible(child: Text('Trovata negli appunti', style: Testo.etichetta.copyWith(color: context.col.testo))),
            ],
          ),
          const SizedBox(height: 8),
          Text(masked, style: orarioStyle(context, size: 16, color: context.col.testo)),
        ],
      ),
    );
  }
}

/// Prima pagina del primo avvio: cos'è e come si usa, in tre righe. Poi la chiave.
class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.onNext, required this.onClose});

  final VoidCallback onNext;

  /// «Salta» in basso a sinistra: salta l'introduzione (o la chiude, se la stai rivedendo).
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Paper(
      child: Scaffold(
        bottomNavigationBar: PiedeIntro(conta: '1 di 3', principale: 'Avanti', onPrincipale: onNext, secondario: 'Salta', onSecondario: onClose),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _Hero(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Come funziona', style: display(context, size: 24)),
                  const SizedBox(height: 18),
                  _How(
                    icon: Icons.bubble_chart_rounded,
                    color: context.col.azione,
                    title: 'Fai uscire Transcri',
                    text: 'Toccalo: vola sul bordo dello schermo e resta lì, sopra tutto.',
                  ),
                  _How(
                    icon: Icons.mic_rounded,
                    color: context.col.transcriB,
                    title: 'Tienilo premuto e parla',
                    text: 'Ti ascolta ovunque tu stia scrivendo: WhatsApp, note, mail. Per fermarlo tienilo premuto di nuovo, o aprilo e tocca Stop.',
                  ),
                  _How(
                    icon: Icons.content_paste_rounded,
                    color: context.col.successo,
                    title: 'Incolla',
                    text: 'Il testo è già negli appunti, anche ripulito da esitazioni e ripetizioni se vuoi.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _How extends StatelessWidget {
  const _How({required this.icon, required this.color, required this.title, required this.text});

  final IconData icon;
  final Color color;
  final String title, text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(text, style: t.bodyMedium?.copyWith(color: context.col.testoSecondario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
