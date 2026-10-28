import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

const _days = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
const _months = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

/// I colori di Transcri: quelli del telefono (Material You), gli stessi della parte nativa.
/// Arrivano col primo stato letto; fino ad allora due toni neutri.
var transcriColors = [const Color(0xFF8AA4FF), const Color(0xFFC3A6F0)];

String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Ieri';
  if (diff < 7) return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  if (d.year == now.year) return '${d.day} ${_months[d.month - 1]}';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// Copia: diventa una ✓ verde per un attimo.
class CopyButton extends StatefulWidget {
  const CopyButton({super.key, required this.text});

  final String text;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool done = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.selectionClick();
    setState(() => done = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => done = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      onPressed: _copy,
      tooltip: 'Copia',
      iconSize: 20,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done
            ? const Icon(Icons.check_rounded, key: ValueKey(1), size: 22, color: Tokens.green)
            : Icon(Icons.content_copy_rounded, key: const ValueKey(0), size: 20, color: context.tk.muted),
      ),
    );
  }
}

/// Cestino sicuro: un tocco lo arma (diventa rosso), un secondo tocco cancella.
/// Tenendolo premuto cancella subito, per chi deve fare pulizia in fretta.
class DeleteButton extends StatefulWidget {
  const DeleteButton({super.key, required this.onDelete, this.onHoldStart, this.onHoldEnd});

  final VoidCallback onDelete;

  /// Tenendo premuto: inizia e finisce la pressione (la scheda decide se è abbastanza).
  /// Se mancano, tenere premuto cancella subito.
  final VoidCallback? onHoldStart, onHoldEnd;

  @override
  State<DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<DeleteButton> {
  bool armed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _tap() {
    if (armed) return widget.onDelete();
    HapticFeedback.selectionClick();
    setState(() => armed = true);
    _disarm?.cancel();
    _disarm = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => armed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (armed) setState(() => armed = false);
      },
      child: Semantics(
        button: true,
        label: armed ? 'Tocca ancora per eliminare' : 'Elimina, tieni premuto per eliminare subito',
        child: GestureDetector(
          onTap: _tap,
          onLongPressStart: widget.onHoldStart == null ? null : (_) => widget.onHoldStart!(),
          onLongPressEnd: widget.onHoldEnd == null ? null : (_) => widget.onHoldEnd!(),
          onLongPress: widget.onHoldStart == null ? widget.onDelete : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            height: 40, // 40 × 40 come il tasto copia: le icone vicine hanno la stessa misura.
            constraints: const BoxConstraints(minWidth: 40),
            padding: EdgeInsets.symmetric(horizontal: armed ? 12 : 10),
            decoration: BoxDecoration(color: armed ? Tokens.red : Colors.transparent, borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(armed ? Icons.delete_rounded : Icons.delete_outline_rounded, size: 20, color: armed ? Colors.white : context.tk.faint),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: armed
                      ? const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            'Elimina',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quanto manca prima che la nota se ne vada davvero: un cerchio che si consuma.
class Countdown extends StatelessWidget {
  const Countdown(this.duration, {super.key});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).snackBarTheme.actionTextColor ?? Theme.of(context).colorScheme.inversePrimary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: duration,
      builder: (context, left, _) => SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(value: left, strokeWidth: 2.5, color: color, backgroundColor: color.withValues(alpha: 0.2)),
      ),
    );
  }
}

/// Quanto resta il messaggio "Annulla" dopo un'eliminazione.
const undoTime = Duration(seconds: 5);

/// Una cosa appena eliminata: il messaggio "Annulla" per qualche secondo, con il cerchio che si consuma.
/// Restituisce true se l'hai ripresa; altrimenti si può cancellare davvero.
Future<bool> undoable(BuildContext context, String label) async {
  HapticFeedback.mediumImpact();
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final reason = await messenger
      .showSnackBar(
        SnackBar(
          content: Row(children: [const Countdown(undoTime), const SizedBox(width: 14), Text(label)]),
          duration: undoTime,
          action: SnackBarAction(label: 'Annulla', onPressed: () {}),
        ),
      )
      .closed;
  if (reason != SnackBarClosedReason.action) return false;
  HapticFeedback.selectionClick();
  return true;
}

/// Il colore delle isole che galleggiano sopra la pagina (il Dock, la casa di Transcri):
/// bianco di giorno; di notte un tono sopra il grigio delle schede delle note, o si confondono.
Color islandColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF353533) : Colors.white;

/// L'ombra delle isole: una larga e morbida che le solleva, e una stretta che fa da bordo appena
/// accennato, così si staccano anche quando sotto passa una scheda. Niente linee vere.
const islandShadow = [
  BoxShadow(color: Color(0x17000000), blurRadius: 18, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x14000000), blurRadius: 1.5, spreadRadius: 0.5),
];

/// Le misure del Dock: ogni isola è alta [dockIsland] e dentro ogni cosa tonda è [dockRound],
/// col suo margine uguale tutto intorno. Così la matita, Transcri e il potere sembrano grandi uguali.
const dockIsland = 64.0, dockRound = 52.0;
