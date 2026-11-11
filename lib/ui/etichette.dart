import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import '../core/regole_colori.dart';
import 'common.dart';
import 'ds.dart';
import 'atomi.dart';
import 'molecole/proposte_etichette.dart';
import 'molecole/riga_etichetta.dart';
import 'molecole/togli_etichetta.dart';
import 'settings.dart';

/// Impostazioni → Etichette (10 nov, sua richiesta: nella rosa «troppa roba», lì restano colore e nome). I colori che
/// hanno un nome o delle trascrizioni, i più usati prima: per ognuno la regola per «Colora da sola» e «Offusca
/// sempre». Accenderlo copre anche quelle che l'etichetta ha già: la pillola «Offuscate N trascrizioni · Annulla» le
/// rimette esattamente com'erano (solo quelle che erano in vista) e spegne l'interruttore; spegnerlo le rimette tutte
/// in vista.
/// 10 nov: in cima una riga dice che le etichette sono i colori della rosa; ognuna si toglie dal suo cestino
/// ([apriTogliEtichetta]); «Proponi etichette» chiede a Groq (solo i titoli) da 4 a 8 etichette, che prendono i colori
/// liberi della rosa più distinti ([Tinte.lontane]), senza doppiare quelle che hai. «Proponi regole» (10 nov) chiede
/// a Groq, sempre dai soli titoli, una regola migliore per ogni etichetta che hai: le scegli nella stessa anteprima.
class EtichettePage extends StatefulWidget {
  const EtichettePage({super.key});

  @override
  State<EtichettePage> createState() => _EtichettePageState();
}

class _EtichettePageState extends State<EtichettePage> {
  List<Entry> _voci = const [];

  /// «Proponi etichette» o «Proponi regole»: quale sta aspettando Groq; e il suo errore, se non è andata.
  String? _propone;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _leggi();
  }

  Future<void> _leggi() async {
    final (voci, _, _) = await (Core.history(), Segni.leggiNomi(), RegoleColori.leggi()).wait;
    if (mounted) setState(() => _voci = voci);
  }

  /// I colori da mostrare: con un nome o in uso, i più usati prima.
  List<(Colore, int)> _etichette() {
    final usi = Segni.usi(_voci);
    final colori = {...usi.keys, for (final k in Segni.nomi.value.keys) ?Colore.da(k)};
    return [for (final c in colori) (c, usi[c] ?? 0)]..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// «Offusca sempre» vale per tutte quelle dell'etichetta (10 nov): acceso le copre, di prima e nuove; spento le
  /// rimette tutte in vista (lo fa il nativo, `salvaRegola`).
  Future<void> _cambia(Colore colore, String regola, bool offusca) async {
    final prima = RegoleColori.di(colore)?.offuscaSempre ?? false;
    // Quelle già coperte prima di accenderlo: con «Annulla» restano coperte, le altre tornano in vista.
    final coperte = [
      for (final e in _voci)
        if (e.colore == colore && e.privata) e.at,
    ];
    final n = await RegoleColori.salva(colore, regola, offusca);
    if (!mounted) return;
    if (n > 0 || offusca != prima) Core.refresh();
    if (n == 0 || prima) return _leggi();
    if (!await undoable(context, n == 1 ? 'Offuscata 1 trascrizione' : 'Offuscate $n trascrizioni')) return _leggi();
    await RegoleColori.salva(colore, regola, false);
    if (coperte.isNotEmpty) await Segni.rendiPrivate(coperte, true);
    Core.refresh();
    await _leggi();
  }

  /// Toglie l'etichetta: nome, regola e «Offusca sempre»; il colore dalle trascrizioni solo se l'hai scelto.
  Future<void> _togli(Colore colore, String nome, int quante) async {
    final colore_ = await apriTogliEtichetta(context, nome: nome, quante: quante);
    if (colore_ == null) return;
    await RegoleColori.salva(colore, '', false);
    await Segni.nomina(colore, '');
    if (colore_) {
      await Segni.colora([
        for (final e in _voci)
          if (e.colore == colore) e.at,
      ], null);
    }
    Core.refresh();
    await _leggi();
  }

  /// Le proposte di Groq, ognuna col suo colore libero; quelle confermate prendono regola e nome (prima la regola: il
  /// nativo non ne chiede un'altra).
  Future<void> _proponi() => _chiediGroq(_etichetteNuove, () async {
    final proposte = await RegoleColori.proponi();
    final tinte = Tinte.lontane({for (final (c, _) in _etichette()) c.tinta}, proposte.length);
    final coppie = [for (final (i, t) in tinte.indexed) (proposte[i], Colore(t, Tinte.luceViva(t)))];
    if (!mounted) return;
    if (coppie.isEmpty) return setState(() => _errore = 'Nessuna etichetta nuova da proporre.');
    final scelte = await apriProposte(context, coppie) ?? const [];
    for (final (proposta, colore) in scelte) {
      await RegoleColori.salva(colore, proposta.regola, false);
      await Segni.nomina(colore, proposta.nome);
    }
    if (scelte.isNotEmpty) await _leggi();
  });

  /// Una regola migliore per ogni etichetta che hai: quelle confermate si salvano («Offusca sempre» resta com'è).
  Future<void> _proponiRegole() => _chiediGroq(_regoleNuove, () async {
    final proposte = await RegoleColori.proponiRegole();
    if (!mounted) return;
    if (proposte.isEmpty) return setState(() => _errore = 'Le regole vanno già bene così.');
    final coppie = [for (final p in proposte) ((nome: p.nome, regola: p.regola), p.colore)];
    final scelte = await apriProposte(context, coppie, titolo: 'Regole proposte', azione: 'Applica') ?? const [];
    for (final (proposta, colore) in scelte) {
      await RegoleColori.salva(colore, proposta.regola, RegoleColori.di(colore)?.offuscaSempre ?? false);
    }
  });

  static const _etichetteNuove = 'Proponi etichette', _regoleNuove = 'Proponi regole';

  /// Groq sta pensando per [quale]: i due tasti aspettano, e un errore si legge sotto.
  Future<void> _chiediGroq(String quale, Future<void> Function() lavoro) async {
    setState(() {
      _propone = quale;
      _errore = null;
    });
    try {
      await lavoro();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _errore = e.message ?? 'Groq non ha risposto: riprova.');
    } finally {
      if (mounted) setState(() => _propone = null);
    }
  }

  Widget _tastoGroq(String quale, VoidCallback onPressed) => Bottone(
    _propone == quale ? 'Ci penso…' : quale,
    icona: Icons.auto_awesome_rounded,
    tipo: TipoBottone.tenue,
    alto: false,
    onPressed: _propone == null ? onPressed : null,
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: RegoleColori.tutte,
    builder: (context, regole, _) {
      final etichette = _etichette(), c = context.col;
      final nomi = [for (final (colore, _) in etichette) Segni.nomi.value[colore.chiave]?.trim().toLowerCase()];
      return SettingsPageFrame(
        title: 'Etichette',
        children: [
          Text('Le etichette sono i colori della rosa: un nome, e di cosa parlano le trascrizioni che ci vanno.', style: Testo.testo.copyWith(color: c.testoSecondario)),
          const SizedBox(height: Spazio.s3),
          Wrap(
            spacing: Spazio.s2,
            runSpacing: Spazio.s2,
            children: [_tastoGroq(_etichetteNuove, _proponi), if (etichette.isNotEmpty) _tastoGroq(_regoleNuove, _proponiRegole)],
          ),
          const SizedBox(height: Spazio.s2),
          Text(_errore ?? 'A Groq vanno solo i titoli delle trascrizioni.', style: Testo.piccolo.copyWith(color: _errore == null ? c.testoSecondario : c.errore)),
          const SizedBox(height: Spazio.s4),
          if (etichette.isEmpty) Text('Dai un nome a un colore dalla rosa: lo trovi qui.', style: Testo.testo.copyWith(color: c.testoSecondario)),
          for (final (i, (colore, quante)) in etichette.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Spazio.s3),
              child: RigaEtichetta(
                key: ValueKey(colore.chiave),
                colore: colore,
                nome: Segni.nomi.value[colore.chiave],
                quante: quante,
                regola: regole[colore.chiave],
                doppio: nomi[i] != null && nomi.where((n) => n == nomi[i]).length > 1,
                onCambia: (regola, offusca) => _cambia(colore, regola, offusca),
                onTogli: () => _togli(colore, Segni.nomi.value[colore.chiave] ?? Tinte.nome(colore.tinta, colore.luce), quante),
              ),
            ),
        ],
      );
    },
  );
}
