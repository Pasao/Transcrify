import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/estratto.dart';
import '../core/native.dart';
import '../core/titoli.dart';
import 'atomi.dart';
import 'common.dart';
import 'ds.dart';
import 'molecole/risultato_estratto.dart';
import 'settings.dart';

/// Un testo da provare: una trascrizione o una nota, coi nomi per la lista.
typedef _Fonte = ({String titolo, String sotto, String testo});

/// Impostazioni → Prove → «Prova il riassunto estrattivo»: scegli una trascrizione o una nota, il motore sul
/// telefono sceglie le frasi che contano. Un laboratorio: SOLO lettura (non scrive niente, non usa la rete),
/// e nient'altro nell'app cambia.
class ProvaEstrattoPage extends StatefulWidget {
  const ProvaEstrattoPage({super.key});

  @override
  State<ProvaEstrattoPage> createState() => _ProvaEstrattoPageState();
}

class _ProvaEstrattoPageState extends State<ProvaEstrattoPage> {
  /// Quanto del testo si vede nella lista, per riconoscerlo.
  static const _anteprima = 90;

  List<_Fonte>? _trascrizioni, _note;
  _Fonte? _scelta;
  Future<Estratto>? _lavoro;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final storia = await Core.history();
    final note = await Core.notes();
    if (!mounted) return;
    setState(() {
      _trascrizioni = [
        for (final e in [...storia]..sort((a, b) => b.at.compareTo(a.at)))
          if (e.text.trim().isNotEmpty) (titolo: shortStamp(e.at), sotto: e.privata ? Titoli.di(e) : _inizio(e.text), testo: e.text),
      ];
      _note = [
        for (final n in note)
          if (n.text.trim().isNotEmpty) (titolo: n.title.isEmpty ? shortStamp(n.updated) : n.title, sotto: _inizio(n.text), testo: n.text),
      ];
    });
  }

  static String _inizio(String t) {
    final una = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return una.length <= _anteprima ? una : '${una.substring(0, _anteprima)}…';
  }

  void _prova(_Fonte f) => setState(() {
    _scelta = f;
    _lavoro = Estratto.di(f.testo);
  });

  Future<void> _scaricaModello() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TopicsSettings()));
    final f = _scelta;
    if (f != null && mounted) _prova(f);
  }

  @override
  Widget build(BuildContext context) {
    final f = _scelta;
    return SettingsPageFrame(title: 'Riassunto estrattivo', children: f == null ? _lista(context) : _risultato(context, f));
  }

  List<Widget> _lista(BuildContext context) {
    final c = context.col;
    final t = _trascrizioni, n = _note;
    if (t == null || n == null) return const [Center(child: CircularProgressIndicator())];
    SettingsGroup gruppo(String nome, List<_Fonte> fonti, IconData icona) => SettingsGroup(
      label: nome,
      children: [for (final f in fonti) SettingsRow(icon: icona, color: c.azione, title: f.titolo, subtitle: f.sotto, onTap: () => _prova(f))],
    );
    return [
      Text(
        'Scegli una trascrizione o una nota: il motore sul telefono sceglie le frasi che contano. Solo lettura: non cambia niente e non va in rete.',
        style: Testo.testo.copyWith(color: c.testoSecondario),
      ),
      const SizedBox(height: Spazio.s6),
      if (t.isEmpty && n.isEmpty) Text('Non ci sono ancora trascrizioni né note.', style: Testo.testo.copyWith(color: c.testo)),
      if (t.isNotEmpty) gruppo('Trascrizioni', t, Icons.graphic_eq_rounded),
      if (n.isNotEmpty) gruppo('Note', n, Icons.sticky_note_2_outlined),
    ];
  }

  List<Widget> _risultato(BuildContext context, _Fonte f) {
    final c = context.col;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Bottone('Scegli un altro testo', tipo: TipoBottone.testo, alto: false, icona: Icons.arrow_back_rounded, onPressed: () => setState(() => _scelta = null)),
      ),
      Text(f.titolo, style: Testo.titoloSezione.copyWith(color: c.testo)),
      const SizedBox(height: Spazio.s4),
      FutureBuilder<Estratto>(
        future: _lavoro,
        builder: (context, s) {
          final e = s.data;
          if (s.hasError) {
            return _errore(context, switch (s.error) {
              PlatformException(:final message, :final code) => message ?? code,
              final altro => '$altro',
            });
          }
          if (e == null) return const Center(child: CircularProgressIndicator());
          return switch (e.stato) {
            'pronto' => RisultatoEstratto(estratto: e, testo: f.testo),
            'senzaModello' => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Spazio.s4,
              children: [
                Text(
                  'Serve il modello degli argomenti, sul telefono: si scarica una volta, poi lavora senza rete. Scegline uno e torna qui.',
                  style: Testo.testo.copyWith(color: c.testo),
                ),
                Bottone('Scegli il modello', icona: Icons.download_rounded, onPressed: _scaricaModello),
              ],
            ),
            _ => _errore(context, e.errore ?? 'errore senza nome'),
          };
        },
      ),
    ];
  }

  /// Quando non va: il perché per intero (dal nativo, causa per causa), da leggere e da copiare per dirlo.
  static Widget _errore(BuildContext context, String perche) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Spazio.s2,
    children: [
      Text('Non è andata.', style: Testo.titoloScheda.copyWith(color: context.col.errore)),
      SelectableText(perche, style: Testo.testo.copyWith(color: context.col.testo)),
    ],
  );
}
