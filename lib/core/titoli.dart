import 'native.dart';
import 'orario.dart';

/// I titoli delle trascrizioni (6 nov, sua idea: sulla scheda, in fondo, il titolo). Si salvano nel nativo con la
/// trascrizione (`Entry.titolo`).
///
/// Dal 7 nov li scrive Groq, una volta sola per trascrizione, in fondo: subito dopo una nuova, e piano piano quelle di
/// prima, dalla più recente (`Titolatore.kt`). Mai sopra un titolo tuo. Finché non c'è, la scheda mostra
/// l'inizio del testo, più tenue ([provvisorio]).
abstract final class Titoli {
  /// Quante parole al massimo nell'inizio del testo che fa le veci del titolo.
  static const parole = 5;

  /// Quello che si vede sulla scheda: il titolo o, senza, l'inizio del testo. Offuscata il titolo resta (7 nov, sua
  /// richiesta: «i titoli delle cose private restano, per orientarti»); senza titolo, finché Groq non lo scrive, l'ora
  /// ([inAttesa]): mai «Offuscata» (10 nov: «se no non capisci cosa hai visto»), mai l'inizio del testo.
  static String di(Entry e) => e.titolo ?? (e.privata ? inAttesa('Trascrizione', e.at) : taglia(e.text));

  /// Al posto del titolo di una offuscata che non ce l'ha ancora: «Trascrizione delle 21:40», «Nota dell'01:05».
  static String inAttesa(String cosa, DateTime at) => '$cosa ${at.hour == 1 ? "dell'" : 'delle '}${hm(at)}';

  /// Al posto del titolo c'è l'inizio del testo (o l'ora): si mostra più tenue, in attesa del titolo vero.
  static bool provvisorio(Entry e) => e.titolo == null;

  /// Le prime [parole] parole di [testo], su una riga: senza i segni della formattazione né la punteggiatura in fondo.
  static String taglia(String testo) {
    final tutte = testo.replaceAll('*', '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return tutte.take(parole).join(' ').replaceFirst(RegExp(r'[\s.,;:!?…\-–—]+$'), '');
  }
}
