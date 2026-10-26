import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/native.dart';
import 'theme.dart';

final _keyPattern = RegExp(r'^gsk_[A-Za-z0-9]{20,}$');

/// La chiave Groq con il minimo sforzo: apri Groq, crei, copi, torni.
/// Al ritorno la chiave si trova da sola negli appunti.
class KeyPage extends StatefulWidget {
  const KeyPage({super.key, required this.onSaved, this.replacing = false, this.onBack, this.onKeep});

  final VoidCallback onSaved;
  final bool replacing;

  /// Torna alla prima pagina dell'introduzione (freccia in alto e gesto indietro).
  final VoidCallback? onBack;

  /// Se una chiave c'è già (introduzione rivista da "Come funziona"): tienila e torna all'app.
  final VoidCallback? onKeep;

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
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null && _keyPattern.hasMatch(text) && mounted) {
      setState(() {
        found = text;
        problem = null;
      });
    }
  }

  Future<void> _openGroq() async {
    setState(() => wentToGroq = true);
    await launchUrl(Uri.parse('https://console.groq.com/keys'), mode: LaunchMode.externalApplication);
  }

  Future<void> _use(String key) async {
    setState(() {
      checking = true;
      problem = null;
    });
    final error = await Core.checkKey(key);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        checking = false;
        problem = error == 'Chiave non valida' ? 'Groq non riconosce questa chiave.' : error;
      });
      return;
    }
    await Core.setKey(key);
    // La chiave non resta negli appunti dopo averla usata.
    await Clipboard.setData(const ClipboardData(text: ''));
    widget.onSaved();
  }

  static String _mask(String k) => '${k.substring(0, 4)}••••••••${k.substring(k.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Ultima cosa: una chiave Groq.', style: display(context, size: 24)),
        const SizedBox(height: 6),
        Text('È gratis. Tre passi, il terzo lo facciamo noi.', style: t.bodyMedium?.copyWith(color: context.tk.muted)),
        const SizedBox(height: 22),
        _Step(n: 1, color: Tokens.blue, text: 'Apri Groq e accedi, anche con Google.', done: wentToGroq || found != null),
        _Step(n: 2, color: Tokens.violet, text: 'Premi “Create API Key”, dagli un nome e copiala.', done: found != null),
        _Step(n: 3, color: Tokens.green, text: 'Torna qui: la troviamo da soli negli appunti.', done: false),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a), child: c),
          ),
          child: found != null
              ? _FoundCard(
                  key: const ValueKey('found'),
                  masked: _mask(found!),
                  checking: checking,
                  onUse: () => _use(found!),
                )
              : FilledButton.icon(
                  key: const ValueKey('open'),
                  onPressed: _openGroq,
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                  label: const Text('Apri Groq'),
                ),
        ),
        if (problem != null) ...[
          const SizedBox(height: 12),
          Text(problem!, style: t.bodySmall?.copyWith(color: Tokens.red)),
        ],
        // Gerarchia: il primario sopra (Apri Groq / Usa questa chiave), poi il secondario
        // con il bordo, poi il terziario solo testo. Chi ha già una chiave la tiene come secondaria.
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
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: checking ? null : () => _use(field.text.trim()),
            child: const Text('Usa questa chiave'),
          ),
        ] else ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.onKeep ?? () => setState(() => manual = true),
            child: Text(widget.onKeep != null ? 'Tieni quella che hai' : 'Ho già una chiave, la incollo io'),
          ),
          if (widget.onKeep != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() => manual = true),
              child: const Text('Incollane un’altra'),
            ),
          ],
        ],
        const SizedBox(height: 20),
        Text('La chiave resta cifrata su questo telefono e parla solo con Groq.',
            style: t.bodySmall, textAlign: TextAlign.center),
      ]),
    );

    if (widget.replacing) {
      return Scaffold(appBar: AppBar(), body: SafeArea(child: ListView(children: [steps])));
    }
    // Seconda pagina dell'introduzione: solo la chiave, e si può tornare indietro.
    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        appBar: widget.onBack == null
            ? null
            : AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack)),
        body: SafeArea(child: ListView(children: [steps])),
        bottomNavigationBar: const PageCount('2 di 2'),
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
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: 380 + top,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Tokens.blue, Tokens.violet],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(children: [
        // Una bolla nasce, vola al bordo e diventa la pillola, in loop.
        Positioned.fill(child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _PillPainter(_c.value)))),
        Positioned(
          left: 24,
          right: 56,
          bottom: 32,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transcrify', style: monoStyle(context, size: 13, color: Colors.white.withValues(alpha: 0.75))),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Parla.\nÈ già '),
                TextSpan(text: 'copiato.', style: display(context, size: 46, strong: true, color: Colors.white)),
              ]),
              style: display(context, size: 46, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Transcri vive sul bordo di ogni app. Lo tocchi, detti, incolli.',
              style: TextStyle(fontSize: 15, height: 1.4, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ]),
        ),
      ]),
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

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: w, height: h),
      Radius.circular(math.min(w, h) / 2),
    );
    canvas.drawRRect(
      rect.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.95 * fade * breathe));
  }

  @override
  bool shouldRepaint(_PillPainter old) => old.t != t;
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, required this.done, required this.color});

  final int n;
  final String text;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? color : color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({super.key, required this.masked, required this.checking, required this.onUse});

  final String masked;
  final bool checking;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Tokens.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 16, color: Tokens.green),
          const SizedBox(width: 8),
          Text('Trovata negli appunti', style: t.bodyMedium?.copyWith(color: Tokens.green, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Text(masked, style: monoStyle(context, size: 16, color: context.tk.text)),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tokens.green),
          onPressed: checking ? null : onUse,
          child: checking
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Usa questa chiave'),
        ),
      ]),
    );
  }
}

/// Il contatore delle pagine dell'introduzione: sempre nello stesso punto, in fondo.
class PageCount extends StatelessWidget {
  const PageCount(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14, top: 6),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ),
      );
}

/// Prima pagina del primo avvio: cos'è e come si usa, in tre righe. Poi la chiave.
class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const PageCount('1 di 2'),
      body: ListView(padding: EdgeInsets.zero, children: [
        const _Hero(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Come funziona', style: display(context, size: 24)),
            const SizedBox(height: 18),
            const _How(
              icon: Icons.bubble_chart_rounded,
              color: Tokens.blue,
              title: 'Fai uscire Transcri',
              text: 'Dal bottone dell’app vola sul bordo dello schermo e resta lì, sopra tutto.',
            ),
            const _How(
              icon: Icons.mic_rounded,
              color: Tokens.violet,
              title: 'Toccala e parla',
              text: 'Da WhatsApp, dalle note, dalla mail: ovunque tu stia scrivendo.',
            ),
            const _How(
              icon: Icons.content_paste_rounded,
              color: Tokens.green,
              title: 'Incolla',
              text: 'Il testo è già negli appunti, anche ripulito da esitazioni e ripetizioni se vuoi.',
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: onNext, child: const Text('Avanti')),
          ]),
        ),
      ]),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 2),
            Text(text, style: t.bodyMedium?.copyWith(color: context.tk.muted)),
          ]),
        ),
      ]),
    );
  }
}
