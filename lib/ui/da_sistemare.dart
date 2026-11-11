import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/proposte_colore.dart';
import 'ds.dart';
import 'molecole/proposte_colore.dart';
import 'molecole/riga_in_attesa.dart';
import 'molecole/sezione_in_attesa.dart';
import 'settings.dart';

/// Apre «Da sistemare» sulla parte [parte] (toccato l'orologio o la scintilla accanto al titolo).
Future<void> apriDaSistemare(
  BuildContext context, {
  required DaSistemare parte,
  required VoidCallback onRiprova,
  required List<Entry> voci,
  required ApriProposta onApri,
}) => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => DaSistemarePage(parte: parte, onRiprova: onRiprova, voci: voci, onApri: onApri)),
);

/// «Da sistemare» (10 nov, sua richiesta: una pagina vera, perché una proposta apre la trascrizione nel suo foglio):
/// in un posto solo quello che aspetta te, in due parti separate. Prima le registrazioni in attesa di rete
/// ([SezioneInAttesa]: il cestino, «Riprova tutte»), poi le proposte di colore ([SezioneProposteColore]: toccato un
/// titolo si apre la trascrizione, ✓ / ✕). Si apre sulla parte toccata; finite tutte e due, lo dice e resta aperta.
class DaSistemarePage extends StatefulWidget {
  const DaSistemarePage({super.key, required this.parte, required this.onRiprova, required this.voci, required this.onApri});

  final DaSistemare parte;
  final VoidCallback onRiprova;
  final List<Entry> voci;
  final ApriProposta onApri;

  @override
  State<DaSistemarePage> createState() => _DaSistemarePageState();
}

class _DaSistemarePageState extends State<DaSistemarePage> {
  List<Waiting>? _attesa;
  final _parti = {for (final p in DaSistemare.values) p: GlobalKey()};

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
    final prima = _attesa == null;
    final w = await Core.waiting();
    if (!mounted) return;
    setState(() => _attesa = w);
    // Aperta la prima volta: si va alla parte toccata.
    if (prima) WidgetsBinding.instance.addPostFrameCallback((_) => _vaiA(widget.parte));
  }

  void _vaiA(DaSistemare parte) {
    final dove = _parti[parte]!.currentContext;
    if (dove != null && dove.mounted) Scrollable.ensureVisible(dove, duration: Durata.normale, curve: Curva.standard);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: ProposteColore.tutte,
    builder: (context, _, _) {
      final attesa = _attesa;
      final vuota = attesa != null && attesa.isEmpty && ProposteColore.con(widget.voci).isEmpty;
      return SettingsPageFrame(
        title: 'Da sistemare',
        children: [
          // Cos'è questa pagina (11 nov: «quando si riempie, e cos'è?»).
          Text(
            'Qui arriva quello che aspetta te: le registrazioni partite senza rete e i colori che «Colora da sola» ti propone.',
            style: Testo.testo.copyWith(color: context.col.testoSecondario),
          ),
          const SizedBox(height: Spazio.s5),
          if (vuota) Text('Niente da sistemare: le registrazioni sono partite e le proposte le hai decise tutte.', style: Testo.testo.copyWith(color: context.col.testoSecondario)),
          // Quello che hai deciso esce piano: le parti si accorciano, non saltano.
          AnimatedSize(
            duration: Durata.normale,
            curve: Curva.standard,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(key: _parti[DaSistemare.attesa], child: SezioneInAttesa(attesa: attesa ?? const [], onRiprova: widget.onRiprova)),
                if (attesa?.isNotEmpty ?? false) const SizedBox(height: Spazio.s6),
                KeyedSubtree(key: _parti[DaSistemare.proposte], child: SezioneProposteColore(voci: widget.voci, onApri: widget.onApri)),
              ],
            ),
          ),
        ],
      );
    },
  );
}
