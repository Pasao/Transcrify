import 'package:flutter/material.dart';

import '../core/native.dart';
import 'common.dart';
import 'onboarding.dart';
import 'settings.dart';
import 'theme.dart';

/// Quello che non va, o che aspetta: un posto solo, in alto accanto alle impostazioni.
/// Ogni cosa dice cosa è successo e cosa puoi fare.
class Status {
  const Status({required this.limitedUntil, required this.waiting, required this.hasKey});

  /// I minuti di Groq sono finiti: quando tornano.
  final DateTime? limitedUntil;

  /// Registrazioni salvate che aspettano di essere trascritte.
  final int waiting;
  final bool hasKey;

  bool get any => limitedUntil != null || waiting > 0 || !hasKey;

  /// La scritta corta del bottone: la cosa sola, o quante sono.
  String get short {
    final n = (limitedUntil != null ? 1 : 0) + (waiting > 0 ? 1 : 0) + (hasKey ? 0 : 1);
    if (n > 1) return '$n avvisi';
    if (!hasKey) return 'Manca la chiave';
    if (limitedUntil != null) return 'Minuti finiti';
    return '$waiting in attesa';
  }

  /// Rosso se Transcri non può lavorare; giallo se qualcosa aspetta e basta.
  bool get blocking => limitedUntil != null || !hasKey;
}

/// Il bottone degli avvisi nell'intestazione: c'è solo quando c'è qualcosa.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.onTap});

  final Status status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = status.blocking ? Tokens.red : const Color(0xFFB7860B);
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.blocking ? Icons.error_outline_rounded : Icons.schedule_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                status.short,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apre il foglio degli avvisi.
Future<void> showStatus(BuildContext context) =>
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const StatusSheet());

/// Il foglio degli avvisi: una scheda per ogni cosa, e cosa puoi fare. Si aggiorna da solo.
class StatusSheet extends StatefulWidget {
  const StatusSheet({super.key});

  @override
  State<StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<StatusSheet> {
  CoreState? st;
  List<Waiting> waiting = [];
  bool flushing = false;

  @override
  void initState() {
    super.initState();
    Core.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    Core.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = await Core.state();
    final w = await Core.waiting();
    if (mounted) {
      setState(() {
        st = s;
        waiting = w;
      });
    }
  }

  /// "Riprova ora": trascrive quello che è rimasto indietro.
  Future<void> _flush() async {
    if (waiting.isEmpty || flushing) return;
    setState(() => flushing = true);
    await Core.flushWaiting();
    if (!mounted) return;
    setState(() => flushing = false);
    Core.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    if (s == null) return const SizedBox(height: 120);
    final until = s.limited == null ? null : s.resetAt;
    final cards = <Widget>[
      if (!s.hasKey)
        _Card(
          color: Tokens.red,
          icon: Icons.key_rounded,
          title: 'Manca la chiave Groq',
          text: 'Transcri trascrive con Groq. La chiave è gratis e si prende in due minuti.',
          action: FilledButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => KeyPage(onSaved: () => Navigator.of(ctx).pop(), onClose: () => Navigator.of(ctx).pop()),
                ),
              );
              Core.refresh();
            },
            child: const Text('Prendi la chiave'),
          ),
        ),
      if (until != null)
        _Card(
          color: Tokens.red,
          icon: Icons.hourglass_bottom_rounded,
          title: s.limited == 'daily' ? 'Minuti di oggi finiti' : "Minuti di quest'ora finiti",
          text:
              'Groq ti dà un tot di minuti di parlato. Transcri dorme e torna ${_when(until)}. Quello che hai già registrato non si perde.',
          action: OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsagePage())),
            child: const Text("Vedi l'utilizzo"),
          ),
        ),
      if (waiting.isNotEmpty)
        _Card(
          color: const Color(0xFFB7860B),
          icon: Icons.cloud_off_rounded,
          title: waiting.length == 1 ? 'Una registrazione in attesa' : '${waiting.length} registrazioni in attesa',
          text: 'Non sono riuscite a partire, di solito per la rete. Sono salvate: riprova quando ce l\'hai.',
          action: flushing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton(onPressed: _flush, child: const Text('Riprova ora')),
          below: Column(
            children: [
              for (final w in waiting)
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 18, color: tk.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${dayLabel(w.at)}, ${hm(w.at)} · ${_duration(w.seconds)}', style: t.bodyMedium)),
                    DeleteButton(
                      onDelete: () async {
                        await Core.discardWaiting(w.id);
                        Core.refresh();
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.isEmpty
              ? [Text('Tutto a posto.', style: display(context, size: 22)), const SizedBox(height: 40)]
              : [
                  for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(height: 12), cards[i]],
                ],
        ),
      ),
    );
  }

  static String _duration(int s) => s < 60 ? '$s s' : '${s ~/ 60} min ${s % 60 > 0 ? '${s % 60} s' : ''}'.trim();

  /// "alle 14:05", "domani alle 09:12".
  static String _when(DateTime d) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return d.isBefore(tomorrow) ? 'alle ${hm(d)}' : 'domani alle ${hm(d)}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.color, required this.icon, required this.title, required this.text, required this.action, this.below});

  final Color color;
  final IconData icon;
  final String title, text;
  final Widget action;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: t.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: t.bodyMedium?.copyWith(color: context.tk.muted)),
          if (below != null) ...[const SizedBox(height: 8), below!],
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: action),
        ],
      ),
    );
  }
}
