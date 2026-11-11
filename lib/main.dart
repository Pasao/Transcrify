import 'package:flutter/material.dart';

import 'core/native.dart';
import 'ui/avvio.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prima di disegnare: i colori del telefono, così l'app non parte blu per poi cambiare.
  try {
    final s = await Core.state();
    Colori.usa(s.tokenChiaro, s.tokenScuro);
  } catch (_) {}
  runApp(const TranscrifyApp());
}

class TranscrifyApp extends StatelessWidget {
  const TranscrifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Un colore solo per tutto: se cambia (nuovo sfondo), si ridisegna l'app intera.
    return ValueListenableBuilder<int>(
        valueListenable: Colori.versione,
        builder: (context, _, _) => MaterialApp(
          title: 'Transcrify',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: Avvio(casa: (atterra, rivedi) => Shell(atterra: atterra, onReplayIntro: rivedi)),
        ),
    );
  }
}
