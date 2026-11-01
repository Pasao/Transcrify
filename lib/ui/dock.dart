import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'theme.dart';

/// I poteri di Transcri. Per ora due: Trascrivi (quello che detti per gli altri) e Pensieri (le tue note).
enum Power {
  // Il microfono è il tasto per dettare, qui accanto a Transcri: il potere ha il suo segno, l'onda della voce.
  trascrivi('Trascrivi', Icons.graphic_eq_rounded),
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
  const Dock({
    super.key,
    required this.power,
    required this.onSwitch,
    required this.onStep,
    required this.nest,
    this.action,
    this.pages = const [],
    this.page = 0,
    this.onPage,
  });

  /// Quanto spazio prende, dal fondo: le pagine lasciano libero questo.
  static const height = dockIsland + 12;

  final Power power;

  /// Tocco sul potere: si apre la colonna degli altri.
  final VoidCallback onSwitch;

  /// Scorrendo su o giù sul potere: +1 il prossimo, -1 il precedente.
  final ValueChanged<int> onStep;

  /// La casa di Transcri.
  final Widget nest;

  /// L'azione accanto a Transcri: scrivere in Pensieri, dettare in Trascrivi, buttare mentre ascolta.
  final (IconData, String, VoidCallback)? action;

  /// Le pagine del potere (in Pensieri: Note e Argomenti), in mezzo. Vuote se il potere ne ha una sola.
  final List<(IconData, String)> pages;
  final int page;
  final ValueChanged<int>? onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Il potere e le sue pagine sono un pezzo solo: si capisce che le pagine sono sue,
          // e il potere si tira su lo stesso per cambiarlo. Cambiando potere le pagine rientrano ed escono.
          Container(
            height: dockIsland,
            decoration: BoxDecoration(
              color: islandColor(context),
              borderRadius: BorderRadius.circular(dockIsland / 2),
              boxShadow: islandShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PowerButton(power: power, onTap: onSwitch, onStep: onStep),
                _Retract(
                  id: pages.length > 1 ? pages.map((p) => p.$2).join() : null,
                  from: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(right: (dockIsland - dockRound) / 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          Tooltip(
                            message: pages[i].$2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onPage?.call(i);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: dockRound - 4,
                                height: dockRound - 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == page ? Tokens.blue.withValues(alpha: 0.16) : Colors.transparent,
                                ),
                                child: Icon(pages[i].$1, size: 22, color: i == page ? Tokens.blue : context.tk.muted),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Island(
            padding: const EdgeInsets.all((dockIsland - dockRound) / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // L'azione esce da Transcri: l'isola si allunga verso sinistra.
                _Retract(
                  id: action?.$1,
                  from: Alignment.centerRight,
                  child: action == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: (dockIsland - dockRound) / 2),
                          child: RoundAction(icon: action!.$1, label: action!.$2, onTap: action!.$3),
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

/// Un pezzo del Dock che dipende dal potere: se cambia prima rientra da dov'è uscito, poi esce quello
/// nuovo; mai un cambio sul posto. [id] dice cos'è: null = non c'è niente. [from]: il lato da cui esce.
class _Retract extends StatefulWidget {
  const _Retract({required this.id, required this.from, required this.child});

  final Object? id;
  final Alignment from;
  final Widget child;

  @override
  State<_Retract> createState() => _RetractState();
}

class _RetractState extends State<_Retract> with SingleTickerProviderStateMixin {
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: widget.id == null ? 0 : 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _swap();
    });

  /// Quello che si vede: mentre rientra resta il vecchio.
  late Object? _shownId = widget.id;
  late Widget _shown = widget.child;

  void _swap() {
    setState(() {
      _shownId = widget.id;
      _shown = widget.child;
    });
    if (_shownId != null) _open.forward();
  }

  @override
  void didUpdateWidget(covariant _Retract old) {
    super.didUpdateWidget(old);
    if (widget.id == _shownId) {
      _shown = widget.child;
      if (_shownId != null) _open.forward();
    } else if (_open.isDismissed) {
      _swap();
    } else {
      _open.reverse();
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = CurvedAnimation(parent: _open, curve: Curves.easeInOutCubic);
    return ClipRect(
      child: AnimatedBuilder(
        animation: v,
        builder: (context, child) => Align(
          alignment: widget.from,
          widthFactor: v.value,
          child: Opacity(opacity: v.value, child: child),
        ),
        child: _shown,
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

/// Il potere in cui sei, in basso a sinistra sotto il pollice, davanti a un piccolo mazzo.
/// Tocchi e si apre la colonna degli altri; lo tiri su (o giù) e passi al vicino.
class PowerButton extends StatefulWidget {
  const PowerButton({super.key, required this.power, required this.onTap, required this.onStep});

  final Power power;
  final VoidCallback onTap;
  final ValueChanged<int> onStep;

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  /// Quanto l'hai tirato, in punti: negativo verso l'alto.
  double _drag = 0;

  /// Quanto bisogna tirare per passare al vicino.
  static const _enough = 28.0;

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_drag.abs() >= _enough || v.abs() > 500) {
      HapticFeedback.lightImpact();
      // Tirando su arriva il prossimo, quello che spuntava da dietro.
      widget.onStep((_drag != 0 ? _drag : v) < 0 ? 1 : -1);
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    // 0 a riposo, 1 quando l'hai tirato su abbastanza.
    final pull = (-_drag / _enough).clamp(0.0, 1.0);
    final settle = Duration(milliseconds: _drag == 0 ? 260 : 0);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onVerticalDragStart: (_) => _drag = 0,
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-_enough * 1.4, _enough * 1.4)),
      onVerticalDragEnd: _end,
      child: SizedBox(
        width: dockIsland,
        height: dockIsland,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Dietro, un mazzo: il prossimo potere spunta appena sopra. Tirando su si alza e si accende.
            AnimatedPositioned(
              duration: settle,
              curve: Curves.easeOutBack,
              top: -10 - 12 * pull,
              child: AnimatedScale(
                duration: settle,
                scale: 0.82 + 0.1 * pull,
                child: Container(
                  width: dockIsland,
                  height: dockIsland,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: islandColor(context), shape: BoxShape.circle, boxShadow: islandShadow),
                  child: Opacity(
                    opacity: 0.35 + 0.65 * pull,
                    child: PowerBadge(power: widget.power.step(1), on: false),
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              // Il tondo davanti segue il dito per un pezzetto, poi torna al suo posto.
              offset: Offset(0, _drag / dockIsland * 0.35),
              duration: settle,
              curve: Curves.easeOutBack,
              child: Container(
                width: dockIsland,
                height: dockIsland,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: islandColor(context), shape: BoxShape.circle),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(
                    scale: a,
                    child: FadeTransition(opacity: a, child: c),
                  ),
                  child: PowerBadge(power: widget.power, key: ValueKey(widget.power)),
                ),
              ),
            ),
          ],
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
