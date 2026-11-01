import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/native.dart';
import 'common.dart';
import 'mode_icon.dart';
import 'onboarding.dart';
import 'theme.dart';

/// Le due scelte che si capiscono, «più preciso» e «più veloce», ricavate dall'elenco dei modelli
/// che Groq ha adesso: se Groq ne aggiunge o ne cambia, le scelte seguono senza aggiornare l'app.
class ModelTiers {
  const ModelTiers(this.precise, this.fast);

  final String? precise, fast;

  String? labelOf(String id) => id == precise
      ? 'Più preciso'
      : id == fast
      ? 'Più veloce'
      : null;

  /// La voce: Whisper. Il più preciso è la versione più nuova senza «turbo», il più veloce la turbo.
  static ModelTiers speech(Iterable<String> ids) {
    final whisper = ids.where((id) => id.contains('whisper') && !id.contains('distil')).toList();
    int version(String id) => int.tryParse(RegExp(r'v(\d+)').firstMatch(id)?.group(1) ?? '') ?? 0;
    String? newest(Iterable<String> list) => list.isEmpty ? null : list.reduce((a, b) => version(b) > version(a) ? b : a);
    final precise = newest(whisper.where((id) => !id.contains('turbo'))) ?? (ids.isEmpty ? null : ids.first);
    return ModelTiers(precise, newest(whisper.where((id) => id.contains('turbo'))));
  }

  /// Il testo: una famiglia con più misure (es. 120b e 20b). Il più preciso è il più grande, il più veloce
  /// il più piccolo. Si preferisce la famiglia del modello che usi già; se no quella col modello più grande.
  static ModelTiers text(Iterable<String> ids, String current) {
    final size = RegExp(r'(\d+(?:\.\d+)?)b\b');
    final families = <String, Map<String, double>>{};
    for (final id in ids) {
      final m = size.firstMatch(id);
      if (m == null) continue;
      families.putIfAbsent(id.replaceFirst(m.group(0)!, '#'), () => {})[id] = double.parse(m.group(1)!);
    }
    final usable = families.entries.where((f) => f.value.length >= 2).toList();
    if (usable.isEmpty) return ModelTiers(current, null);
    final mine = usable.where((f) => f.value.containsKey(current)).firstOrNull;
    double biggest(MapEntry<String, Map<String, double>> f) => f.value.values.reduce((a, b) => a > b ? a : b);
    final family = (mine ?? usable.reduce((a, b) => biggest(b) > biggest(a) ? b : a)).value;
    final sorted = family.keys.toList()..sort((a, b) => family[a]!.compareTo(family[b]!));
    return ModelTiers(sorted.last, sorted.first);
  }
}

/// Le impostazioni, a gruppi come in Revolut: Dettatura, Pulizia del testo, Argomenti nelle note,
/// Utilizzo, Aiuto, la zona sensibile.
/// Ogni riga dice il suo valore e apre la sua pagina. Restituisce 'intro' per rivedere come funziona.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  CoreState? s;
  List<GroqModel>? models;

  @override
  void initState() {
    super.initState();
    _load();
    _loadModels();
  }

  Future<void> _load() async {
    final state = await Core.state();
    if (mounted) setState(() => s = state);
    _loadTopics();
    if (await askLimits(state)) _load();
  }

  /// L'elenco dei modelli di Groq (il telefono lo tiene un giorno): serve a dire «più preciso» o «più veloce».
  Future<void> _loadModels() async {
    try {
      final list = await Core.models();
      if (mounted) setState(() => models = list);
    } catch (_) {
      // Senza rete la riga dice il nome del modello: va bene lo stesso.
    }
  }

  Future<void> _setPurify(bool on) async {
    HapticFeedback.selectionClick();
    await Core.setPurify(on);
    _load();
  }

  /// Apre una pagina delle impostazioni; al ritorno si rilegge tutto.
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  /// La prova «utente nuovo»: si chiudono le impostazioni e l'app riparte dall'introduzione.
  void _setPreview(bool on) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    Core.setPreview(on);
  }

  Future<void> _setLimit(bool on) async {
    HapticFeedback.selectionClick();
    await Core.simulateLimit(on);
    Core.refresh();
    _load();
  }

  Future<void> _simulate(String what, bool on) async {
    HapticFeedback.selectionClick();
    await Core.simulate(what, on);
    _load();
  }

  void _setFakeWaiting(bool on) {
    HapticFeedback.selectionClick();
    Core.setFakeWaiting(on);
    setState(() {});
  }

  /// Una nota che mostra tutto quello che c'è: argomenti diversi, una parola chiave di due parole,
  /// un elenco, dei link. Si può riscrivere quando vuoi; le tue note non si toccano.
  Future<void> _demoNote() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    await Core.saveNote(
      Note(
        id: 'nota-di-prova',
        title: 'Nota di prova',
        created: now,
        updated: now,
        text: [
          'Questa nota serve a provare tutto quello che abbiamo aggiunto. Pizzicala, o usa il mirino nella barra in basso.',
          'Sono un product designer e il portfolio deve raccontarlo bene. Nel portfolio voglio tre casi: Zero, Transcrify e il redesign del sito. '
              'Ogni caso del portfolio parte da un problema vero, non da una bella schermata. Un product designer mostra come pensa.',
          'Le promesse della settimana sono il minimo: palestra lunedì, mercoledì e venerdì, e un quiz della patente al giorno. '
              'Anche un solo esercizio di palestra conta come promessa mantenuta.',
          'Stasera voglio vedere Obsession al cinema. Il film me l\'ha consigliato Marco: dice che la fotografia è incredibile.',
          'Cose da comprare:\n• dentifricio\n• pane\n• batterie per il mouse',
          'Da riguardare:\nhttps://www.youtube.com/@Figma\nhttps://pub.dev/packages/semantic_zoom',
          'Per Transcrify il Dock deve essere più leggero, e il motore degli argomenti deve girare anche sui telefoni economici. '
              'Transcrify resta gratis: niente che si paghi.',
        ].join('\n\n'),
      ),
    );
    Core.refresh();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('«Nota di prova» è nei Pensieri')));
  }

  static String _short(String model) => model.substring(model.lastIndexOf('/') + 1);

  static const _modeNames = {'fedele': 'Fedele', 'pulita': 'Pulita', 'riassunto': 'Riassunto'};

  String _modelValue(String current, {required bool speech}) {
    final list = models;
    if (list == null) return _short(current);
    final ids = list.where((m) => m.speech == speech).map((m) => m.id);
    final tiers = speech ? ModelTiers.speech(ids) : ModelTiers.text(ids, current);
    return tiers.labelOf(current) ?? _short(current);
  }

  @override
  Widget build(BuildContext context) {
    final st = s;
    return Paper(
      child: Scaffold(
        appBar: AppBar(),
        body: st == null
            ? const SizedBox.shrink()
            : ListView(
                // Sotto, lo spazio dei tasti di Android se ci sono (i tre bottoni), niente se non ci sono.
                padding: EdgeInsets.only(bottom: 40 + MediaQuery.viewPaddingOf(context).bottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text('Impostazioni', style: display(context)),
                  ),
                  // Tre gruppi, uno per cosa fa l'app col tuo parlato: la voce diventa testo, il testo si pulisce,
                  // le note si dividono per argomento. Quando una cosa si accende, le sue scelte compaiono sotto.
                  SettingsGroup(
                    label: 'Dettatura',
                    children: [
                      SettingsRow(
                        icon: Icons.graphic_eq_rounded,
                        color: Tokens.blue,
                        title: 'Trascrizione',
                        subtitle: 'Chi ascolta la tua voce e la scrive',
                        value: _modelValue(st.sttModel, speech: true),
                        onTap: () => _open(const ModelSettings(speech: true)),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Pulizia del testo',
                    children: [
                      SettingsRow(
                        icon: Icons.auto_fix_high_rounded,
                        color: Tokens.violet,
                        title: 'Pulisci il testo',
                        subtitle: 'Toglie esitazioni e ripetizioni, mette la punteggiatura',
                        trailing: Switch(value: st.purify, onChanged: _setPurify),
                        onTap: () => _setPurify(!st.purify),
                      ),
                      _Unfold(
                        open: st.purify,
                        children: [
                          SettingsRow(
                            icon: Icons.auto_awesome_rounded,
                            color: Tokens.violet,
                            title: 'Modello',
                            value: _modelValue(st.llmModel, speech: false),
                            onTap: () => _open(const ModelSettings(speech: false)),
                          ),
                          SettingsRow(
                            icon: Icons.tune_rounded,
                            color: Tokens.violet,
                            title: 'Come pulisce',
                            value: _modeNames[st.mode],
                            onTap: () => _open(LiveSettings(title: 'Come pulisce', build: _cleanPage)),
                          ),
                          SettingsRow(
                            icon: Icons.spellcheck_rounded,
                            color: Tokens.violet,
                            title: 'Vocabolario',
                            value: st.words.isEmpty ? 'Vuoto' : '${st.words.length} ${st.words.length == 1 ? 'parola' : 'parole'}',
                            onTap: () => _open(
                              LiveSettings(
                                title: 'Vocabolario',
                                build: (context, st, reload) => [WordsEditor(words: st.words, onChanged: reload)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Argomenti nelle note',
                    children: [
                      SettingsRow(
                        icon: Icons.bubble_chart_rounded,
                        color: Tokens.green,
                        title: 'Dividi per argomento',
                        subtitle: 'Sul telefono, senza rete',
                        trailing: Switch(value: topicsOn, onChanged: _setTopics),
                        onTap: () => _setTopics(!topicsOn),
                      ),
                      _Unfold(
                        open: topicsOn,
                        children: [
                          SettingsRow(
                            icon: Icons.memory_rounded,
                            color: Tokens.green,
                            title: 'Modello',
                            value: topics,
                            onTap: () => _open(const TopicsSettings()),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Utilizzo',
                    children: [
                      SettingsRow(
                        icon: Icons.insights_rounded,
                        color: Tokens.green,
                        title: 'Utilizzo',
                        value: '${(_dayUsed(st) / 60).round()} di ${(st.dayLimit / 60).round()} min oggi',
                        onTap: () => _open(const UsagePage()),
                      ),
                    ],
                  ),
                  const _Permissions(),
                  const SizedBox(height: 16),
                  SettingsGroup(
                    label: 'Aiuto',
                    children: [
                      SettingsRow(
                        icon: Icons.school_rounded,
                        color: context.tk.muted,
                        title: 'Rivedi come funziona',
                        onTap: () => Navigator.of(context).pop('intro'),
                      ),
                    ],
                  ),
                  if (kDebugMode)
                    SettingsGroup(
                      label: 'Prove',
                      children: [
                        SettingsRow(
                          icon: Icons.science_outlined,
                          color: Tokens.blue,
                          title: 'Crea la nota di prova',
                          subtitle: 'Con tutto quello che c\'è: argomenti, elenchi, link',
                          onTap: _demoNote,
                        ),
                        SettingsRow(
                          icon: Icons.person_outline_rounded,
                          color: Tokens.blue,
                          title: 'Come un utente nuovo',
                          subtitle: 'Senza chiave né note, con l\'introduzione. I tuoi dati restano.',
                          trailing: Switch(value: Core.preview.value, onChanged: _setPreview),
                          onTap: () => _setPreview(!Core.preview.value),
                        ),
                        SettingsRow(
                          icon: Icons.hourglass_bottom_rounded,
                          color: Tokens.blue,
                          title: 'Minuti finiti',
                          subtitle: 'Transcri dorme come quando finisce il limite',
                          trailing: Switch(value: st.simulateLimit, onChanged: _setLimit),
                          onTap: () => _setLimit(!st.simulateLimit),
                        ),
                        SettingsRow(
                          icon: Icons.pinch_rounded,
                          color: Tokens.blue,
                          title: 'Pizzico al contrario',
                          subtitle: 'Stringere le dita = più argomenti',
                          trailing: Switch(
                            value: Core.pinchReversed.value,
                            onChanged: (on) => setState(() => Core.pinchReversed.value = on),
                          ),
                          onTap: () => setState(() => Core.pinchReversed.value = !Core.pinchReversed.value),
                        ),
                        SettingsRow(
                          icon: Icons.wifi_off_rounded,
                          color: Tokens.blue,
                          title: 'Senza rete',
                          subtitle: 'Groq non risponde: le registrazioni vanno in attesa',
                          trailing: Switch(value: st.simOffline, onChanged: (on) => _simulate('offline', on)),
                          onTap: () => _simulate('offline', !st.simOffline),
                        ),
                        SettingsRow(
                          icon: Icons.key_off_rounded,
                          color: Tokens.blue,
                          title: 'Chiave rifiutata',
                          subtitle: 'Groq dice che la chiave non è valida',
                          trailing: Switch(value: st.simBadKey, onChanged: (on) => _simulate('badKey', on)),
                          onTap: () => _simulate('badKey', !st.simBadKey),
                        ),
                        SettingsRow(
                          icon: Icons.mic_off_rounded,
                          color: Tokens.blue,
                          title: 'Microfono negato',
                          subtitle: 'Come se non avessi dato il permesso',
                          trailing: Switch(value: st.simNoMic, onChanged: (on) => _simulate('noMic', on)),
                          onTap: () => _simulate('noMic', !st.simNoMic),
                        ),
                        SettingsRow(
                          icon: Icons.cloud_off_rounded,
                          color: Tokens.blue,
                          title: 'Registrazioni in attesa',
                          subtitle: 'Due finte, come se fosse mancata la rete',
                          trailing: Switch(value: Core.fakeWaiting.value, onChanged: _setFakeWaiting),
                          onTap: () => _setFakeWaiting(!Core.fakeWaiting.value),
                        ),
                      ],
                    ),
                  SettingsGroup(
                    label: 'Zona sensibile',
                    danger: true,
                    children: [
                      SettingsRow(
                        icon: Icons.key_rounded,
                        color: Tokens.red,
                        title: 'Chiave Groq',
                        value: st.maskedKey ?? 'Nessuna',
                        mono: st.maskedKey != null,
                        onTap: () => _open(LiveSettings(title: 'Chiave Groq', build: _keyPage)),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _cleanPage(BuildContext context, CoreState st, VoidCallback reload) => [
    _ModeChooser(
      mode: st.mode,
      enabled: st.purify,
      onChanged: (m) async {
        await Core.setMode(m);
        reload();
      },
    ),
    const SizedBox(height: 24),
    PromptEditor(
      key: ValueKey(st.mode),
      prompt: st.prompt,
      custom: st.customPrompt,
      defaultPrompt: st.defaultPrompt,
      enabled: st.purify,
      onChanged: reload,
    ),
  ];

  /// Il riassunto degli argomenti per la riga: il modello scelto, o quanto manca a scaricarlo.
  String? topics;
  bool topicsOn = false;
  List<TopicModelInfo> _topicModels = [];

  /// L'interruttore della riga, come per la pulizia. Acceso: il modello già sul telefono, se c'è;
  /// se no il più leggero, che si scarica.
  Future<void> _setTopics(bool on) async {
    HapticFeedback.selectionClick();
    final ready = _topicModels.where((m) => m.state == 'ready').map((m) => m.id).firstOrNull;
    await Core.chooseTopicModel(on ? ready ?? 'leggero' : null);
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final list = await Core.topicModels();
    final chosen = list.where((m) => m.chosen).firstOrNull;
    if (!mounted) return;
    setState(() {
      _topicModels = list;
      topicsOn = chosen != null;
      topics = chosen == null
          ? null
          : chosen.state == 'downloading'
          ? '${((chosen.progress ?? 0) * 100).round()}%'
          : chosen.label;
    });
  }

  /// La chiave: un campo con la chiave nascosta e «Modifica»; rimuoverla sta in fondo, a parte.
  List<Widget> _keyPage(BuildContext context, CoreState st, VoidCallback reload) {
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    Future<void> change() async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => KeyPage(onSaved: () => Navigator.of(ctx).pop(), onClose: () => Navigator.of(ctx).pop()),
        ),
      );
      reload();
    }

    Future<void> remove() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rimuovere la chiave?'),
          content: const Text(
            "Transcri si chiude e non potrà trascrivere finché non ne metti un'altra. Le trascrizioni e le note restano.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            // Quello che vuoi fare, rosso e pieno; tornare indietro resta lì, senza peso.
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tokens.red, minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rimuovi'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await Core.deleteKey();
      Core.refresh();
      reload();
    }

    final has = st.maskedKey != null;
    return [
      Text(
        'Dà accesso al tuo account Groq. Resta cifrata su questo telefono: non condividerla.',
        style: t.bodyMedium?.copyWith(color: tk.muted),
      ),
      const SizedBox(height: 20),
      // Come un campo: la chiave (nascosta) e a destra Modifica, che apre la pagina per incollarne una o crearne una nuova.
      Material(
        color: islandColor(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: change,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    st.maskedKey ?? 'Nessuna chiave',
                    style: has ? monoStyle(context, size: 15, color: tk.text) : t.bodyLarge?.copyWith(color: tk.faint),
                  ),
                ),
                TextButton(onPressed: change, child: Text(has ? 'Modifica' : 'Aggiungi')),
              ],
            ),
          ),
        ),
      ),
      if (has) ...[
        const SizedBox(height: 48),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Tokens.red, padding: EdgeInsets.zero),
            onPressed: remove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Rimuovi la chiave'),
          ),
        ),
      ],
    ];
  }
}

/// Le righe che dipendono da un interruttore: si aprono sotto quando è acceso, spariscono quando è spento.
class _Unfold extends StatelessWidget {
  const _Unfold({required this.open, required this.children});

  final bool open;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: open ? Column(children: children) : const SizedBox(width: double.infinity),
  );
}

/// La pagina dell'utilizzo: tutti i contatori, ognuno nella sua scheda.
class UsagePage extends StatelessWidget {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context) => LiveSettings(
    title: 'Utilizzo',
    build: (context, st, reload) => [
      UsageCard(label: 'Trascrizione', children: speechMeters(st)),
      const SizedBox(height: 20),
      UsageCard(label: 'Pulizia del testo', children: textMeters(st)),
    ],
  );
}

/// I minuti usati come li vedi: se i minuti sono finiti (anche per finta, nelle prove) il contatore è pieno,
/// così quello che leggi qui e quello che fa Transcri dicono la stessa cosa.
int _hourUsed(CoreState st) => st.limited == 'hourly' ? st.hourLimit : st.hourUsed;
int _dayUsed(CoreState st) => st.limited == 'daily' ? st.dayLimit : st.dayUsed;

/// I contatori della trascrizione: quante oggi e i minuti di audio, con quando si azzerano.
List<Widget> speechMeters(CoreState st) => [
  _Meter(
    label: 'Trascrizioni oggi',
    value: '${st.sttUses}',
    of: _requestLimit(st.sttLimits),
    fraction: _fraction(st.sttUses, _requestLimit(st.sttLimits)),
    resets: _midnight(),
  ),
  _Meter(
    label: "Audio quest'ora",
    value: '${(_hourUsed(st) / 60).round()}',
    of: '${(st.hourLimit / 60).round()} min',
    fraction: _hourUsed(st) / st.hourLimit,
    resets: st.limited == 'hourly' ? st.resetAt : st.hourEnd,
  ),
  _Meter(
    label: 'Audio oggi',
    value: '${(_dayUsed(st) / 60).round()}',
    of: '${(st.dayLimit / 60).round()} min',
    fraction: _dayUsed(st) / st.dayLimit,
    resets: st.limited == 'daily' ? st.resetAt : st.dayEnd,
  ),
  const _Note("Groq conta i minuti di audio, non il tempo che passa: in un'ora puoi mandargli fino a 120 minuti di parlato."),
];

/// I contatori della pulizia del testo.
List<Widget> textMeters(CoreState st) => [
  _Meter(
    label: 'Pulizie oggi',
    value: '${st.llmUses}',
    of: _requestLimit(st.llmLimits),
    fraction: _fraction(st.llmUses, _requestLimit(st.llmLimits)),
    resets: _midnight(),
  ),
];

/// Le richieste al giorno, se Groq ce le ha dette nell'ultima risposta.
String? _requestLimit(Map<String, String> limits) => int.tryParse(limits['requests'] ?? '') == null ? null : limits['requests'];

double? _fraction(int used, String? limit) {
  final l = int.tryParse(limit ?? '');
  return l == null || l == 0 ? null : used / l;
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Se dei modelli in uso non sappiamo ancora i limiti, li chiede a Groq (una volta per modello).
/// Restituisce true se ne ha chiesti: allora conviene rileggere lo stato.
Future<bool> askLimits(CoreState st) async {
  var asked = false;
  if (_requestLimit(st.sttLimits) == null && _asked.add(st.sttModel)) {
    await Core.probeLimits(st.sttModel, speech: true);
    asked = true;
  }
  if (_requestLimit(st.llmLimits) == null && _asked.add(st.llmModel)) {
    await Core.probeLimits(st.llmModel, speech: false);
    asked = true;
  }
  return asked;
}

/// I modelli già chiesti in questa sessione: niente richieste ripetute se Groq non risponde.
final _asked = <String>{};

/// I contatori in una scheda, come gli altri gruppi delle impostazioni: si vedono separati e chiari.
class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(left: 12), child: UsageLabel(label)),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: islandColor(context), borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
            ],
          ),
        ),
      ],
    );
  }
}

/// L'etichetta piccola sopra un gruppo di contatori.
class UsageLabel extends StatelessWidget {
  const UsageLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: context.tk.muted),
    ),
  );
}

/// La scelta di un modello: «Più preciso» o «Più veloce», con una riga su cosa cambia e il nome vero
/// piccolo sotto. Le due scelte vengono dall'elenco di Groq di adesso. Sotto, quanto l'hai usato oggi.
class ModelSettings extends StatefulWidget {
  const ModelSettings({super.key, required this.speech});

  final bool speech;

  @override
  State<ModelSettings> createState() => _ModelSettingsState();
}

class _ModelSettingsState extends State<ModelSettings> {
  CoreState? st;
  List<GroqModel>? models;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Core.state();
    List<GroqModel>? list;
    String? problem;
    try {
      list = await Core.models();
    } catch (_) {
      problem = 'Non riesco a leggere i modelli da Groq. Serve la rete.';
    }
    if (!mounted) return;
    setState(() {
      st = s;
      models = list ?? models;
      error = problem;
    });
    if (await askLimits(s)) _load();
  }

  Future<void> _pick(String id) async {
    HapticFeedback.selectionClick();
    await Core.setModel(id, speech: widget.speech);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    final speech = widget.speech;
    final current = s == null ? '' : (speech ? s.sttModel : s.llmModel);
    final ids = models?.where((m) => m.speech == speech).map((m) => m.id);
    final tiers = ids == null ? null : (speech ? ModelTiers.speech(ids) : ModelTiers.text(ids, current));
    final choices = [
      if (tiers?.precise != null)
        (tiers!.precise!, 'Più preciso', speech ? 'Sbaglia meno, anche coi nomi.' : 'Capisce meglio cosa volevi dire.'),
      if (tiers?.fast != null) (tiers!.fast!, 'Più veloce', speech ? 'Il testo arriva prima.' : "Più svelto, un po' meno attento."),
    ];
    return SettingsPageFrame(
      title: speech ? 'Trascrizione' : 'Pulizia del testo',
      children: [
        Text(
          speech ? 'Chi ascolta la tua voce e la scrive.' : 'Chi rilegge quello che hai detto e lo pulisce.',
          style: t.bodyMedium?.copyWith(color: tk.muted),
        ),
        const SizedBox(height: 20),
        if (error != null) Text(error!, style: t.bodySmall?.copyWith(color: Tokens.red)),
        if (models == null && error == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        for (final (id, label, hint) in choices)
          _Choice(
            title: label,
            hint: hint,
            subtitle: id.substring(id.lastIndexOf('/') + 1),
            selected: current == id,
            onTap: () => _pick(id),
          ),
        if (s != null) ...[const SizedBox(height: 20), UsageCard(label: 'Utilizzo', children: speech ? speechMeters(s) : textMeters(s))],
      ],
    );
  }
}

/// Il vocabolario: le parole come chip; "Aggiungi" apre il campo, che si richiude
/// appena smetti di scrivere.
class WordsEditor extends StatefulWidget {
  const WordsEditor({super.key, required this.words, required this.onChanged});

  final List<String> words;
  final VoidCallback onChanged;

  @override
  State<WordsEditor> createState() => _WordsEditorState();
}

class _WordsEditorState extends State<WordsEditor> {
  final field = TextEditingController();
  final focus = FocusNode();
  bool adding = false;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus && adding) _close();
    });
  }

  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => adding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  /// Chiudendo, quello che era scritto non va perso: si aggiunge.
  Future<void> _close() async {
    await _add(keepOpen: false);
    if (mounted) setState(() => adding = false);
  }

  Future<void> _add({bool keepOpen = true}) async {
    final w = field.text.trim();
    field.clear();
    if (w.isNotEmpty && !widget.words.contains(w)) {
      await Core.setWords([...widget.words, w]);
      widget.onChanged();
    }
    if (keepOpen && mounted) focus.requestFocus();
  }

  Future<void> _remove(String w) async {
    await Core.setWords(widget.words.where((e) => e != w).toList());
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vocabolario', style: t.titleMedium),
        const SizedBox(height: 2),
        Text('Nomi, marchi e termini scritti come li vuoi tu. Li usa la pulizia del testo.', style: t.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final w in widget.words)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(w, style: t.bodyMedium),
                    const SizedBox(width: 4),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _remove(w),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 14, color: tk.muted),
                      ),
                    ),
                  ],
                ),
              ),
            if (adding)
              SizedBox(
                width: 180,
                child: TextField(
                  controller: field,
                  focusNode: focus,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Scrivi e premi invio',
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              )
            else
              ActionChip(
                onPressed: _open,
                avatar: Icon(Icons.add_rounded, size: 16, color: Tokens.blue),
                label: const Text('Aggiungi'),
                labelStyle: TextStyle(color: Tokens.blue, fontWeight: FontWeight.w600),
                side: BorderSide(color: Tokens.blue.withValues(alpha: 0.4)),
                shape: const StadiumBorder(),
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ],
    );
  }
}

/// I tre modi di pulire: fedele, pulita, riassunto. Spenti finché la pulizia è spenta.
class _ModeChooser extends StatelessWidget {
  const _ModeChooser({required this.mode, required this.enabled, required this.onChanged});

  final String mode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static const _modes = [
    ('fedele', 'Fedele', 'Parola per parola, con punteggiatura e paragrafi.'),
    ('pulita', 'Pulita', 'Senza esitazioni e ripetizioni, con la tua voce.'),
    ('riassunto', 'Riassunto', 'Solo i punti: decisioni, date, cose da fare.'),
  ];

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    final current = _modes.firstWhere((m) => m.$1 == mode);
    final index = _modes.indexOf(current);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(32)),
              child: LayoutBuilder(
                builder: (context, box) {
                  final cell = box.maxWidth / 3;
                  void pick(double x) {
                    final m = _modes[(x / cell).floor().clamp(0, 2)].$1;
                    if (m != mode) onChanged(m);
                  }

                  return GestureDetector(
                    // Si tocca o si trascina il dito: vale il modo sotto il dito.
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => pick(d.localPosition.dx),
                    onHorizontalDragStart: (d) => pick(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          left: cell * index,
                          top: 0,
                          bottom: 0,
                          width: cell,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Tokens.blue,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [BoxShadow(color: Tokens.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final m in _modes)
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomPaint(size: const Size(18, 14), painter: ModeIcon(m.$1, m.$1 == mode ? Colors.white : tk.muted)),
                                    const SizedBox(height: 5),
                                    Text(
                                      m.$2,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: m.$1 == mode ? Colors.white : tk.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(current.$3, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Il prompt del modo scelto. Resta bloccato; si modifica solo se la pulizia è accesa.
class PromptEditor extends StatefulWidget {
  const PromptEditor({
    super.key,
    required this.prompt,
    required this.custom,
    required this.defaultPrompt,
    required this.enabled,
    required this.onChanged,
  });

  final String prompt, defaultPrompt;
  final bool custom, enabled;
  final VoidCallback onChanged;

  @override
  State<PromptEditor> createState() => _PromptEditorState();
}

class _PromptEditorState extends State<PromptEditor> {
  final field = TextEditingController();
  bool editing = false;

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  void _edit() {
    if (!widget.enabled) return;
    field.text = widget.prompt;
    setState(() => editing = true);
  }

  Future<void> _save() async {
    final text = field.text.trim();
    await Core.setPrompt(text.isEmpty || text == widget.defaultPrompt.trim() ? null : text);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => editing = false);
    widget.onChanged();
  }

  Future<void> _reset() async {
    await Core.setPrompt(null);
    setState(() => editing = false);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.enabled || editing ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Prompt della pulizia', style: t.titleMedium),
              const SizedBox(width: 8),
              Text(widget.custom ? 'tuo' : 'predefinito', style: monoStyle(context, color: tk.faint)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !editing
                ? Material(
                    color: tk.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.enabled ? _edit : null,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.prompt,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(color: tk.faint),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(widget.enabled ? Icons.edit_rounded : Icons.lock_outline_rounded, size: 16, color: tk.faint),
                          ],
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: field,
                        autofocus: true,
                        minLines: 6,
                        maxLines: 14,
                        style: t.bodySmall?.copyWith(color: tk.text, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton(onPressed: _save, child: const Text('Salva')),
                          const SizedBox(width: 8),
                          TextButton(onPressed: () => setState(() => editing = false), child: const Text('Annulla')),
                          const Spacer(),
                          if (widget.custom) TextButton(onPressed: _reset, child: const Text('Predefinito')),
                        ],
                      ),
                    ],
                  ),
          ),
          if (!widget.enabled && !editing) ...[const SizedBox(height: 6), Text('Si usa solo con la pulizia accesa.', style: t.bodySmall)],
        ],
      ),
    );
  }
}

/// I contatori "oggi" dei modelli ripartono a mezzanotte.
DateTime _midnight() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + 1);
}

String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Il momento in cui si azzera, come lo diresti: "alle 14:05", "domani alle 09:12", "a mezzanotte".
String _when(DateTime d) {
  final now = DateTime.now();
  if (d.hour == 0 && d.minute == 0) return 'a mezzanotte';
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return d.isBefore(tomorrow) ? 'alle ${_clock(d)}' : 'domani alle ${_clock(d)}';
}

/// Una misura: etichetta, numero grande, "di N" e, se c'è un limite, una barretta.
/// Sotto, quando si azzera; finito il limite, al posto del numero c'è l'ora in cui torna.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.of, this.fraction, this.resets});

  final String label, value;
  final String? of;
  final double? fraction;

  /// Quando il contatore torna a zero (null: non è ancora partito, non c'è niente da azzerare).
  final DateTime? resets;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    final full = fraction != null && fraction! >= 1;
    final near = fraction != null && fraction! >= 0.8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: t.bodyMedium?.copyWith(color: tk.muted)),
            const Spacer(),
            Text(value, style: display(context, size: 20, color: full ? Tokens.red : null)),
            if (of != null) Text(' / $of', style: monoStyle(context)),
          ],
        ),
        if (fraction != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction!.clamp(0, 1).toDouble(),
              minHeight: 5,
              // La parte ancora libera si vede, anche sulla scheda bianca.
              backgroundColor: tk.border,
              color: full ? Tokens.red : Tokens.blue,
            ),
          ),
        ],
        // Quando si azzera si dice solo se serve: vicino al limite, o finito. Un orario, non un conto alla rovescia.
        if (resets != null && near) ...[
          const SizedBox(height: 6),
          Text(
            full ? 'Finito. Torna ${_when(resets!)}' : 'Si azzera ${_when(resets!)}',
            style: monoStyle(context).copyWith(color: full ? Tokens.red : null),
          ),
        ],
      ],
    );
  }
}

/// Un gruppo di impostazioni, come in Revolut: un'etichetta piccola e una scheda con le sue righe.
/// Si vede subito dove finisce un gruppo e comincia l'altro, senza linee.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.label, required this.children, this.danger = false});

  final String label;
  final List<Widget> children;

  /// La zona sensibile: la scheda ha un filo rosso.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: danger ? Tokens.red : tk.muted),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: islandColor(context),
              borderRadius: BorderRadius.circular(24),
              border: danger ? Border.all(color: Tokens.red.withValues(alpha: 0.35)) : null,
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// I permessi, tutti in un posto: si vede quali sono accesi e, toccandoli, si va ad accenderli.
class _Permissions extends StatefulWidget {
  const _Permissions();

  @override
  State<_Permissions> createState() => _PermissionsState();
}

class _PermissionsState extends State<_Permissions> with WidgetsBindingObserver {
  bool? mic, notifications, overlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Si torna dalle impostazioni di Android: il permesso può essere cambiato.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final m = await Permission.microphone.isGranted;
    final n = await Permission.notification.isGranted;
    final o = await Core.canDrawOverlays();
    if (mounted) {
      setState(() {
        mic = m;
        notifications = n;
        overlay = o;
      });
    }
  }

  /// Se è spento lo chiede; se Android non lo chiede più, o è già acceso, si apre la sua pagina.
  Future<void> _fix(Permission p) async {
    if (!(await p.isGranted) && (await p.request()).isGranted) return _load();
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    String state(bool? on) => on == null ? '' : (on ? 'Attivo' : 'Da attivare');
    return SettingsGroup(
      label: 'Permessi',
      children: [
        SettingsRow(
          icon: Icons.mic_rounded,
          color: Tokens.blue,
          title: 'Microfono',
          value: state(mic),
          onTap: () => _fix(Permission.microphone),
        ),
        SettingsRow(
          icon: Icons.notifications_rounded,
          color: Tokens.blue,
          title: 'Notifiche',
          value: state(notifications),
          onTap: () => _fix(Permission.notification),
        ),
        SettingsRow(
          icon: Icons.layers_rounded,
          color: Tokens.blue,
          title: 'Sopra le altre app',
          subtitle: 'Per stare sul bordo dello schermo',
          value: state(overlay),
          onTap: Core.openOverlaySettings,
        ),
      ],
    );
  }
}

/// Una riga: l'icona nel suo tondo colorato, il nome (e una riga di spiegazione), a destra il valore
/// e la freccia se apre una pagina, o un interruttore.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.mono = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle, value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Il valore è un codice (la chiave): in DM Mono.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: t.bodySmall)],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  style: mono ? monoStyle(context, size: 12) : t.bodyMedium?.copyWith(color: tk.muted),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: tk.faint),
          ],
        ),
      ),
    );
  }
}

/// Una pagina delle impostazioni che si tiene aggiornata da sola: legge lo stato e lo rilegge
/// dopo ogni cambio, così quello che vedi è sempre quello che c'è.
class LiveSettings extends StatefulWidget {
  const LiveSettings({super.key, required this.title, required this.build});

  final String title;
  final List<Widget> Function(BuildContext context, CoreState st, VoidCallback reload) build;

  @override
  State<LiveSettings> createState() => _LiveSettingsState();
}

class _LiveSettingsState extends State<LiveSettings> {
  CoreState? st;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Core.state();
    if (mounted) setState(() => st = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    return SettingsPageFrame(title: widget.title, children: s == null ? const [] : widget.build(context, s, _load));
  }
}

/// La cornice di una pagina delle impostazioni: freccia indietro, titolo grande, il contenuto.
class SettingsPageFrame extends StatelessWidget {
  const SettingsPageFrame({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Paper(
      child: Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 48 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            Text(title, style: display(context, size: 28)),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Gli argomenti nelle note: spenti, oppure un modello sul telefono, più leggero o più preciso.
/// Sceglierlo vuol dire scaricarlo, una volta; poi lavora senza rete e senza costi.
class TopicsSettings extends StatefulWidget {
  const TopicsSettings({super.key});

  @override
  State<TopicsSettings> createState() => _TopicsSettingsState();
}

class _TopicsSettingsState extends State<TopicsSettings> {
  List<TopicModelInfo>? models;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await Core.topicModels();
    if (!mounted) return;
    setState(() => models = list);
    // Mentre scarica si guarda a che punto è, due volte al secondo; poi si smette.
    final busy = list.any((m) => m.state == 'downloading');
    if (busy && _poll == null) _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => _load());
    if (!busy) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _choose(String? id) async {
    HapticFeedback.selectionClick();
    await Core.chooseTopicModel(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = models;
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    return SettingsPageFrame(
      title: 'Argomenti nelle note',
      children: [
        Text(
          'Transcrify divide le note per argomento e le raggruppa da solo. Lo fa un modello che gira sul telefono: '
          'si scarica una volta, poi lavora senza rete e senza costi. Meglio col Wi-Fi.',
          style: t.bodyMedium?.copyWith(color: tk.muted),
        ),
        const SizedBox(height: 24),
        if (list != null) ...[
          // Prima il leggero: è la scelta più sobria.
          for (final m in [...list]..sort((a, b) => a.approxMb.compareTo(b.approxMb)))
            _Choice(
              title: m.label,
              // Il più preciso vuole memoria: sui telefoni che ne hanno poca lo diciamo prima.
              hint: m.id == 'preciso' && m.ramGb < 6 ? 'Su questo telefono può essere lento.' : null,
              subtitle: '${m.name} · circa ${m.approxMb} MB',
              selected: m.chosen,
              onTap: () => _choose(m.id),
              below: m.chosen || m.state != 'missing' ? _ModelState(model: m, onRefresh: _load) : null,
            ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.subtitle, required this.selected, required this.onTap, this.hint, this.below});

  final String title, subtitle;

  /// Una riga che dice cosa cambia, sopra il nome vero.
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: islandColor(context),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? Tokens.blue : Colors.transparent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.titleMedium),
                          if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: t.bodySmall)],
                          const SizedBox(height: 2),
                          // Il nome del modello, piccolo: per chi lo conosce.
                          Text(subtitle, style: monoStyle(context, size: 11)),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: selected ? Tokens.blue : tk.faint,
                    ),
                  ],
                ),
                ?below,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sotto un modello: quanto manca, o se è pronto, o cosa è andato storto.
class _ModelState extends StatelessWidget {
  const _ModelState({required this.model, required this.onRefresh});

  final TopicModelInfo model;
  final VoidCallback onRefresh;

  static String _mb(int bytes) => (bytes / 1e6).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = model;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: switch (m.state) {
        'downloading' => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: m.progress, minHeight: 6),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.total == null || m.total == 0 ? 'Comincio…' : 'Scarico: ${_mb(m.done!)} di ${_mb(m.total!)} MB',
                    style: t.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Core.cancelTopicModel(m.id);
                    onRefresh();
                  },
                  child: const Text('Ferma'),
                ),
              ],
            ),
          ],
        ),
        'ready' => Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Tokens.green),
            const SizedBox(width: 6),
            Expanded(child: Text('Sul telefono', style: t.bodySmall)),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Tokens.red),
              onPressed: () async {
                await Core.deleteTopicModel(m.id);
                onRefresh();
              },
              child: const Text('Elimina'),
            ),
          ],
        ),
        'failed' => Row(
          children: [
            Expanded(
              child: Text(m.error ?? 'Non è andata.', style: t.bodySmall?.copyWith(color: Tokens.red)),
            ),
            TextButton(
              onPressed: () async {
                await Core.chooseTopicModel(m.id);
                onRefresh();
              },
              child: const Text('Riprova'),
            ),
          ],
        ),
        // Scelto ma fermato a metà: riprende da dove era arrivato.
        _ => Row(
          children: [
            Expanded(child: Text('Fermo a metà', style: t.bodySmall)),
            TextButton(
              onPressed: () async {
                await Core.chooseTopicModel(m.id);
                onRefresh();
              },
              child: const Text('Riprendi'),
            ),
          ],
        ),
      },
    );
  }
}
