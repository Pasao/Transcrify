import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../ds.dart';
import 'scheda_trascrizione.dart';

/// Una fila di schede che scorre di lato: un giorno di Trascrivi (anche in una cartella aperta). Le schede le fa chi la usa
/// ([scheda]): così hanno gli stessi gesti dappertutto (tocco apre, tenuta premuta sceglie).
class FilaSchede extends StatelessWidget {
  const FilaSchede({super.key, required this.chiave, required this.voci, required this.scheda});

  /// Il nome della fila: esce dallo schermo e torna, e le schede restano dove le avevi fatte scorrere.
  final String chiave;
  final List<Entry> voci;
  final Widget Function(Entry) scheda;

  /// Lo spazio tra due schede.
  static const tra = 10.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SchedaTrascrizione.alta,
    child: ListView.separated(
      key: PageStorageKey(chiave),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Spazio.s5),
      itemCount: voci.length,
      separatorBuilder: (_, _) => const SizedBox(width: tra),
      itemBuilder: (_, i) => scheda(voci[i]),
    ),
  );
}
