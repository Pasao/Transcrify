import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/native.dart';
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

/// Le impostazioni in una pagina: modelli (ognuno con quanto l'hai usato), testo, chiave.
/// Restituisce 'removed' se la chiave è stata rimossa.
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

  Future<void> _replaceKey() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => KeyPage(replacing: true, onSaved: () => Navigator.of(ctx).pop()),
    ));
    _load();
  }

  Future<void> _removeKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovere la chiave?'),
        content: const Text('Transcri si chiude. Le trascrizioni restano.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rimuovi')),
        ],
      ),
    );
    if (ok != true) return;
    await Core.deleteKey();
    if (mounted) Navigator.of(context).pop('removed');
  }

  Future<void> _setPurify(bool on) async {
    await Core.setPurify(on);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final st = s;
    final t = Theme.of(context).textTheme;
    final tk = context.tk;
    return Scaffold(
      appBar: AppBar(),
      body: st == null
          ? const SizedBox.shrink()
          : ListView(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                child: Text('Impostazioni', style: display(context)),
              ),
              Section(label: 'Modelli', children: [
                ModelPicker(
                  label: 'Trascrizione',
                  current: st.sttModel,
                  speech: true,
                  recommended: _recommendedStt,
                  load: _models,
                  error: modelsError,
                  onSaved: _load,
                  usage: [
                    _Meter(
                      label: 'Trascrizioni oggi',
                      value: '${st.sttUses}',
                      of: _requestLimit(st.sttLimits),
                      fraction: _fraction(st.sttUses, _requestLimit(st.sttLimits)),
                    ),
                    _Meter(
                      label: 'Audio quest\'ora',
                      value: '${(st.hourUsed / 60).round()}',
                      of: '${(st.hourLimit / 60).round()} min',
                      fraction: st.hourUsed / st.hourLimit,
                    ),
                    _Meter(
                      label: 'Audio oggi',
                      value: '${(st.dayUsed / 60).round()}',
                      of: '${(st.dayLimit / 60).round()} min',
                      fraction: st.dayUsed / st.dayLimit,
                    ),
                  ],
                  note: 'Groq conta i minuti di audio, non il tempo che passa: '
                      'in un\'ora puoi mandargli fino a 120 minuti di parlato.',
                ),
                const SizedBox(height: 32),
                ModelPicker(
                  label: 'Pulizia del testo',
                  current: st.llmModel,
                  speech: false,
                  recommended: _recommendedLlm,
                  load: _models,
                  error: modelsError,
                  onSaved: _load,
                  usage: [
                    _Meter(
                      label: 'Pulizie oggi',
                      value: '${st.llmUses}',
                      of: _requestLimit(st.llmLimits),
                      fraction: _fraction(st.llmUses, _requestLimit(st.llmLimits)),
                    ),
                  ],
                ),
              ]),
              Section(label: 'Testo', children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pulisci il testo', style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text('Toglie esitazioni e ripetizioni, mette punteggiatura e paragrafi. '
                          'Si sceglie anche da Transcri, mentre detti.', style: t.bodySmall),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: st.purify, onChanged: _setPurify),
                ]),
                const SizedBox(height: 20),
                _ModeChooser(
                  mode: st.mode,
                  enabled: st.purify,
                  onChanged: (m) async {
                    await Core.setMode(m);
                    _load();
                  },
                ),
                const SizedBox(height: 24),
                PromptEditor(
                  key: ValueKey(st.mode),
                  prompt: st.prompt,
                  custom: st.customPrompt,
                  defaultPrompt: st.defaultPrompt,
                  enabled: st.purify,
                  onChanged: _load,
                ),
                const SizedBox(height: 28),
                WordsEditor(words: st.words, onChanged: _load),
              ]),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Tokens.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Tokens.red.withValues(alpha: 0.45)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Row(children: [
                      Icon(Icons.key_rounded, size: 18, color: Tokens.red),
                      SizedBox(width: 8),
                      Text('ZONA SENSIBILE',
                          style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Tokens.red)),
                    ]),
                    const SizedBox(height: 12),
                    Text('Chiave Groq', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text('Dà accesso al tuo account Groq. Non condividerla.', style: t.bodySmall),
                    const SizedBox(height: 12),
                    Text(st.maskedKey ?? '—', style: monoStyle(context, size: 14, color: tk.text)),
                    const SizedBox(height: 16),
                    Row(children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Tokens.red,
                          side: BorderSide(color: Tokens.red.withValues(alpha: 0.5)),
                        ),
                        onPressed: _replaceKey,
                        child: const Text('Cambia chiave'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Tokens.red, minimumSize: const Size(0, 40)),
                        onPressed: _removeKey,
                        child: const Text('Rimuovi'),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]),
    );
  }

  /// Le richieste al giorno, se Groq ce le ha dette nell'ultima risposta.
  static String? _requestLimit(Map<String, String> limits) =>
      int.tryParse(limits['requests'] ?? '') == null ? null : limits['requests'];

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text(widget.label, style: t.titleMedium)),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: editing ? _wheel(context) : _locked(context),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 8),
          Text(widget.error!, style: t.bodySmall?.copyWith(color: Tokens.red)),
        ],
        const SizedBox(height: 18),
        for (final (i, m) in widget.usage.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          m,
        ],
        if (widget.note != null) ...[
          const SizedBox(height: 12),
          Text(widget.note!, style: t.bodySmall?.copyWith(color: tk.faint)),
        ],
      ]),
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
          child: Row(children: [
            Expanded(child: Text(widget.current, style: monoStyle(context, size: 13))),
            loading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                : Icon(Icons.unfold_more_rounded, size: 18, color: tk.faint),
          ]),
        ),
      ),
    );
  }

  Widget _wheel(BuildContext context) {
    final tk = context.tk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 180,
        decoration: BoxDecoration(color: tk.bg, borderRadius: BorderRadius.circular(12)),
        child: CupertinoPicker(
          itemExtent: 38,
          scrollController: FixedExtentScrollController(initialItem: index),
          selectionOverlay: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Tokens.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onSelectedItemChanged: (i) => index = i,
          children: [
            for (final id in options)
              Center(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(id, style: monoStyle(context, size: 13, color: tk.text), overflow: TextOverflow.ellipsis),
                  ),
                  if (widget.recommended.take(3).contains(id)) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, size: 14, color: Tokens.blue),
                  ],
                ]),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        FilledButton(onPressed: _save, child: const Text('Salva')),
        const SizedBox(width: 8),
        TextButton(onPressed: () => setState(() => editing = false), child: const Text('Annulla')),
        const Spacer(),
        Icon(Icons.star_rounded, size: 12, color: tk.faint),
        const SizedBox(width: 3),
        Text('consigliati', style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Vocabolario', style: t.titleMedium),
      const SizedBox(height: 2),
      Text('Nomi, marchi e termini scritti come li vuoi tu. Li usa la pulizia del testo.', style: t.bodySmall),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final w in widget.words)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
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
            ]),
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
            avatar: const Icon(Icons.add_rounded, size: 16, color: Tokens.blue),
            label: const Text('Aggiungi'),
            labelStyle: const TextStyle(color: Tokens.blue, fontWeight: FontWeight.w600),
            side: BorderSide(color: Tokens.blue.withValues(alpha: 0.4)),
            shape: const StadiumBorder(),
            backgroundColor: Colors.transparent,
          ),
      ]),
    ]);
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 64,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: tk.surface, borderRadius: BorderRadius.circular(32)),
            child: LayoutBuilder(builder: (context, box) {
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
                child: Stack(children: [
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
                  Row(children: [
                    for (final m in _modes)
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          CustomPaint(size: const Size(18, 14), painter: ModeIcon(m.$1, m.$1 == mode ? Colors.white : tk.muted)),
                          const SizedBox(height: 5),
                          Text(m.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: m.$1 == mode ? Colors.white : tk.muted,
                              )),
                        ]),
                      ),
                  ]),
                ]),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(current.$3, style: t.bodySmall),
        ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Prompt della pulizia', style: t.titleMedium),
          const SizedBox(width: 8),
          Text(widget.custom ? 'tuo' : 'predefinito', style: monoStyle(context, color: tk.faint)),
        ]),
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
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Text(widget.prompt,
                              maxLines: 4, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: tk.faint)),
                        ),
                        const SizedBox(width: 8),
                        Icon(widget.enabled ? Icons.edit_rounded : Icons.lock_outline_rounded, size: 16, color: tk.faint),
                      ]),
                    ),
                  ),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: field,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 14,
                    style: t.bodySmall?.copyWith(color: tk.text, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    FilledButton(onPressed: _save, child: const Text('Salva')),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => setState(() => editing = false), child: const Text('Annulla')),
                    const Spacer(),
                    if (widget.custom) TextButton(onPressed: _reset, child: const Text('Predefinito')),
                  ]),
                ]),
        ),
        if (!widget.enabled && !editing) ...[
          const SizedBox(height: 6),
          Text('Si usa solo con la pulizia accesa.', style: t.bodySmall),
        ],
      ]),
    );
  }
}

/// Una misura: etichetta, numero grande, "di N" e, se c'è un limite, una barretta.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, this.of, this.fraction});

  final String label, value;
  final String? of;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(label, style: t.bodyMedium?.copyWith(color: tk.muted)),
        const Spacer(),
        Text(value, style: display(context, size: 20)),
        if (of != null) Text(' / $of', style: monoStyle(context)),
      ]),
      if (fraction != null) ...[
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction!.clamp(0, 1).toDouble(),
            minHeight: 5,
            backgroundColor: tk.bg,
            color: Tokens.blue,
          ),
        ),
      ],
    ]);
  }
}
