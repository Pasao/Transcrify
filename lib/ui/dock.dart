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

/// Il potere in cui sei, in basso a sinistra sotto il pollice. Tocchi e si apre la colonna
/// degli altri; scorri su o giù e passi al vicino, con un piccolo scatto.
class PowerButton extends StatefulWidget {
  const PowerButton({super.key, required this.power, required this.onTap, required this.onStep});

  final Power power;
  final VoidCallback onTap;
  final ValueChanged<int> onStep;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  double _drag = 0;

  /// Quanto bisogna scorrere per passare al vicino.
  static const _enough = 28.0;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onVerticalDragStart: (_) => _drag = 0,
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-_enough * 1.4, _enough * 1.4)),
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_drag.abs() >= _enough || v.abs() > 500) {
          HapticFeedback.lightImpact();
          // Su = il prossimo, come una ruota che gira verso l'alto.
          widget.onStep((_drag != 0 ? _drag : v) < 0 ? 1 : -1);
        }
        setState(() => _drag = 0);
      },
      child: AnimatedSlide(
        // Segue il dito per un pezzetto, poi torna al suo posto.
        offset: Offset(0, _drag / dockIsland * 0.35),
        duration: Duration(milliseconds: _drag == 0 ? 260 : 0),
        curve: Curves.easeOutBack,
        child: Container(
          width: dockIsland,
          height: dockIsland,
          decoration: BoxDecoration(color: islandColor(context), shape: BoxShape.circle, boxShadow: islandShadow),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Due trattini sopra: gli altri poteri stanno "dietro", si raggiungono scorrendo.
              Positioned(
                top: 7,
                child: Container(
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(color: tk.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: a,
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: PowerBadge(power: widget.power, key: ValueKey(widget.power)),
              ),
            ],
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
