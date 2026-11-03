// Quanto manca al design system: conta, file per file, i valori ancora scritti a mano.
//
//   dart run tool/ds_rimasti.dart            riassunto per file
//   dart run tool/ds_rimasti.dart --righe    anche le righe, per sapere dove mettere le mani
//   dart run tool/ds_rimasti.dart --tetto    salva i conteggi di adesso come tetto (test/regole_tetto.json)
//
// Lo stesso conteggio lo usa test/regole_test.dart: i numeri possono solo scendere.
import 'dart:convert';
import 'dart:io';

/// Dove si cerca: il codice Flutter e il Kotlin.
const cartelle = ['lib', 'android/app/src/main/kotlin'];

/// Dove i valori DEVONO stare: le fondamenta e la fonte dei colori. Qui non si conta.
const fonti = ['lib/ui/ds/', 'lib/ui/ds.dart', 'Token.kt', 'Seme.kt', 'Caratteri.kt', 'Forme.kt', 'Durate.kt'];

/// Eccezioni dichiarate per file intero: il movimento di Transcri (volo, magnete, onda, respiro) è suo.
const eccezioniFile = {
  'lib/ui/transcri.dart': {'durate'},
  'android/app/src/main/kotlin/com/pasao/transcrify/PillUi.kt': {'durate'},
};

/// Cosa conta come «scritto a mano».
final categorie = <String, RegExp>{
  'colori': RegExp(r'Color\(0x|Colors\.(?!transparent)\w+|colorResource\(|R\.color\.'),
  'nomi vecchi': RegExp(r'Tokens\.(blue|violet|red|green|yellow)|\btk\.(bg|surface|border|text|muted|faint)\b'),
  'testi': RegExp(r'fontSize\s*[:=]|\.sp\b'),
  'raggi': RegExp(r'circular\(\s*\d|cornerRadius|RoundedCornerShape\(\s*\d'),
  'durate': RegExp(r'milliseconds:\s*\d|tween\(\s*\d|Duration\(seconds'),
  'ombre': RegExp(r'BoxShadow\(|shadow\('),
};

/// I file del progetto da controllare, con il percorso relativo (barre dritte).
List<(String, File)> fileDa(Directory radice) {
  final out = <(String, File)>[];
  for (final c in cartelle) {
    final d = Directory('${radice.path}/$c');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') && !f.path.endsWith('.kt')) continue;
      final rel = f.path.substring(radice.path.length + 1).replaceAll('\\', '/');
      out.add((rel, f));
    }
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

bool _commento(String r) {
  final t = r.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*') || t.startsWith('import ');
}

/// Per ogni file (fuori dalle fonti): categoria → quante volte. Con [righe] raccoglie anche dove.
Map<String, Map<String, int>> conta(Directory radice, {List<String>? righe}) {
  final out = <String, Map<String, int>>{};
  for (final (rel, f) in fileDa(radice)) {
    if (fonti.any(rel.contains)) continue;
    final conti = <String, int>{};
    final linee = f.readAsLinesSync();
    for (var i = 0; i < linee.length; i++) {
      // Le eccezioni dichiarate: `// ds:eccezione: motivo` sulla riga (il disegno di Transcri, la testata dell'introduzione…).
      if (_commento(linee[i]) || linee[i].contains('ds:eccezione')) continue;
      for (final MapEntry(key: k, value: rx) in categorie.entries) {
        if (eccezioniFile[rel]?.contains(k) ?? false) continue;
        final n = rx.allMatches(linee[i]).length;
        if (n == 0) continue;
        conti[k] = (conti[k] ?? 0) + n;
        righe?.add('$rel:${i + 1} [$k] ${linee[i].trim()}');
      }
    }
    if (conti.isNotEmpty) out[rel] = conti;
  }
  return out;
}

void main(List<String> args) {
  final radice = Directory.current;
  final righe = args.contains('--righe') ? <String>[] : null;
  final conti = conta(radice, righe: righe);
  final totale = <String, int>{};
  for (final MapEntry(key: f, value: c) in conti.entries) {
    stdout.writeln('$f: ${c.entries.map((e) => '${e.key} ${e.value}').join(', ')}');
    c.forEach((k, v) => totale[k] = (totale[k] ?? 0) + v);
  }
  if (righe != null) righe.forEach(stdout.writeln);
  stdout.writeln('\nTOTALE: ${categorie.keys.map((k) => '$k ${totale[k] ?? 0}').join(', ')}');
  if (args.contains('--tetto')) {
    // Il tetto si può solo abbassare: se un numero è salito, prima si sistema il codice.
    final f = File('${radice.path}/test/regole_tetto.json');
    final vecchio = f.existsSync() ? (jsonDecode(f.readAsStringSync()) as Map) : const {};
    final saliti = [
      for (final MapEntry(key: file, value: c) in conti.entries)
        for (final MapEntry(key: k, value: n) in c.entries)
          if (n > ((vecchio[file] as Map?)?[k] as int? ?? 0)) '$file: $k $n (era ${(vecchio[file] as Map?)?[k] ?? 0})',
    ];
    if (saliti.isNotEmpty) {
      stderr.writeln('Il tetto non si alza. Sono saliti:');
      for (final r in saliti) {
        stderr.writeln('  $r');
      }
      stderr.writeln('Usa i token di lib/ui/ds/ (o Caratteri.kt, Token.kt) e riprova.');
      exitCode = 1;
      return;
    }
    f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(conti));
    stdout.writeln('Tetto salvato in test/regole_tetto.json');
  }
}
