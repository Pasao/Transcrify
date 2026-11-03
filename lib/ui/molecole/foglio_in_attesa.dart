import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../common.dart';
import '../ds.dart';

/// Si apre toccando la riga delle registrazioni in attesa: una per riga (giorno, ora, durata;
/// non hanno ancora parole, non sono trascritte), ognuna col suo cestino, e in fondo «Riprova tutte».
Future<void> apriInAttesa(BuildContext context, {required VoidCallback onRiprova}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _FoglioInAttesa(onRiprova: onRiprova),
);

class _FoglioInAttesa extends StatefulWidget {
  const _FoglioInAttesa({required this.onRiprova});

  final VoidCallback onRiprova;

  @override
  State<_FoglioInAttesa> createState() => _FoglioInAttesaState();
}

class _FoglioInAttesaState extends State<_FoglioInAttesa> {
  List<Waiting>? _attesa;

  @override
  void initState() {
    super.initState();
    Core.addListener(_carica);
    _carica();
  }

  @override
  void dispose() {
    Core.removeListener(_carica);
    super.dispose();
  }

  Future<void> _carica() async {
    final w = await Core.waiting();
    if (!mounted) return;
    if (w.isEmpty) return Navigator.of(context).pop();
    setState(() => _attesa = w);
  }

  static String _durata(int s) => s < 60 ? '$s s' : '${s ~/ 60} min${s % 60 > 0 ? ' ${s % 60} s' : ''}';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final attesa = _attesa;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s5, 0, Spazio.s5, Spazio.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Spazio.s3,
          children: [
            Text('In attesa di rete', style: Testo.titoloSezione.copyWith(color: c.testo)),
            Text('Sono salvate: partono quando torna la rete, o adesso con «Riprova tutte».', style: Testo.testo.copyWith(color: c.testoSecondario)),
            if (attesa == null)
              const SizedBox(height: Misura.tocco)
            else
              for (final w in attesa)
                Row(
                  spacing: Spazio.s3,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: Misura.iconaMedia, color: c.testoSecondario),
                    Expanded(
                      child: Text('${dayLabel(w.at)}, ${hm(w.at)} · ${_durata(w.seconds)}', style: Testo.testo.copyWith(color: c.testo)),
                    ),
                    DeleteButton(
                      onDelete: () async {
                        await Core.discardWaiting(w.id);
                        Core.refresh();
                      },
                    ),
                  ],
                ),
            Bottone('Riprova tutte', onPressed: widget.onRiprova),
          ],
        ),
      ),
    );
  }
}
