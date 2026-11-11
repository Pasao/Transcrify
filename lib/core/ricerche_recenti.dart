import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native.dart';

/// Le ultime ricerche (7 nov: «tocchi cerca e c'è solo la barra»): le cinque più nuove, prima l'ultima, senza doppioni
/// (né per maiuscole). Restano sul telefono (il Kotlin le tiene e basta); nelle prove solo finché l'app è aperta.
abstract final class RicercheRecenti {
  static const _ch = MethodChannel('transcrify/core');

  /// Quante se ne tengono.
  static const quante = 5;

  static final lista = ValueNotifier<List<String>>(const []);

  static Future<void> leggi() async {
    if (Core.preview.value) return;
    final l = ((await _ch.invokeMethod('ricercheRecenti')) as List?)?.cast<String>() ?? const [];
    if (!listEquals(l, lista.value)) lista.value = l;
  }

  /// [cercata] in cima (se c'era già, si sposta lì).
  static Future<void> aggiungi(String cercata) => _salva(conNuova(lista.value, cercata));

  static Future<void> togli(String cercata) => _salva([for (final r in lista.value) if (r != cercata) r]);

  /// La lista con [cercata] in cima: pulita (una riga, senza spazi in più), al massimo [quante].
  static List<String> conNuova(List<String> prima, String cercata) {
    final q = cercata.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return prima;
    return [q, for (final r in prima) if (r.toLowerCase() != q.toLowerCase()) r].take(quante).toList();
  }

  static Future<void> _salva(List<String> l) async {
    if (listEquals(l, lista.value)) return;
    lista.value = l;
    if (!Core.preview.value) await _ch.invokeMethod('ricercheRecenti', {'ricerche': l});
  }
}
