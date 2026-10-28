import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/native.dart';
import 'common.dart';
import 'mode_icon.dart';
import 'onboarding.dart';
import 'theme.dart';

// Modelli testuali consigliati per la pulizia, in ordine di preferenza.
const _recommendedLlm = [
  'openai/gpt-oss-120b',
  'llama-3.3-70b-versatile',
  'openai/gpt-oss-20b',
  'moonshotai/kimi-k2-instruct',
  'qwen/qwen3-32b',
];
const _recommendedStt = ['whisper-large-v3', 'whisper-large-v3-turbo'];

/// Una scelta di modello col nome che si capisce; quello vero sta scritto piccolo sotto.
class _Curated {
  const _Curated(this.id, this.label, this.hint);

  final String id, label, hint;
}

const _sttChoices = [
  _Curated('whisper-large-v3', 'Più preciso', 'Sbaglia meno, anche coi nomi.'),
  _Curated('whisper-large-v3-turbo', 'Più veloce', 'Il testo arriva prima.'),
];
const _llmChoices = [
  _Curated('openai/gpt-oss-120b', 'Più preciso', 'Capisce meglio cosa volevi dire.'),
  _Curated('openai/gpt-oss-20b', 'Più veloce', "Più svelto, un po' meno attento."),
];

/// Le impostazioni, a gruppi come in Revolut: Dettatura, Modelli, Aiuto, la zona sensibile.
/// Ogni riga dice il suo valore e apre la sua pagina. Restituisce 'intro' per rivedere come funziona.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  CoreState? s;
  List<GroqModel>? models;
  String? modelsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await Core.state();
    if (mounted) setState(() => s = state);
    _loadTopics();
  }

  /// I modelli si chiedono a Groq una volta sola, quando servono.
  Future<List<GroqModel>?> _models() async {
    if (models != null) return models;
    try {
      final list = await Core.models();
      setState(() {
        models = list;
        modelsError = null;
      });
      return list;
    } catch (e) {
      setState(() => modelsError = 'Non riesco a leggere i modelli da Groq.');
      return null;
    }
  }

  Future<void> _setPurify(bool on) async {
    await Core.setPurify(on);
    _load();
  }

  /// Apre una pagina delle impostazioni; al ritorno si rilegge tutto.
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  static String _short(String model) => model.substring(model.lastIndexOf('/') + 1);

  /// Come si chiama la scelta nella riga: «Più preciso», «Più veloce»; il nome vero solo se è un altro modello.
  static String _choiceName(String model, List<_Curated> choices) =>
      choices.where((c) => c.id == model).map((c) => c.label).firstOrNull ?? _short(model);

  /// La pagina di un modello: due scelte con un nome che si capisce (il nome vero piccolo sotto),
  /// poi, per chi li conosce, tutti i modelli di Groq e quanto li hai usati.
  List<Widget> _modelChoices(BuildContext context, CoreState st, VoidCallback reload, {required bool speech}) {
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    final current = speech ? st.sttModel : st.llmModel;
    return [
      Text(
        speech ? 'Chi ascolta la tua voce e la scrive.' : 'Chi rilegge quello che hai detto e lo pulisce.',
        style: t.bodyMedium?.copyWith(color: tk.muted),
      ),
      const SizedBox(height: 20),
      for (final c in speech ? _sttChoices : _llmChoices)
        _Choice(
          title: c.label,
          hint: c.hint,
          subtitle: _short(c.id),
          selected: current == c.id,
          onTap: () async {
            HapticFeedback.selectionClick();
            await Core.setModel(c.id, speech: speech);
            reload();
          },
        ),
      const SizedBox(height: 28),
      Text(
        'PER CHI LI CONOSCE',
        style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: tk.muted),
      ),
      const SizedBox(height: 12),
      speech
          ? ModelPicker(
              label: 'Modello',
              current: st.sttModel,
              speech: true,
              recommended: _recommendedStt,
              load: _models,
              error: modelsError,
              onSaved: reload,
              usage: [
                _Meter(
                  label: 'Trascrizioni oggi',
                  value: '${st.sttUses}',
                  of: _requestLimit(st.sttLimits),
                  fraction: _fraction(st.sttUses, _requestLimit(st.sttLimits)),
                  resets: _midnight(),
                ),
                _Meter(
                  label: "Audio quest'ora",
                  value: '${(st.hourUsed / 60).round()}',
                  of: '${(st.hourLimit / 60).round()} min',
                  fraction: st.hourUsed / st.hourLimit,
                  resets: st.hourEnd,
                ),
                _Meter(
                  label: 'Audio oggi',
                  value: '${(st.dayUsed / 60).round()}',
                  of: '${(st.dayLimit / 60).round()} min',
                  fraction: st.dayUsed / st.dayLimit,
                  resets: st.dayEnd,
                ),
              ],
              note:
                  'Groq conta i minuti di audio, non il tempo che passa: '
                  "in un'ora puoi mandargli fino a 120 minuti di parlato.",
            )
          : ModelPicker(
              label: 'Modello',
              current: st.llmModel,
              speech: false,
              recommended: _recommendedLlm,
              load: _models,
              error: modelsError,
              onSaved: reload,
              usage: [
                _Meter(
                  label: 'Pulizie oggi',
                  value: '${st.llmUses}',
                  of: _requestLimit(st.llmLimits),
                  fraction: _fraction(st.llmUses, _requestLimit(st.llmLimits)),
                  resets: _midnight(),
                ),
              ],
            ),
    ];
  }

  static const _modeNames = {'fedele': 'Fedele', 'pulita': 'Pulita', 'riassunto': 'Riassunto'};

  @override
  Widget build(BuildContext context) {
    final st = s;
    return Paper(
      child: Scaffold(
        appBar: AppBar(),
        body: st == null
            ? const SizedBox.shrink()
            : ListView(
                // Sotto, anche lo spazio dei tasti di Android (i tre bottoni), se ci sono.
                padding: EdgeInsets.only(bottom: 40 + MediaQuery.viewPaddingOf(context).bottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text('Impostazioni', style: display(context)),
                  ),
                  SettingsGroup(
                    label: 'Dettatura',
                    children: [
                      SettingsRow(
                        icon: Icons.auto_fix_high_rounded,
                        color: Tokens.blue,
                        title: 'Pulisci il testo',
                        subtitle: 'Toglie esitazioni e ripetizioni, mette la punteggiatura',
                        trailing: Switch(value: st.purify, onChanged: _setPurify),
                        onTap: () => _setPurify(!st.purify),
                      ),
                      SettingsRow(
                        icon: Icons.tune_rounded,
                        color: Tokens.violet,
                        title: 'Come pulisce',
                        value: st.purify ? _modeNames[st.mode] : 'Spenta',
                        onTap: () => _open(
                          LiveSettings(
                            title: 'Come pulisce',
                            build: (context, st, reload) => [
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
                            ],
                          ),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.spellcheck_rounded,
                        color: Tokens.green,
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
                  SettingsGroup(
                    label: 'Modelli',
                    children: [
                      SettingsRow(
                        icon: Icons.graphic_eq_rounded,
                        color: Tokens.blue,
                        title: 'Trascrizione',
                        value: _choiceName(st.sttModel, _sttChoices),
                        onTap: () => _open(LiveSettings(title: 'Trascrizione', build: (c, st, r) => _modelChoices(c, st, r, speech: true))),
                      ),
                      SettingsRow(
                        icon: Icons.auto_awesome_rounded,
                        color: Tokens.violet,
                        title: 'Pulizia del testo',
                        value: _choiceName(st.llmModel, _llmChoices),
                        onTap: () =>
                            _open(LiveSettings(title: 'Pulizia del testo', build: (c, st, r) => _modelChoices(c, st, r, speech: false))),
                      ),
                      SettingsRow(
                        icon: Icons.bubble_chart_rounded,
                        color: Tokens.green,
                        title: 'Argomenti nelle note',
                        subtitle: 'Sul telefono, senza rete',
                        value: topicsOn ? topics : null,
                        trailing: Switch(value: topicsOn, onChanged: _setTopics),
                        onTap: () => _open(const TopicsSettings()),
                      ),
                    ],
                  ),
                  SettingsGroup(
                    label: 'Aiuto',
                    children: [
                      SettingsRow(
                        icon: Icons.school_rounded,
                        color: Tokens.yellow,
                        title: 'Rivedi come funziona',
                        onTap: () => Navigator.of(context).pop('intro'),
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
    _topicModels = list;
    topicsOn = chosen != null;
    setState(
      () => topics = chosen == null
          ? 'Spenti'
          : chosen.state == 'downloading'
          ? '${((chosen.progress ?? 0) * 100).round()}%'
          : chosen.label,
    );
  }

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
            'Transcri si chiude e non potrà trascrivere finché non ne metti un\'altra. Le trascrizioni e le note restano.',
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

    return [
      Text(
        'Dà accesso al tuo account Groq. Resta cifrata su questo telefono: non condividerla.',
        style: t.bodyMedium?.copyWith(color: tk.muted),
      ),
      const SizedBox(height: 20),
      Text(st.maskedKey ?? 'Nessuna chiave', style: monoStyle(context, size: 15, color: tk.text)),
      const SizedBox(height: 24),
      if (st.maskedKey == null)
        FilledButton(onPressed: change, child: const Text('Prendi la chiave'))
      else ...[
        OutlinedButton(onPressed: change, child: const Text('Cambia chiave')),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Tokens.red),
          onPressed: remove,
          child: const Text('Rimuovi la chiave'),
        ),
      ],
    ];
  }

  /// Le richieste al giorno, se Groq ce le ha dette nell'ultima risposta.
  static String? _requestLimit(Map<String, String> limits) => int.tryParse(limits['requests'] ?? '') == null ? null : limits['requests'];

  static double? _fraction(int used, String? limit) {
    final l = int.tryParse(limit ?? '');
    return l == null || l == 0 ? null : used / l;
  }
}

/// Campo bloccato col modello scelto; toccandolo si apre una rotella per cambiarlo.
/// Sotto, nello stesso riquadro, quanto l'hai usato.
class ModelPicker extends StatefulWidget {
  const ModelPicker({
    super.key,
    required this.label,
    required this.current,
    required this.speech,
    required this.recommended,
    required this.load,
    required this.error,
    required this.onSaved,
    required this.usage,
    this.note,
  });

  final String label, current;
  final bool speech;
  final List<String> recommended;
  final Future<List<GroqModel>?> Function() load;
  final String? error;
  final VoidCallback onSaved;
  final List<Widget> usage;
  final String? note;

  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<ModelPicker> {
  bool editing = false;
  bool loading = false;
  List<String> options = [];
  int index = 0;

  Future<void> _edit() async {
    setState(() => loading = true);
    final all = await widget.load();
    if (!mounted) return;
    if (all == null) return setState(() => loading = false);
    final ids = all.where((m) => m.speech == widget.speech).map((m) => m.id).toList();
    // Prima i consigliati, poi gli altri.
    final rec = widget.recommended.where(ids.contains).toList();
    final rest = ids.where((id) => !rec.contains(id)).toList();
    options = [...rec, ...rest];
    if (!options.contains(widget.current)) options.insert(0, widget.current);
    index = options.indexOf(widget.current);
    setState(() {
      loading = false;
      editing = true;
    });
  }

  Future<void> _save() async {
    await Core.setModel(options[index], speech: widget.speech);
    setState(() => editing = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(widget.label, style: t.titleMedium),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: editing ? _wheel(context) : _locked(context),
          ),
          if (widget.error != null) ...[const SizedBox(height: 8), Text(widget.error!, style: t.bodySmall?.copyWith(color: Tokens.red))],
          const SizedBox(height: 18),
          for (final (i, m) in widget.usage.indexed) ...[if (i > 0) const SizedBox(height: 14), m],
          if (widget.note != null) ...[const SizedBox(height: 12), Text(widget.note!, style: t.bodySmall?.copyWith(color: tk.faint))],
        ],
      ),
    );
  }

  Widget _locked(BuildContext context) {
    final tk = context.tk;
    return Material(
      color: tk.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : _edit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(widget.current, style: monoStyle(context, size: 13))),
              loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                  : Icon(Icons.unfold_more_rounded, size: 18, color: tk.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(color: tk.bg, borderRadius: BorderRadius.circular(12)),
          child: CupertinoPicker(
            itemExtent: 38,
            scrollController: FixedExtentScrollController(initialItem: index),
            selectionOverlay: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Tokens.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            ),
            onSelectedItemChanged: (i) => index = i,
            children: [
              for (final id in options)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          id,
                          style: monoStyle(context, size: 13, color: tk.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.recommended.take(3).contains(id)) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.star_rounded, size: 14, color: Tokens.blue),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton(onPressed: _save, child: const Text('Salva')),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => editing = false), child: const Text('Annulla')),
            const Spacer(),
            Icon(Icons.star_rounded, size: 12, color: tk.faint),
            const SizedBox(width: 3),
            Text('consigliati', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
              backgroundColor: tk.bg,
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
