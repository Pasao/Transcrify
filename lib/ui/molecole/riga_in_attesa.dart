import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Sotto il titolo, quando ci sono registrazioni che aspettano la rete: lo dice (non è un bottone
/// da toccare per sapere) e accanto c'è «Riprova». Mentre riprova, al posto del bottone gira un cerchio.
/// Toccando la frase si apre l'elenco ([onApri]), per buttarne qualcuna.
class RigaInAttesa extends StatelessWidget {
  const RigaInAttesa({super.key, required this.quante, required this.riprovando, required this.onRiprova, required this.onApri});

  final int quante;
  final bool riprovando;
  final VoidCallback onRiprova, onApri;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final frase = quante == 1 ? '1 registrazione in attesa di rete' : '$quante registrazioni in attesa di rete';
    return Row(
      spacing: Spazio.s2,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(Raggio.piccolo),
            onTap: onApri,
            child: Row(
              spacing: Spazio.s2,
              children: [
                Icon(Icons.schedule_rounded, size: Misura.iconaPiccola, color: c.attenzione),
                Flexible(
                  child: Text(
                    frase,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Testo.etichetta.copyWith(color: c.testoSecondario),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: Misura.iconaPiccola, color: c.testoSecondario),
              ],
            ),
          ),
        ),
        SizedBox(
          height: Misura.bottoneBasso,
          child: Center(
            child: riprovando
                ? SizedBox.square(
                    dimension: Misura.iconaMedia,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.azione),
                  )
                : Bottone('Riprova', tipo: TipoBottone.testo, alto: false, onPressed: onRiprova),
          ),
        ),
      ],
    );
  }
}

/// Con l'intestazione ridotta: solo «⏱ 2» accanto al titolo.
class InAttesaCorto extends StatelessWidget {
  const InAttesaCorto({super.key, required this.quante});

  final int quante;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Spazio.s1,
      children: [
        Icon(Icons.schedule_rounded, size: Misura.iconaPiccola, color: c.attenzione),
        Text('$quante', style: Testo.orario.copyWith(color: c.attenzione)),
      ],
    );
  }
}
