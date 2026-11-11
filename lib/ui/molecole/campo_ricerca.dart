import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';
import 'isola.dart';

/// Il campo della ricerca, in fondo sopra la tastiera (6 nov, come One UI 8.5): un'isola come quelle del Dock, con la
/// lente, il testo e la X che lo svuota; accanto «Annulla», che esce dalla ricerca. Si apre già pronto a scrivere.
class CampoRicerca extends StatelessWidget {
  const CampoRicerca({super.key, required this.controller, required this.onAnnulla, this.onCerca, this.suggerimento = 'Cerca quello che ricordi'});

  final TextEditingController controller;
  final VoidCallback onAnnulla;

  /// Il tasto «cerca» della tastiera: quello scritto.
  final ValueChanged<String>? onCerca;
  final String suggerimento;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return BarraInFondo(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s3, Spazio.s2, Spazio.s2, Spazio.s3),
        child: Row(
          spacing: Spazio.s1,
          children: [
            Expanded(
              child: Isola(
                padding: Isola.bordo(tondoDopo: true),
                child: SizedBox(
                  height: Misura.tondo,
                  child: Row(
                    spacing: Spazio.s2,
                    children: [
                      Icon(Icons.search_rounded, size: Misura.iconaGrande, color: c.testoSecondario),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: onCerca,
                          style: Testo.testo.copyWith(color: c.testo),
                          decoration: CampoNudo.decorazione.copyWith(hintText: suggerimento),
                        ),
                      ),
                      // La X solo quando c'è qualcosa da cancellare.
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => controller.text.isEmpty
                            ? const SizedBox.shrink()
                            : BottoneIcona(Icons.close_rounded, etichetta: 'Cancella', misura: Misura.tondo, onTap: controller.clear),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(onPressed: onAnnulla, child: const Text('Annulla')),
          ],
        ),
      ),
    );
  }
}
