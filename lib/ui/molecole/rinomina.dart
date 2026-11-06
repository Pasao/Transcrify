import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../atomi.dart';
import '../ds.dart';

/// «Rinomina» una cartella (6 nov, come nei dialoghi di Samsung): il titolo, il campo già pronto per scrivere (vuoto,
/// col nome di adesso, [attuale], come suggerimento) e in fondo «Annulla» a sinistra e «Rinomina» a destra. «Rinomina»
/// si accende solo con un nome nuovo. Il nome è del colore, salvato nel nativo (`Segni.nomina`).
/// Torna true se l'ha rinominata.
Future<bool> apriRinomina(BuildContext context, {required Colore colore, required String attuale}) async =>
    await showDialog<bool>(context: context, builder: (_) => _Rinomina(colore: colore, attuale: attuale)) ?? false;

class _Rinomina extends StatefulWidget {
  const _Rinomina({required this.colore, required this.attuale});

  final Colore colore;
  final String attuale;

  @override
  State<_Rinomina> createState() => _RinominaState();
}

class _RinominaState extends State<_Rinomina> {
  final _nome = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  bool get _nuovo {
    final n = _nome.text.trim();
    return n.isNotEmpty && n != widget.attuale;
  }

  void _rinomina() {
    if (!_nuovo) return;
    Segni.nomina(widget.colore, _nome.text);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Dialog(
      backgroundColor: c.isola,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raggio.foglio)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spazio.s6, Spazio.s6, Spazio.s6, Spazio.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rinomina', style: Testo.titoloSezione.copyWith(color: c.testo)),
            const SizedBox(height: Spazio.s4),
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _rinomina(),
              decoration: InputDecoration(hintText: widget.attuale),
            ),
            const SizedBox(height: Spazio.s3),
            Row(
              children: [
                Expanded(child: Bottone('Annulla', tipo: TipoBottone.testo, alto: false, onPressed: () => Navigator.pop(context, false))),
                Expanded(child: Bottone('Rinomina', tipo: TipoBottone.testo, alto: false, onPressed: _nuovo ? _rinomina : null)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
