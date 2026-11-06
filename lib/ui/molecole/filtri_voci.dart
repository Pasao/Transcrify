import 'package:flutter/material.dart';

import '../../core/filtro_voci.dart';
import '../../core/segni.dart';
import '../atomi.dart';
import '../ds.dart';
import 'isola.dart';

/// Un filtro da mostrare: il suo nome, il puntino (i colori), se è acceso, e cosa fa toccarlo.
typedef VoceFiltro = ({String nome, Color? punto, bool acceso, VoidCallback onTap});

/// Le tre file dei filtri di Trascrivi (6 nov, giro 7), col loro nome: da dove, come, il colore. Solo i filtri che
/// servono ([FiltriPossibili]); una fila senza filtri non c'è. Le usano il pannello e i filtri accesi sotto il titolo.
List<(String, List<VoceFiltro>)> righeFiltri(
  BuildContext context, {
  required FiltroVoci filtro,
  required FiltriPossibili possibili,
  required ValueChanged<FiltroVoci> onFiltro,
  required String Function(Colore) nome,
}) => [
  for (final riga in <(String, List<VoceFiltro>)>[
    ('Da dove', [
      for (final f in possibili.fonti) (nome: f.nome, punto: null, acceso: filtro.fonti.contains(f), onTap: () => onFiltro(filtro.conFonte(f))),
    ]),
    ('Come', [
      for (final m in possibili.modi) (nome: nomiModi[m]!, punto: null, acceso: filtro.modi.contains(m), onTap: () => onFiltro(filtro.conModo(m))),
    ]),
    ('Colore', [
      for (final k in possibili.colori)
        (nome: nome(k), punto: PuntoColore.di(context, k), acceso: filtro.colori.contains(k), onTap: () => onFiltro(filtro.conColore(k))),
    ]),
  ])
    if (riga.$2.isNotEmpty) riga,
];

/// Il pannello dei filtri, aperto dal tasto «Filtri»: le tre file una sotto l'altra, ognuna col suo nome. Dentro una
/// fila se ne accendono quanti vuoi (basta uno); tra le file valgono insieme. Si aggiorna mentre tocchi.
class PannelloFiltri extends StatelessWidget {
  const PannelloFiltri({super.key, required this.righe});

  final List<(String, List<VoceFiltro>)> righe;

  @override
  Widget build(BuildContext context) => Isola(
    raggio: BorderRadius.circular(Raggio.gruppo),
    padding: const EdgeInsets.all(Spazio.s4),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spazio.s3,
      children: [
        for (final (nome, voci) in righe)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Spazio.s1,
            children: [
              EtichettaGruppo(nome),
              Wrap(
                spacing: Spazio.s2,
                children: [for (final v in voci) ChipFiltro(v.nome, punto: v.punto, acceso: v.acceso, onTap: v.onTap)],
              ),
            ],
          ),
      ],
      ),
    ),
  );
}

/// Sotto il titolo di Trascrivi, solo i filtri accesi (6 nov, giro 7: «sempre a sinistra, così restano in vista»):
/// allineati a sinistra, ognuno con la × per spegnerlo, nell'ordine delle file; se non ci stanno vanno a capo (si
/// vedono tutti, sempre). Nessuno acceso: niente.
class FiltriAccesi extends StatelessWidget {
  const FiltriAccesi({super.key, required this.righe});

  final List<(String, List<VoceFiltro>)> righe;

  @override
  Widget build(BuildContext context) {
    final accesi = [
      for (final (nome, voci) in righe)
        for (final v in voci)
          if (v.acceso) (nome, v),
    ];
    if (accesi.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spazio.s5, 0, Spazio.s3, 0),
      child: Wrap(
        spacing: Spazio.s2,
        children: [
          for (final (riga, v) in accesi)
            Semantics(
              label: riga,
              child: ChipFiltro(v.nome, punto: v.punto, acceso: true, togli: true, onTap: v.onTap),
            ),
        ],
      ),
    );
  }
}
