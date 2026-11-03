import 'package:flutter/material.dart';

import 'ds.dart';
import 'atomi.dart';

export 'ds.dart';
export 'atomi.dart';

/// Titolo in Bricolage Grotesque; [strong] per la parola che deve cantare.
TextStyle display(BuildContext context, {double size = 34, bool strong = false, Color? color}) {
  final weight = strong ? 800.0 : 650.0;
  return TextStyle(
    fontFamily: Testo.fontTitoli,
    fontSize: size, // ds:eccezione: la funzione dei titoli (la grandezza la sceglie chi la usa)
    height: 1.04,
    letterSpacing: -0.04 * size,
    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
    fontVariations: [FontVariation('wght', weight), FontVariation('opsz', size.clamp(12, 96).toDouble())],
    color: color ?? context.col.testo,
  );
}

TextStyle monoStyle(BuildContext context, {double size = 11, Color? color}) =>
    TextStyle(fontFamily: Testo.fontMono, fontSize: size, color: color ?? context.col.testoSecondario, letterSpacing: 0.2); // ds:eccezione: la funzione degli orari

ThemeData buildTheme(Brightness b) {
  final col = b == Brightness.light ? Colori.chiaro : Colori.scuro;
  const body = Testo.fontTesto;
  final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: body);
  final text = base.textTheme.apply(bodyColor: col.testo, displayColor: col.testo, fontFamily: body);
  return base.copyWith(
    extensions: [col],
    // Le pagine sono trasparenti: lo sfondo lo dipinge Paper, con un velo dei colori del telefono.
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: col.azione,
      onPrimary: col.suAzione,
      surface: col.pagina,
      onSurface: col.testo,
      outline: col.linea,
      error: col.errore,
    ),
    textTheme: text.copyWith(
      // I ruoli di Material dagli stili del design system (chi usa ancora textTheme ha gli stessi valori).
      titleMedium: Testo.titoloScheda.copyWith(color: col.testo),
      bodyLarge: Testo.testoGrande.copyWith(color: col.testo),
      bodyMedium: Testo.testo.copyWith(color: col.testo),
      bodySmall: Testo.piccolo.copyWith(color: col.testoSecondario),
      labelLarge: Testo.etichetta.copyWith(color: col.testo),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: col.testo, size: Misura.iconaGrande),
    ),
    // Campo (B4): fondo «scheda», suggerimento leggibile, il contorno solo quando è attivo.
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: col.scheda,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spazio.s4, vertical: 14),
      hintStyle: Testo.testo.copyWith(color: col.testoSecondario),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Raggio.campo), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Raggio.campo), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Raggio.campo),
        borderSide: BorderSide(color: col.azione, width: 1.5),
      ),
    ),
    // Bottone (B4): FilledButton = Pieno alto, OutlinedButton = Tenue basso (senza contorno), TextButton = Testo basso.
    filledButtonTheme: FilledButtonThemeData(style: Bottone.stile(col, TipoBottone.pieno)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: Bottone.stile(col, TipoBottone.tenue, alto: false)),
    textButtonTheme: TextButtonThemeData(style: Bottone.stile(col, TipoBottone.testo, alto: false)),
    // BottoneIcona trasparente: icone nude nel testo secondario.
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: col.testoSecondario)),
    // Interruttore (B4): acceso il colore dell'azione, spento la linea.
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? col.azione : col.linea),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? col.suAzione : col.isola),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: col.floater,
      contentTextStyle: Testo.testo.copyWith(color: col.suFloater),
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: col.pagina,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: col.linea,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Raggio.foglio))),
    ),
  );
}

/// Un gruppo di impostazioni: un'etichetta piccola e tanto spazio. Nessuna linea.
class Section extends StatelessWidget {
  const Section({super.key, required this.label, required this.children, this.trailing});

  final String label;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: EtichettaGruppo(label),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Lo sfondo di ogni pagina, come nelle app Samsung: in alto un velo leggero del colore del
/// telefono che sfuma nel fondo neutro. È opaco, quindi le pagine non si vedono una sotto l'altra.
class Paper extends StatelessWidget {
  const Paper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = Color.alphaBlend(c.azione.withValues(alpha: dark ? 0.14 : 0.12), c.pagina);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, c.pagina], stops: const [0, 0.55]),
      ),
      child: child,
    );
  }
}
