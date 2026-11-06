import 'dart:async';

import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/ricerca.dart';
import 'common.dart';
import 'molecole/campo_ricerca.dart';
import 'molecole/riga_trovata.dart';
import 'pensieri.dart';
import 'theme.dart';
import 'trascrizione_aperta.dart';

/// Apre la ricerca (la lente in cima, in Trascrivi e nelle Note: la stessa). Indietro o «Annulla» la chiudono.
Future<void> apriRicerca(BuildContext context) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    transitionDuration: Durata.normale,
    reverseTransitionDuration: Durata.normale,
    pageBuilder: (_, _, _) => const CercaPage(),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curva.standard), child: child),
  ),
);

/// La ricerca (6 nov, come One UI 8.5): il campo in fondo, sopra la tastiera che si apre da sola; sopra quello che ha
/// trovato il motore (prima le frasi con tutte le parole, poi quelle vicine per senso), note e
/// trascrizioni insieme, una riga per frase. Le private non si mostrano: la loro frase resterebbe scritta qui.
/// I filtri (6 nov, giro 6) non stanno più qui: sono sotto il titolo di Trascrivi e filtrano la lista che guardi.
class CercaPage extends StatefulWidget {
  const CercaPage({super.key});

  @override
  State<CercaPage> createState() => _CercaPageState();
}

class _CercaPageState extends State<CercaPage> {
  final _testo = TextEditingController();

  /// Quello che si sta cercando, e quello che ha trovato il motore: per parola subito, per senso quando è pronto
  /// (null finché non ha risposto).
  String _cercato = '';
  List<Trovato>? _perParola, _perSenso;

  /// Le note e le trascrizioni (non private), per mostrare le frasi trovate. Si leggono all'inizio e quando cambiano.
  Map<String, Note> _note = {};
  Map<String, Entry> _voci = {};

  /// Si cerca quando smetti di scrivere per un attimo, non a ogni lettera.
  Timer? _attesa;

  @override
  void initState() {
    super.initState();
    _testo.addListener(() {
      if (_testo.text == _cercato) return;
      _cercato = _testo.text;
      _attesa?.cancel();
      _attesa = Timer(Durata.veloce, _cerca);
    });
    // Aperta e cambiata una cosa trovata (o eliminata), i risultati si rifanno.
    Core.addListener(_cambiato);
    // Il modello per senso si carica adesso, mentre scrivi, e resta pronto finché la ricerca è aperta.
    Ricerca.aperta(true);
    _leggi();
  }

  @override
  void dispose() {
    Ricerca.aperta(false);
    Core.removeListener(_cambiato);
    _attesa?.cancel();
    _testo.dispose();
    super.dispose();
  }

  Future<void> _cambiato() async {
    await _leggi();
    await _cerca();
  }

  Future<void> _leggi() async {
    final note = await Core.notes();
    final voci = await Core.history();
    if (!mounted) return;
    setState(() {
      _note = {for (final n in note) n.id: n};
      _voci = {
        for (final e in voci)
          if (!e.privata) '${e.at.millisecondsSinceEpoch}': e,
      };
    });
  }

  /// Prima per parola (si vede subito), poi per senso: le righe per senso arrivano sotto, quando sono pronte.
  Future<void> _cerca() async {
    final q = _cercato;
    if (q.trim().isEmpty) return setState(() => _perParola = _perSenso = null);
    final parole = await Ricerca.cerca(q, senso: false);
    // Nel frattempo hai scritto altro: questa risposta è vecchia.
    if (!mounted || q != _cercato) return;
    setState(() {
      _perParola = parole;
      _perSenso = null;
    });
    final senso = await Ricerca.cerca(q, senso: true);
    if (!mounted || q != _cercato) return;
    setState(() => _perSenso = senso);
  }

  List<Widget> _righeDi(List<Trovato> t) => [
    for (final x in t) ?_riga(x.nota ? _note[x.id] : null, x.nota ? null : _voci[x.id], x.frase),
  ];

  /// Quello che ha trovato il motore: per parola, poi (sotto il titoletto) per senso. Null: non stai cercando niente,
  /// o il motore non ha ancora risposto.
  List<Widget>? get _righe {
    final parola = _perParola;
    if (_cercato.trim().isEmpty || parola == null) return null;
    final perParola = _righeDi(parola), perSenso = _righeDi(_perSenso ?? const []);
    // Niente per parola e il senso non ha ancora risposto: si aspetta, non si dice «niente».
    if (perParola.isEmpty && _perSenso == null) return null;
    return [
      ...perParola,
      if (perSenso.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(Spazio.s1, Spazio.s2, 0, Spazio.s2),
          child: EtichettaGruppo('Per significato'),
        ),
        ...perSenso,
      ],
    ];
  }

  /// Una riga: la frase trovata, e sotto da dove viene. Null se la cosa non c'è più.
  Widget? _riga(Note? nota, Entry? voce, TextRange frase) {
    final testo = nota?.text ?? voce?.text;
    if (testo == null || frase.end > testo.length) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spazio.s3),
      child: RigaTrovata(
        frase: frase.textInside(testo).trim(),
        cercato: _cercato,
        nota: nota != null,
        daDove: nota != null ? (nota.title.trim().isEmpty ? shortStamp(nota.updated) : nota.title.trim()) : 'Trascrizione · ${shortStamp(voce!.at)}',
        onApri: () => nota != null ? openNote(context, nota) : openEntry(context, voce!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final righe = _righe;
    return Paper(
      child: Scaffold(
        // Il campo sta sopra la tastiera.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: righe == null
                    ? const SizedBox.shrink()
                    : righe.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(Spazio.s5, Spazio.s10, Spazio.s5, 0),
                        child: Text(
                          'Niente con «${_cercato.trim()}».\nProva a dirlo con altre parole.',
                          style: Testo.testoGrande.copyWith(color: c.testoSecondario),
                        ),
                      )
                    : ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(Spazio.s4, Spazio.s2, Spazio.s4, Spazio.s2),
                        children: righe,
                      ),
              ),
              CampoRicerca(controller: _testo, onAnnulla: () => Navigator.of(context).maybePop()),
            ],
          ),
        ),
      ),
    );
  }
}
