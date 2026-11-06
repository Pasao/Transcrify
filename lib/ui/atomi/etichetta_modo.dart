import 'package:flutter/material.dart';

import '../../core/filtro_voci.dart';
import '../mode_icon.dart';
import '../theme.dart';

/// Con che modo è stata pulita la trascrizione: l'icona, e nella trascrizione aperta anche il nome.
class EtichettaModo extends StatelessWidget {
  const EtichettaModo(this.modo, {super.key, this.nome = false});

  final String modo;
  final bool nome;

  @override
  Widget build(BuildContext context) {
    final colore = context.col.testoSecondario;
    final icona = CustomPaint(size: const Size(16, 13), painter: ModeIcon(modo, colore));
    if (!nome) return Tooltip(message: nomiModi[modo] ?? modo, child: icona);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icona,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            nomiModi[modo] ?? modo,
            style: orarioStyle(context, size: 12, color: colore),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
