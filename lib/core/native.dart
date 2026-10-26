import 'package:flutter/services.dart';

/// Lo stato che arriva dal nucleo nativo (Kotlin).
class CoreState {
  CoreState(Map m)
      : hasKey = m['hasKey'] as bool,
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
        sttModel = m['sttModel'] as String,
        llmModel = m['llmModel'] as String,
        sttLimits = (m['sttLimits'] as Map).cast<String, String>(),
        llmLimits = (m['llmLimits'] as Map).cast<String, String>(),
        sttUses = m['sttUses'] as int,
        llmUses = m['llmUses'] as int,
        hourUsed = m['hourUsed'] as int,
        dayUsed = m['dayUsed'] as int,
        hourLimit = m['hourLimit'] as int,
        dayLimit = m['dayLimit'] as int;

  final bool hasKey, pillOn, purify, customPrompt, simulateLimit;

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
  GroqModel(Map m)
      : id = m['id'] as String,
        owner = m['owner'] as String,
        context = m['context'] as int,
        speech = m['speech'] as bool;

  final String id, owner;
  final int context;
  final bool speech;
}

/// Tutte le chiamate al nucleo nativo passano da qui.
class Core {
  static const _ch = MethodChannel('transcrify/core');

  /// Chiamato quando la pillola cambia qualcosa (si accende, si spegne, trascrive).
  static void onChanged(VoidCallback cb) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'changed') cb();
    });
  }

  static Future<CoreState> state() async => CoreState(await _ch.invokeMethod('state'));

  static Future<List<Entry>> history() async =>
      ((await _ch.invokeMethod('history')) as List).map((e) => Entry(e as Map)).toList();

  static Future<List<Waiting>> waiting() async =>
      ((await _ch.invokeMethod('pending')) as List).map((e) => Waiting(e as Map)).toList();

  static Future<void> discardWaiting(String id) => _ch.invokeMethod('discardPending', {'id': id});

  /// Prova a trascrivere quello che aspetta. Senza rete non succede niente: resta lì.
  static Future<void> flushWaiting() async {
    try {
      await _ch.invokeMethod('flushPending');
    } on PlatformException {
      // Ancora niente rete o un errore di Groq: si riproverà.
    }
  }

  static Future<void> deleteEntry(DateTime at) =>
      _ch.invokeMethod('deleteHistory', {'at': at.millisecondsSinceEpoch});

  /// Prova la chiave con Groq. Restituisce null se va bene, altrimenti il motivo.
  static Future<String?> checkKey(String key) async {
    try {
      await _ch.invokeMethod('checkKey', {'key': key});
      return null;
    } on PlatformException catch (e) {
      return e.message;
    }
  }

  static Future<void> setKey(String key) => _ch.invokeMethod('setKey', {'key': key});
  static Future<void> deleteKey() => _ch.invokeMethod('deleteKey');

  static Future<List<GroqModel>> models() async =>
      ((await _ch.invokeMethod('models')) as List).map((e) => GroqModel(e as Map)).toList();

  static Future<void> setModel(String id, {required bool speech}) =>
      _ch.invokeMethod('setModel', {'id': id, 'speech': speech});

  static Future<void> setWords(List<String> words) => _ch.invokeMethod('setWords', {'words': words});

  /// null = torna al prompt predefinito.
  static Future<void> setPrompt(String? prompt) => _ch.invokeMethod('setPrompt', {'prompt': prompt});

  static Future<void> setMode(String mode) => _ch.invokeMethod('setMode', {'mode': mode});
  static Future<void> simulateLimit(bool on) => _ch.invokeMethod('simulateLimit', {'on': on});

  static Future<void> setPurify(bool on) => _ch.invokeMethod('setPurify', {'on': on});

  static Future<bool> canDrawOverlays() async => await _ch.invokeMethod('canDrawOverlays') as bool;
  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');

  /// [x], [y] in pixel fisici dello schermo: da lì parte la bolla.
  /// Restituisce 'overlay' se manca il permesso di stare sopra le altre app.
  /// [home]: la capsula di Transcri nel bottone (l, t, r, b, in pixel fisici): parte da lì, con la sua forma.
  static Future<String?> startPill(double x, double y, {List<double>? home}) async =>
      await _ch.invokeMethod('startPill', {'x': x, 'y': y, 'home': home}) as String?;

  /// Con [x], [y] la pillola rientra volando in quel punto; senza, si chiude e basta.
  static Future<void> stopPill({double? x, double? y, List<double>? home}) =>
      _ch.invokeMethod('stopPill', {'x': x, 'y': y, 'home': home});
}
