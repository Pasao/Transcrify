import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'segni.dart';

export 'segni.dart';

/// Lo stato che arriva dal nucleo nativo (Kotlin).
class CoreState {
  CoreState(Map m)
    : hasKey = m['hasKey'] as bool,
      introSeen = m['introSeen'] as bool,
      maskedKey = m['maskedKey'] as String?,
      pillOn = m['pillOn'] as bool,
      sandbox = m['sandbox'] as bool,
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
      provaRespiro = m['provaRespiro'] as bool,
      sttModel = m['sttModel'] as String,
      llmModel = m['llmModel'] as String,
      sttLimits = (m['sttLimits'] as Map).cast<String, String>(),
      llmLimits = (m['llmLimits'] as Map).cast<String, String>(),
      sttUses = m['sttUses'] as int,
      llmUses = m['llmUses'] as int,
      hourUsed = m['hourUsed'] as int,
      dayUsed = m['dayUsed'] as int,
      tokenChiaro = m['tokenChiaro'] as Map,
      tokenScuro = m['tokenScuro'] as Map,
      hourEnd = _time(m['hourEnd']),
      dayEnd = _time(m['dayEnd']),
      hourLimit = m['hourLimit'] as int,
      dayLimit = m['dayLimit'] as int;

  final bool hasKey, pillOn, purify, customPrompt, simulateLimit;

  /// L'app sta usando i dati finti delle prove: quelli veri sono da parte.
  final bool sandbox;

  /// I guasti finti delle prove: niente rete, chiave rifiutata, microfono negato.
  final bool simOffline, simBadKey, simNoMic;

  /// Il successo di Transcri: «l'ultimo respiro» (true) o il salto di prima (false). Una prova, come i guasti finti.
  final bool provaRespiro;

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



  /// I 26 token del design system, calcolati nel Kotlin (Token.kt, la fonte unica) dal colore del telefono.
  final Map tokenChiaro, tokenScuro;


  static DateTime? _time(Object? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);
}

class Entry {
  Entry(Map m)
    : text = m['text'] as String,
      at = DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
      purified = m['purified'] as bool,
      mode = m['mode'] as String?,
      source = m['source'] as String?,
      colore = Colore.da(m['colore'] as String?),
      privata = m['privata'] as bool? ?? false,
      titolo = m['titolo'] as String?;

  final String text;
  final DateTime at;
  final bool purified;

  /// Da dove arriva, se è un audio condiviso: il pacchetto dell'app (vedi [Core.provenienza]). Null se l'hai dettata tu.
  final String? source;

  /// Il modo di pulizia usato ("fedele", "pulita", "riassunto"), null se è il testo così com'è.
  final String? mode;

  /// Il suo colore (uno solo), null se non ne ha. Le trascrizioni di prima dei colori non ne hanno.
  final Colore? colore;

  /// Privata: sulla scheda il testo è coperto, e la ricerca non lo mostra.
  final bool privata;

  /// Il suo titolo (6 nov): scritto da te, o proposto dal riassunto estrattivo (`Titoli`). Null finché non ne ha uno:
  /// sulla scheda si vede l'inizio del testo (vedi `Titoli.di`).
  final String? titolo;

  /// Uguale se non è cambiato niente: rileggendo dal nativo, la lista si ridisegna solo se serve.
  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.at == at &&
      other.text == text &&
      other.purified == purified &&
      other.mode == mode &&
      other.source == source &&
      other.colore == colore &&
      other.privata == privata &&
      other.titolo == titolo;

  @override
  int get hashCode => Object.hash(at, text, purified, mode, source, colore, privata, titolo);

  /// Com'è, per rimetterla tale e quale (l'«Annulla» dopo averle unite).
  Map<String, Object?> toMap() => {
    'text': text,
    'at': at.millisecondsSinceEpoch,
    'purified': purified,
    'mode': mode,
    'source': source,
    'colore': colore?.chiave,
    'privata': privata,
    'titolo': titolo,
  };
}

/// Una nota: tua, da rileggere. Si scrive a mano (per ora); il titolo può restare vuoto.
class Note {
  Note({required this.id, this.title = '', this.text = '', required this.created, required this.updated, this.topics = 'off', this.source, this.summary});

  Note.fromMap(Map m)
    : id = m['id'] as String,
      title = m['title'] as String,
      text = m['text'] as String,
      created = DateTime.fromMillisecondsSinceEpoch(m['created'] as int),
      updated = DateTime.fromMillisecondsSinceEpoch(m['updated'] as int),
      topics = m['topics'] as String? ?? 'off',
      source = m['source'] as String?,
      summary = m['summary'] as String?;

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

  /// Da dove arriva, se è nata da un audio condiviso: il pacchetto dell'app (vedi [Core.provenienza]).
  final String? source;

  /// Il riassunto, se l'hai chiesto. Sta accanto al testo e non lo sostituisce mai.
  final String? summary;

  bool get isEmpty => title.trim().isEmpty && text.trim().isEmpty;

  /// Uguale se non è cambiato niente (anche lo stato degli argomenti): la lista si ridisegna solo se serve.
  @override
  bool operator ==(Object other) =>
      other is Note && other.id == id && other.updated == updated && other.created == created && other.topics == topics && other.title == title && other.text == text && other.source == source && other.summary == summary;

  @override
  int get hashCode => Object.hash(id, updated, topics, title, text);

  Note edited({required String title, required String text, String? summary}) =>
      Note(id: id, title: title, text: text, created: created, updated: DateTime.now(), source: source, summary: summary);

  Map<String, Object?> toMap() => {
    'source': source,
    'summary': summary,
    'id': id,
    'title': title,
    'text': text,
    'created': created.millisecondsSinceEpoch,
    'updated': updated.millisecondsSinceEpoch,
  };
}

/// Gli argomenti di una nota: dove stanno le frasi (inizio e fine, in fila), dopo quali frasi
/// cambia argomento alla grana larga e a quella media, e dove sono le parole chiave.
class NoteTopics {
  NoteTopics(Map m)
    : spans = (m['spans'] as List).cast<int>(),
      _cuts = (m['medium'] as List).cast<int>(),
      _gruppi = (m['groups'] as List).cast<int>(),
      keys = (m['keys'] as List).cast<int>(),
      keywords = (m['keywords'] as List).cast<int>();

  final List<int> spans;

  /// I confini tra i pezzi: dopo quale frase cambia argomento.
  final List<int> _cuts;

  /// Il gruppo di senso di ogni pezzo: i pezzi che dicono cose simili hanno lo stesso (il motore, `NoteTopics.groups`).
  final List<int> _gruppi;

  /// Le frasi chiave: per ogni pezzo, la frase che gli somiglia di più (indici di frase).
  final List<int> keys;

  /// Le parole chiave: coppie inizio–fine.
  final List<int> keywords;

  /// Le frasi chiave come intervalli di caratteri.
  List<TextRange> get keyRanges => [for (final i in keys) TextRange(start: spans[2 * i], end: spans[2 * i + 1])];

  int get sentences => spans.length ~/ 2;

  /// Il gruppo di senso del pezzo [i] (da 0): lo stesso colore per i pezzi che dicono cose simili.
  int gruppo(int i) => i < _gruppi.length ? _gruppi[i] : i;

  /// I pezzi del testo, uno per argomento, come intervalli di caratteri.
  List<TextRange> get pieces {
    if (sentences == 0) return const [];
    final out = <TextRange>[];
    var from = 0;
    for (final c in _cuts) {
      out.add(TextRange(start: spans[2 * from], end: spans[2 * c + 1]));
      from = c + 1;
    }
    out.add(TextRange(start: spans[2 * from], end: spans[2 * (sentences - 1) + 1]));
    return out;
  }
}

/// Un album: un argomento che torna in più note, con un nome fatto delle sue parole chiave.
class Album {
  Album(Map m)
    : id = (m['id'] as num).toInt(),
      name = m['name'] as String,
      concetto = (m['concetto'] as num?)?.toInt() ?? -1,
      concettoNome = m['concettoNome'] as String? ?? m['name'] as String,
      pieces = [
        for (final p in (m['pieces'] as List).cast<Map>())
          (note: p['note'] as String, range: TextRange(start: p['start'] as int, end: p['end'] as int)),
      ];

  final int id;
  final String name;

  /// Il grande concetto a cui appartiene (Argomenti a due livelli): gli album con lo stesso numero stanno insieme.
  final int concetto;

  /// Il nome del concetto: la parola che conta di più in tutti i suoi album.
  final String concettoNome;
  final List<({String note, TextRange range})> pieces;

  int get notes => pieces.map((p) => p.note).toSet().length;

  @override
  bool operator ==(Object other) => other is Album && other.id == id && other.name == name && other.concetto == concetto && other.concettoNome == concettoNome && listEquals(other.pieces, pieces);

  @override
  int get hashCode => Object.hash(id, name, concetto, concettoNome, pieces.length);
}

/// Un modello per gli argomenti: si chiama «più preciso» o «più leggero»; il nome vero è scritto piccolo.
class TopicModelInfo {
  TopicModelInfo(Map m)
    : id = m['id'] as String,
      label = m['label'] as String,
      name = m['name'] as String,
      approxMb = m['approxMb'] as int,
      chosen = m['chosen'] as bool,
      ramGb = (m['ramGb'] as num?)?.toDouble() ?? 8,
      state = m['state'] as String,
      done = (m['done'] as num?)?.toInt(),
      total = (m['total'] as num?)?.toInt(),
      error = m['error'] as String?;

  final String id, label, name;
  final int approxMb;
  final bool chosen;

  /// Quanta memoria ha il telefono (GB): sotto i 6 il più preciso può essere lento.
  final double ramGb;

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

/// Cosa sta facendo Transcri adesso: "IDLE", "RECORDING", "PROCESSING", "SUCCESS", "ERROR", "LIMITED".
class Live {
  const Live({this.phase = 'IDLE', this.level = 0, this.appendTo, this.error, this.paused = false, this.seconds = 0});

  Live.fromMap(Map m)
    : phase = m['phase'] as String,
      level = (m['level'] as num).toDouble(),
      appendTo = (m['appendTo'] as num?)?.toInt(),
      error = m['error'] as String?,
      paused = m['paused'] as bool? ?? false,
      seconds = (m['seconds'] as num?)?.toInt() ?? 0;

  final String phase;

  /// Il volume della voce, da 0 a 1.
  final double level;

  /// La trascrizione a cui si sta aggiungendo (in millisecondi, come la sua data), se c'è.
  final int? appendTo;
  final String? error;

  /// In pausa (sta ancora ascoltando, ma fermo), e da quanti secondi ascolta.
  final bool paused;
  final int seconds;

  bool get listening => phase == 'RECORDING';
}

/// Tutte le chiamate al nucleo nativo passano da qui.
/// L'app da cui è arrivato un audio condiviso: il nome («WhatsApp») e la sua icona (PNG), se si conoscono.
class Provenienza {
  const Provenienza(this.nome, this.icona);

  final String? nome;
  final Uint8List? icona;
}

class Core {
  static const _ch = MethodChannel('transcrify/core');

  /// Nome e icona dell'app di un audio condiviso: si chiedono una volta per app, poi restano in memoria.
  static Future<Provenienza> provenienza(String source) => _provenienze[source] ??= _ch
      .invokeMapMethod<String, Object?>('provenienza', {'source': source})
      .then((m) => _pronte[source] = Provenienza(m?['nome'] as String?, m?['icona'] as Uint8List?));
  static final _provenienze = <String, Future<Provenienza>>{};

  /// La provenienza se è già arrivata: una scheda che compare scorrendo ha subito la sua icona.
  static Provenienza? provenienzaPronta(String source) => _pronte[source];
  static final _pronte = <String, Provenienza>{};

  static final _changed = <VoidCallback>{};
  static ValueChanged<bool>? _nestHot;

  static void _listen() => _ch.setMethodCallHandler((call) async {
    if (call.method == 'changed') refresh();
    if (call.method == 'nestHot') _nestHot?.call(call.arguments as bool);
    if (call.method == 'live') live.value = Live.fromMap(call.arguments as Map);
  });

  /// Chi vuole sapere quando la pillola cambia qualcosa (si accende, si spegne, trascrive).
  /// Ogni pagina si iscrive per conto suo e si toglie quando se ne va.
  static void addListener(VoidCallback cb) {
    _changed.add(cb);
    _listen();
  }

  static void removeListener(VoidCallback cb) => _changed.remove(cb);

  /// Quello che Transcri sta facendo adesso: lo stato e il volume della voce.
  static final live = ValueNotifier<Live>(const Live());

  /// Comincia ad ascoltare dentro l'app. Se esci, Transcri vola fuori e continua.
  /// [appendTo]: quello che senti finisce in questa trascrizione, alla posizione [cursor] (-1 = in fondo).
  /// [panel]: dove aprire subito il player (l, t, r, b, in pixel fisici).
  static Future<void> listen({DateTime? appendTo, int cursor = -1, List<double>? panel}) =>
      _ch.invokeMethod('listen', {'appendTo': appendTo?.millisecondsSinceEpoch, 'cursor': cursor, 'panel': panel});

  /// Il foglio della trascrizione si chiude mentre «Detta qui» detta: la pillola torna sul bordo (il nativo la
  /// nasconde da solo mentre si detta nell'app, e la rimette a fine dettatura o se l'app va via).
  static Future<void> lasciaDettatura() async {
    if (!preview.value) await _ch.invokeMethod('lasciaDettatura');
  }

  /// Apre il player del Floater (butta, ferma, pausa, modi) vicino a [rect] (l, t, r, b, in pixel fisici).
  /// La pagina della trasparenza (nativa): la pillola, il Floater e la casa sul tuo sfondo, con lo slider.
  static Future<void> openTrasparenza() => _ch.invokeMethod('openTrasparenza');

  static Future<void> openPanel(List<double> rect) => _ch.invokeMethod('openPanel', {'rect': rect});

  static Future<void> stopListening() => _ch.invokeMethod('stopListening');

  static Future<void> discardListening() => _ch.invokeMethod('discardListening');
  static Future<void> togglePause() => _ch.invokeMethod('togglePause');

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

  /// Nella prova: le tue scelte non si vedono e non si toccano, quelle fatte lì vivono solo in memoria.
  static final _previewChoices = <String, Object?>{};

  /// Nella prova i permessi partono tutti spenti, e «darli» è finto: quelli veri restano come sono.
  static final _previewGranted = <String>{};

  static void previewGrant(String name) => _previewGranted.add(name);

  static Future<bool> micGranted() async => preview.value ? _previewGranted.contains('mic') : Permission.microphone.isGranted;

  static Future<bool> notificationsGranted() async =>
      preview.value ? _previewGranted.contains('notifications') : Permission.notification.isGranted;

  static void setPreview(bool on) {
    _previewChoices.clear();
    _previewGranted.clear();
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
      m.addAll({
        'words': <String>[],
        'purify': false,
        'mode': 'pulita',
        'prompt': m['promptDefault'],
        'defaultPrompt': m['promptDefault'],
        'customPrompt': false,
        'sttModel': m['sttDefault'],
        'llmModel': m['llmDefault'],
        'sttLimits': <String, String>{},
        'llmLimits': <String, String>{},
        'sttUses': 0,
        'llmUses': 0,
        'hourUsed': 0,
        'dayUsed': 0,
        'hourEnd': null,
        'dayEnd': null,
        'limited': null,
        'resetAt': null,
        ..._previewChoices,
      });
    }
    live.value = m['live'] == null ? const Live() : Live.fromMap(m['live'] as Map);
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

  static Future<void> editEntry(DateTime at, String text) async {
    if (!preview.value) await _ch.invokeMethod('editHistory', {'at': at.millisecondsSinceEpoch, 'text': text});
  }

  /// Il riassunto di un testo, fatto col modello di pulizia. Lancia un errore se non riesce.
  static Future<String> summarize(String text) async => await _ch.invokeMethod('summarize', {'text': text}) as String;

  static Future<void> setIntroSeen() async {
    if (preview.value) {
      _previewIntro = true;
    } else {
      await _ch.invokeMethod('introSeen');
    }
  }

  static Future<List<TopicModelInfo>> topicModels() async => ((await _ch.invokeMethod('topicModels')) as List).map((e) {
    final m = Map<Object?, Object?>.from(e as Map);
    if (preview.value) m.addAll({'chosen': false, 'state': 'missing', 'done': null, 'total': null, 'error': null});
    return TopicModelInfo(m);
  }).toList();

  /// Sceglie il modello per gli argomenti (e lo scarica se manca). null = argomenti spenti.
  static Future<void> chooseTopicModel(String? id) async {
    if (!preview.value) await _ch.invokeMethod('chooseTopicModel', {'id': id});
  }

  static Future<void> cancelTopicModel(String id) async {
    if (!preview.value) await _ch.invokeMethod('cancelTopicModel', {'id': id});
  }

  static Future<void> deleteTopicModel(String id) async {
    if (!preview.value) await _ch.invokeMethod('deleteTopicModel', {'id': id});
  }

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

  /// Gli album: argomenti che tornano in più note.
  static Future<List<Album>> albums() async {
    if (preview.value) return [];
    return ((await _ch.invokeMethod('albums')) as List).map((e) => Album(e as Map)).toList();
  }

  /// Nelle prove: il pizzico al contrario (stringere = più argomenti), per provare tutte e due le direzioni.
  static final pinchReversed = ValueNotifier<bool>(false);

  /// Nelle prove: la pagina Argomenti accanto alle Note (7 nov: nascosta, «troppo»). Il codice resta.
  static final mostraArgomenti = ValueNotifier<bool>(false);

  /// Apre il «Condividi» di Android col testo.
  static Future<void> share(String text) => _ch.invokeMethod('share', {'text': text});

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

  static Future<void> setModel(String id, {required bool speech}) async {
    if (preview.value) {
      _previewChoices[speech ? 'sttModel' : 'llmModel'] = id;
    } else {
      await _ch.invokeMethod('setModel', {'id': id, 'speech': speech});
    }
  }

  /// Fa dire a Groq i limiti di un modello mai usato (li dice solo nelle risposte). Una volta sola per modello.
  static Future<void> probeLimits(String id, {required bool speech}) async {
    try {
      await _ch.invokeMethod('probeLimits', {'id': id, 'speech': speech});
    } on PlatformException {
      // Senza rete: si riproverà la prossima volta.
    }
  }

  static Future<void> setWords(List<String> words) async {
    if (preview.value) {
      _previewChoices['words'] = words;
    } else {
      await _ch.invokeMethod('setWords', {'words': words});
    }
  }

  /// null = torna al prompt predefinito.
  static Future<void> setPrompt(String? prompt) async {
    if (!preview.value) await _ch.invokeMethod('setPrompt', {'prompt': prompt});
  }

  static Future<void> setMode(String mode) async {
    if (preview.value) {
      _previewChoices['mode'] = mode;
    } else {
      await _ch.invokeMethod('setMode', {'mode': mode});
    }
  }

  /// Un guasto finto delle prove: 'offline', 'badKey' o 'noMic'.
  static Future<void> simulate(String what, bool on) => _ch.invokeMethod('simulate', {'what': what, 'on': on});

  /// Passa ai dati finti o torna a quelli veri. L'app si riavvia.
  static Future<void> setSandbox(bool on) => _ch.invokeMethod('setSandbox', {'on': on});

  static Future<void> simulateLimit(bool on) => _ch.invokeMethod('simulateLimit', {'on': on});

  static Future<void> setPurify(bool on) async {
    if (preview.value) {
      _previewChoices['purify'] = on;
    } else {
      await _ch.invokeMethod('setPurify', {'on': on});
    }
  }

  static Future<bool> canDrawOverlays() async =>
      preview.value ? _previewGranted.contains('overlay') : await _ch.invokeMethod('canDrawOverlays') as bool;

  static Future<void> openOverlaySettings() async {
    if (preview.value) {
      previewGrant('overlay');
      refresh();
    } else {
      await _ch.invokeMethod('openOverlaySettings');
    }
  }

  /// [x], [y] in pixel fisici dello schermo: da lì parte la bolla.
  /// Restituisce 'overlay' se manca il permesso di stare sopra le altre app.
  /// [home]: la capsula di Transcri nel bottone (l, t, r, b, in pixel fisici): parte da lì, con la sua forma.
  /// [place]: Transcri è stato portato a mano fin lì, quindi si attacca al bordo più vicino a quel punto.
  static Future<String?> startPill(double x, double y, {List<double>? home, bool place = false}) async =>
      await _ch.invokeMethod('startPill', {'x': x, 'y': y, 'home': home, 'place': place}) as String?;

  /// Con [x], [y] la pillola rientra volando in quel punto; senza, si chiude e basta.
  static Future<void> stopPill({double? x, double? y, List<double>? home}) => _ch.invokeMethod('stopPill', {'x': x, 'y': y, 'home': home});
}
