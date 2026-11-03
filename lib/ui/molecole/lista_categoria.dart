import 'package:flutter/material.dart';

import '../ds.dart';

/// Una categoria come lista (la sua idea del 3 nov): il nome, quante frasi, e le frasi chiave
/// una sotto l'altra, già riassunte. Toccandone una si apre la nota da cui viene.
/// Di base se ne vedono [prime]; «Tutte» mostra le altre.
class ListaCategoria extends StatefulWidget {
  const ListaCategoria({super.key, required this.nome, required this.frasi, required this.onApri, this.prime = 4});

  final String nome;
  final List<String> frasi;
  final ValueChanged<int> onApri;
  final int prime;

  @override
  State<ListaCategoria> createState() => _ListaCategoriaState();
}

class _ListaCategoriaState extends State<ListaCategoria> {
  bool _tutte = false;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final quante = _tutte ? widget.frasi.length : widget.frasi.length.clamp(0, widget.prime);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: Spazio.s2,
          children: [
            Flexible(child: Text(widget.nome, style: Testo.titoloSezione.copyWith(color: c.testo), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${widget.frasi.length}', style: Testo.orario.copyWith(color: c.testoSecondario)),
          ],
        ),
        const SizedBox(height: Spazio.s2),
        for (var i = 0; i < quante; i++)
          InkWell(
            onTap: () => widget.onApri(i),
            borderRadius: BorderRadius.circular(Raggio.campo),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spazio.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Spazio.s3,
                children: [
                  Text('•', style: Testo.testo.copyWith(color: c.azione, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(widget.frasi[i], style: Testo.testo.copyWith(color: c.testo), maxLines: 3, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        if (widget.frasi.length > widget.prime)
          TextButton(onPressed: () => setState(() => _tutte = !_tutte), child: Text(_tutte ? 'Meno' : 'Tutte')),
      ],
    );
  }
}
