import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lo stato che arriva dal nucleo nativo (Kotlin).
class CoreState {
  CoreState(Map m)
    : hasKey = m['hasKey'] as bool,
      introSeen = m['introSeen'] as bool,
      maskedKey = m['maskedKey'] as String?,
      pillOn = m['pillOn'] as bool,
      purify = m['purify'] as bool,
      words = (m['words'] as List).cast<String>(),
      prompt = m['prompt'] as String,
      customPrompt = m['customPrompt'] as bool,
      defaultPrompt = m['defaultPrompt'] as String,
      mode = m['mode'] as String,
      limited = m['limited'] as String?,
      resetAt = m['resetAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['resetAt'] as int),
      simulateLimit = m['simulateLimit'] as bool,
      simOffline = m['simOffline'] as bool,
      simBadKey = m['simBadKey'] as bool,
      simNoMic = m['simNoMic'] as bool,
      sttModel = m['sttModel'] as String,
      llmModel = m['llmModel'] as String,
      sttLimits = (m['sttLimits'] as Map).cast<String, String>(),
      llmLimits = (m['llmLimits'] as Map).cast<String, String>(),
      sttUses = m['sttUses'] as int,
      llmUses = m['llmUses'] as int,
      hourUsed = m['hourUsed'] as int,
      dayUsed = m['dayUsed'] as int,
      accentMain = Color(m['accentMain'] as int),
      accentSecond = Color(m['accentSecond'] as int),
      accentA = Color(m['accentA'] as int),
      accentB = Color(m['accentB'] as int),
      hourEnd = _time(m['hourEnd']),
      dayEnd = _time(m['dayEnd']),
      hourLimit = m['hourLimit'] as int,
      dayLimit = m['dayLimit'] as int;

  final bool hasKey, pillOn, purify, customPrompt, simulateLimit;

  /// I guasti finti delle prove: niente rete, chiave rifiutata, microfono negato.
  final bool simOffline, simBadKey, simNoMic;

  /// L'introduzione è già stata vista o saltata.
  final bool introSeen;

  /// "fedele", "pulita" o "riassunto".
  final String mode;

  /// "hourly" o "daily" se i minuti sono finiti, e quando tornano.
  final String? limited;
  final DateTime? resetAt;
  final String? maskedKey;
  final List<String> words;
  final String prompt, defaultPrompt, sttModel, llmModel;
  final Map<String, String> sttLimits, llmLimits;
  final int hourUsed, dayUsed, hourLimit, dayLimit, sttUses, llmUses;

  /// Quando si azzerano i minuti dell'ora e del giorno; null se non hai ancora dettato niente.
  final DateTime? hourEnd, dayEnd;

  /// I colori di Transcri: l'accento del telefono, in due toni.
  final Color accentA, accentB;

  /// Il colore delle azioni nell'app (bottoni, interruttori, barrette): l'accento pieno del telefono.
  final Color accentMain, accentSecond;

  static DateTime? _time(Object? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
}

class Entry {
  Entry(Map m)
    : text = m['text'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
      purified = m['purified'] as bool,
      mode = m['mode'] as String?;

  final String text;
  final DateTime at;
  final bool purified;

  /// Il modo di pulizia usato ("fedele", "pulita", "riassunto"), null se è il testo così com'è.
  final String? mode;
}

/// Una nota: tua, da rileggere. Si scrive a mano (per ora); il titolo può restare vuoto.
class Note {
  Note({required this.id, this.title = '', this.text = '', required this.created, required this.updated, this.topics = 'off'});

  Note.fromMap(Map m)
    : id = m['id'] as String,
      title = m['title'] as String,
      text = m['text'] as String,
      created = DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      updated = DateTime.fromMillisecondsSinceEpoch(m['updated'] as int),
      topics = m['topics'] as String? ?? 'off';

  /// Una nota nuova, vuota, nata adesso.
  factory Note.blank() {
    final now = DateTime.now();
    return Note(id: '${now.microsecondsSinceEpoch}', created: now, updated: now);
  }

  final String id, title, text;
  final DateTime created, updated;

  /// Gli argomenti di questa nota: "off" (spenti o senza modello), "pending" (li sta facendo),
  /// "ready" (pronti per questo testo) o "stale" (la nota è cambiata: si rifanno al prossimo salvataggio).
  final String topics;

  bool get isEmpty => title.trim().isEmpty && text.trim().isEmpty;

  Note edited({required String title, required String text}) =>
      Note(id: id, title: title, text: text, created: created, updated: DateTime.now());

  Map<String, Object> toMap() => {
    'id': id,
    'title': title,
    'text': text,
    'created': created.millisecondsSinceEpoch,
    'updated': updated.millisecondsSinceEpoch,
  };
}

/// Gli argomenti di una nota: dove stanno le frasi (inizio e fine, in fila) e, per ogni grana,
/// dopo quali frasi cambia argomento. Le grane fini contengono sempre i confini di quelle larghe.
class NoteTopics {
  NoteTopics(Map m)
    : spans = (m['spans'] as List).cast<int>(),
      cuts = [(m['coarse'] as List).cast<int>(), (m['medium'] as List).cast<int>(), (m['fine'] as List).cast<int>()];

  final List<int> spans;

  /// [0] larga, [1] media, [2] fine.
  final List<List<int>> cuts;

  int get sentences => spans.length ~/ 2;

  /// I pezzi del testo a una grana (1 larga … 3 fine), come intervalli di caratteri.
  List<TextRange> pieces(int grain) {
    if (sentences == 0) return const [];
    final out = <TextRange>[];
    var from = 0;
    for (final c in cuts[grain - 1]) {
      out.add(TextRange(start: spans[2 * from], end: spans[2 * c + 1]));
      from = c + 1;
    }
    out.add(TextRange(start: spans[2 * from], end: spans[2 * (sentences - 1) + 1]));
    return out;
  }
}

/// Un modello per gli argomenti: si chiama «più preciso» o «più leggero»; il nome vero è scritto piccolo.
class TopicModelInfo {
  TopicModelInfo(Map m)
    : id = m['id'] as String,
      label = m['label'] as String,
      name = m['name'] as String,
      approxMb = m['approxMb'] as int,
      chosen = m['chosen'] as bool,
      state = m['state'] as String,
      done = (m['done'] as num?)?.toInt(),
      total = (m['total'] as num?)?.toInt(),
      error = m['error'] as String?;

  final String id, label, name;
  final int approxMb;
  final bool chosen;

  /// "missing", "downloading", "ready" o "failed".
  final String state;
  final int? done, total;
  final String? error;

  double? get progress => total == null || total == 0 ? null : done! / total!;
}

/// Una registrazione che aspetta di essere trascritta (di solito: mancava la rete).
class Waiting {
  Waiting(Map m)
    : id = m['id'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
      seconds = m['seconds'] as int,
      mode = m['mode'] as String?;

  final String id;
  final DateTime at;
  final int seconds;
  final String? mode;
}

class GroqModel {
  GroqModel(Map m) : id = m['id'] as String, owner = m['owner'] as String, context = m['context'] as int, speech = m['speech'] as bool;

  final String id, owner;
  final int context;
  final bool speech;
}

/// Tutte le chiamate al nucleo nativo passano da qui.
class Core {
  static const _ch = MethodChannel('transcrify/core');

  static final _changed = <VoidCallback>{};
  static ValueChanged<bool>? _nestHot;

  static void _listen() => _ch.setMethodCallHandler((call) async {
    if (call.method == 'changed') refresh();
    if (call.method == 'nestHot') _nestHot?.call(call.arguments as bool);
  });

  /// Chi vuole sapere quando la pillola cambia qualcosa (si accende, si spegne, trascrive).
  /// Ogni pagina si iscrive per conto suo e si toglie quando se ne va.
  static void addListener(VoidCallback cb) {
    _changed.add(cb);
    _listen();
  }

  static void removeListener(VoidCallback cb) => _changed.remove(cb);

  /// Fa rileggere tutto a chi è iscritto: quando cambia qualcosa, o al ritorno nell'app.
  static void refresh() {
    for (final cb in [..._changed]) {
      cb();
    }
  }

  /// Chiamato quando, trascinandolo, Transcri arriva sopra il nido dell'app o se ne allontana.
  static void onNestHot(ValueChanged<bool>? cb) {
    _nestHot = cb;
    _listen();
  }

  static List<double>? _nest;

  /// Dov'è il nido di Transcri sullo schermo (l, t, r, b in pixel fisici); null se non si vede.
  /// Con l'app aperta, trascinandolo, Transcri rientra lì invece che nella casa in basso.
  static Future<void> setNest(List<double>? rect) async {
    if (rect == null ? _nest == null : _nest != null && _sameRect(rect, _nest!)) return;
    _nest = rect;
    await _ch.invokeMethod('setNest', {'rect': rect});
  }

  /// L'app è andata in pausa e il nativo ha dimenticato il nido: la prossima volta si manda comunque.
  static void forgetNest() => _nest = null;

  static bool _sameRect(List<double> a, List<double> b) {
    for (var i = 0; i < 4; i++) {
      if ((a[i] - b[i]).abs() > 0.5) return false;
    }
    return true;
  }

  // --- Le prove (solo nella versione di sviluppo) ---

  /// L'app come la vede chi la apre la prima volta: niente chiave, niente note né trascrizioni,
  /// l'introduzione da vedere. I dati veri non si toccano: spegnendo la prova tornano tutti.
  static final preview = ValueNotifier<bool>(false);

  /// Nella prova: le note scritte e la chiave messa vivono solo in memoria.
  static final _previewNotes = <Note>[];
  static bool _previewIntro = false, _previewKey = false;

  /// Due registrazioni «in attesa» finte, per vedere quella parte senza staccare la rete.
  static final fakeWaiting = ValueNotifier<bool>(false);
  static final _fake = <Waiting>[];

  static void setPreview(bool on) {
    _previewNotes.clear();
    _previewIntro = false;
    _previewKey = false;
    preview.value = on;
    refresh();
  }

  static void setFakeWaiting(bool on) {
    final now = DateTime.now();
    _fake
      ..clear()
      ..addAll([
        if (on)
          Waiting({
            'id': 'prova-1',
            'at': now.subtract(const Duration(minutes: 12)).millisecondsSinceEpoch,
            'seconds': 40,
            'mode': 'pulita',
          }),
        if (on)
          Waiting({'id': 'prova-2', 'at': now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch, 'seconds': 185, 'mode': null}),
      ]);
    fakeWaiting.value = on;
    refresh();
  }

  static Future<CoreState> state() async {
    final m = Map<String, Object?>.from(await _ch.invokeMethod('state') as Map);
    if (preview.value) {
      m['hasKey'] = _previewKey;
      m['maskedKey'] = _previewKey ? 'gsk_••••••••prov' : null;
      m['introSeen'] = _previewIntro;
      m['words'] = <String>[];
    }
    return CoreState(m);
  }

  static Future<List<Entry>> history() async =>
      preview.value ? [] : ((await _ch.invokeMethod('history')) as List).map((e) => Entry(e as Map)).toList();

  static Future<List<Waiting>> waiting() async => [
    ..._fake,
    if (!preview.value) ...((await _ch.invokeMethod('pending')) as List).map((e) => Waiting(e as Map)),
  ];

  static Future<void> discardWaiting(String id) async {
    if (_fake.any((w) => w.id == id)) return _fake.removeWhere((w) => w.id == id);
    await _ch.invokeMethod('discardPending', {'id': id});
  }

  /// Prova a trascrivere quello che aspetta. Senza rete non succede niente: resta lì.
  static Future<void> flushWaiting() async {
    try {
      await _ch.invokeMethod('flushPending');
    } on PlatformException {
      // Ancora niente rete o un errore di Groq: si riproverà.
    }
  }

  static Future<void> deleteEntry(DateTime at) async {
    if (!preview.value) await _ch.invokeMethod('deleteHistory', {'at': at.millisecondsSinceEpoch});
  }

  static Future<void> setIntroSeen() async {
    if (preview.value) {
      _previewIntro = true;
    } else {
      await _ch.invokeMethod('introSeen');
    }
  }

  static Future<List<TopicModelInfo>> topicModels() async =>
      ((await _ch.invokeMethod('topicModels')) as List).map((e) => TopicModelInfo(e as Map)).toList();

  /// Sceglie il modello per gli argomenti (e lo scarica se manca). null = argomenti spenti.
  static Future<void> chooseTopicModel(String? id) => _ch.invokeMethod('chooseTopicModel', {'id': id});

  static Future<void> cancelTopicModel(String id) => _ch.invokeMethod('cancelTopicModel', {'id': id});

  static Future<void> deleteTopicModel(String id) => _ch.invokeMethod('deleteTopicModel', {'id': id});

  static Future<List<Note>> notes() async => preview.value
      ? ([..._previewNotes]..sort((a, b) => b.updated.compareTo(a.updated)))
      : ((await _ch.invokeMethod('notes')) as List).map((e) => Note.fromMap(e as Map)).toList();

  /// Salva una nota nuova o aggiorna quella con lo stesso id.
  static Future<void> saveNote(Note n) async {
    if (!preview.value) return _ch.invokeMethod('saveNote', n.toMap());
    _previewNotes
      ..removeWhere((x) => x.id == n.id)
      ..add(n);
  }

  /// Gli argomenti di una nota, se sono pronti per il testo che ha adesso.
  static Future<NoteTopics?> noteTopics(String id) async {
    if (preview.value) return null;
    final m = await _ch.invokeMethod('noteTopics', {'id': id}) as Map?;
    return m == null ? null : NoteTopics(m);
  }

  /// Nelle prove: il pizzico al contrario (stringere = più argomenti), per provare tutte e due le direzioni.
  static final pinchReversed = ValueNotifier<bool>(false);

  static Future<void> deleteNote(String id) async {
    if (!preview.value) return _ch.invokeMethod('deleteNote', {'id': id});
    _previewNotes.removeWhere((x) => x.id == id);
  }

  /// Prova la chiave con Groq. Restituisce null se va bene, altrimenti il motivo.
  static Future<String?> checkKey(String key) async {
    try {
      await _ch.invokeMethod('checkKey', {'key': key});
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  static Future<void> setKey(String key) async {
    // Nella prova la chiave si controlla davvero con Groq, ma non si salva: quella vera resta.
    if (preview.value) {
      _previewKey = true;
    } else {
      await _ch.invokeMethod('setKey', {'key': key});
    }
  }

  static Future<void> deleteKey() => _ch.invokeMethod('deleteKey');

  static Future<List<GroqModel>> models() async => ((await _ch.invokeMethod('models')) as List).map((e) => GroqModel(e as Map)).toList();

  static Future<void> setModel(String id, {required bool speech}) => _ch.invokeMethod('setModel', {'id': id, 'speech': speech});

  /// Fa dire a Groq i limiti di un modello mai usato (li dice solo nelle risposte). Una volta sola per modello.
  static Future<void> probeLimits(String id, {required bool speech}) async {
    try {
      await _ch.invokeMethod('probeLimits', {'id': id, 'speech': speech});
    } on PlatformException {
      // Senza rete: si riproverà la prossima volta.
    }
  }

  static Future<void> setWords(List<String> words) => _ch.invokeMethod('setWords', {'words': words});

  /// null = torna al prompt predefinito.
  static Future<void> setPrompt(String? prompt) => _ch.invokeMethod('setPrompt', {'prompt': prompt});

  static Future<void> setMode(String mode) => _ch.invokeMethod('setMode', {'mode': mode});

  /// Un guasto finto delle prove: 'offline', 'badKey' o 'noMic'.
  static Future<void> simulate(String what, bool on) => _ch.invokeMethod('simulate', {'what': what, 'on': on});

  static Future<void> simulateLimit(bool on) => _ch.invokeMethod('simulateLimit', {'on': on});

  static Future<void> setPurify(bool on) => _ch.invokeMethod('setPurify', {'on': on});

  static Future<bool> canDrawOverlays() async => await _ch.invokeMethod('canDrawOverlays') as bool;
  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');

  /// [x], [y] in pixel fisici dello schermo: da lì parte la bolla.
  /// Restituisce 'overlay' se manca il permesso di stare sopra le altre app.
  /// [home]: la capsula di Transcri nel bottone (l, t, r, b, in pixel fisici): parte da lì, con la sua forma.
  /// [place]: Transcri è stato portato a mano fin lì, quindi si attacca al bordo più vicino a quel punto.
  static Future<String?> startPill(double x, double y, {List<double>? home, bool place = false}) async =>
      await _ch.invokeMethod('startPill', {'x': x, 'y': y, 'home': home, 'place': place}) as String?;

  /// Con [x], [y] la pillola rientra volando in quel punto; senza, si chiude e basta.
  static Future<void> stopPill({double? x, double? y, List<double>? home}) => _ch.invokeMethod('stopPill', {'x': x, 'y': y, 'home': home});
}
