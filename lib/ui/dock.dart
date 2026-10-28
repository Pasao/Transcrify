import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'theme.dart';

/// I poteri di Transcri. Per ora due: Trascrivi (quello che detti per gli altri) e Pensieri (le tue note).
enum Power {
  trascrivi('Trascrivi', Icons.mic_rounded),
  pensieri('Pensieri', Icons.cloud_rounded);

  const Power(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Quello dopo (o prima), in giro: scorrendo sul tondo si passa al vicino.
  Power step(int by) => values[(index + by) % values.length];
}

/// Il Dock, in fondo a ogni pagina. Due lati, due compiti:
/// a sinistra dove sei (il potere, che cambi), a destra cosa crei (scrivi, e Transcri che detta).
class Dock extends StatelessWidget {
  const Dock({super.key, required this.power, required this.onSwitch, required this.onStep, required this.nest, this.onWrite});

  /// Quanto spazio prende, dal fondo: le pagine lasciano libero questo.
  static const height = dockIsland + 12;

  final Power power;

  /// Tocco sul potere: si apre la colonna degli altri.
  final VoidCallback onSwitch;

  /// Scorrendo su o giù sul potere: +1 il prossimo, -1 il precedente.
  final ValueChanged<int> onStep;

  /// La casa di Transcri.
  final Widget nest;

  /// Scrivere a mano, se il potere lo permette (in Pensieri sì).
  final VoidCallback? onWrite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PowerButton(power: power, onTap: onSwitch, onStep: onStep),
          const Spacer(),
          Island(
            padding: const EdgeInsets.all((dockIsland - dockRound) / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // In Pensieri la matita esce da Transcri: l'isola si allunga verso sinistra.
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: onWrite == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: (dockIsland - dockRound) / 2),
                          child: RoundAction(icon: Icons.edit_rounded, label: 'Scrivi', onTap: onWrite!),
                        ),
                ),
                nest,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un'isola: un pezzo che galleggia sopra la pagina, bianco, tondo, con l'ombra morbida.
class Island extends StatelessWidget {
  const Island({super.key, required this.child, this.padding = const EdgeInsets.all(6)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: islandColor(context), borderRadius: BorderRadius.circular(40), boxShadow: islandShadow),
      child: child,
    );
  }
}

/// Un'azione tonda dentro un'isola: un'icona su un fondo appena grigio.
class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.label, required this.onTap, this.size = dockRound});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Tooltip(
      message: label,
      child: Material(
        color: tk.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 22, color: tk.muted),
          ),
        ),
      ),
    );
  }
}

/// Il potere in cui sei, in basso a sinistra sotto il pollice: una ruota in una finestra tonda.
/// Tocchi e si apre la colonna degli altri; tiri su o giù e la ruota gira sul vicino.
class PowerButton extends StatefulWidget {
  const PowerButton({super.key, required this.power, required this.onTap, required this.onStep});

  final Power power;
  final VoidCallback onTap;
  final ValueChanged<int> onStep;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> with SingleTickerProviderStateMixin {
  /// Di quanto è girata la ruota, in punti: negativo verso l'alto.
  double _drag = 0;
  late final AnimationController _settle = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _drag = _settle.value));

  /// La distanza tra un potere e il vicino sulla ruota: abbastanza perché del vicino si veda solo un pezzetto.
  static const _gap = dockRound * 0.86;

  /// Quanto bisogna tirare per passare al vicino.
  static const _enough = 22.0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    var from = _drag;
    if (_drag.abs() >= _enough || v.abs() > 500) {
      // Tirando su sale il prossimo, come una ruota.
      final up = (_drag != 0 ? _drag : v) < 0;
      HapticFeedback.lightImpact();
      widget.onStep(up ? 1 : -1);
      // Il nuovo parte da dove stava il vicino, così la ruota continua senza salti.
      from = _drag + (up ? _gap : -_gap);
    }
    _settle.value = from;
    _settle.animateTo(0, duration: const Duration(milliseconds: 340), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.power;
    Widget at(Power power, double y, {bool on = false}) => Transform.translate(
      offset: Offset(0, y),
      child: Opacity(
        opacity: on ? 1 : 0.55,
        child: PowerBadge(power: power, on: on),
      ),
    );
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onVerticalDragStart: (_) => _settle.stop(),
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-_gap, _gap)),
      onVerticalDragEnd: _end,
      child: Container(
        width: dockIsland,
        height: dockIsland,
        decoration: BoxDecoration(color: islandColor(context), shape: BoxShape.circle, boxShadow: islandShadow),
        // Una ruota vista da una finestra tonda: sopra e sotto spunta un pezzetto dei vicini,
        // ed è quello che dice che si può girare.
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [at(p.step(-1), -_gap + _drag), at(p.step(1), _gap + _drag), at(p, _drag, on: true)],
          ),
        ),
      ),
    );
  }
}

/// L'icona di un potere su un tondo del colore del telefono: acceso se è quello in cui sei.
class PowerBadge extends StatelessWidget {
  const PowerBadge({super.key, required this.power, this.on = true, this.size = dockRound});

  final Power power;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Tokens.blue.withValues(alpha: 0.16) : tk.surface),
      child: Icon(power.icon, size: size * 0.46, color: on ? Tokens.blue : tk.muted),
    );
  }
}

/// La colonna dei poteri, che sale dal tondo in basso a sinistra: sotto il pollice, niente da raggiungere in alto.
class PowerColumn extends StatelessWidget {
  const PowerColumn({super.key, required this.current, required this.onPick});

  final Power current;
  final ValueChanged<Power> onPick;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Island(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dall'alto in basso; quello in cui sei è l'ultimo, vicino al dito.
          for (final p in [...Power.values.where((p) => p != current), current])
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                HapticFeedback.selectionClick();
                onPick(p);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 18, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PowerBadge(power: p, on: p == current),
                    const SizedBox(width: 12),
                    Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: p == current ? FontWeight.w600 : FontWeight.w500,
                        color: p == current ? Tokens.blue : tk.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
