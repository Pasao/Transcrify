import 'package:flutter/material.dart';

/// Colori e caratteri. La pulizia viene da Figma (neutri, un blu per le azioni);
/// Bricolage Grotesque per i titoli, Inter per il testo, DM Mono per orari e codici.
/// Niente linee: separa lo spazio.
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.bg,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
  });

  final Color bg, surface, border, text, muted, faint;

  static const blue = Color(0xFF0D99FF);
  static const violet = Color(0xFF9747FF);
  static const red = Color(0xFFF24822);
  static const green = Color(0xFF14AE5C);
  static const yellow = Color(0xFFFFCD29);

  static const display = 'Bricolage Grotesque';
  static const body = 'Inter';
  static const mono = 'DM Mono';

  static const light = Tokens(
    bg: Color(0xFFFBFAF8),
    surface: Color(0xFFF1EFEB),
    border: Color(0xFFE4E1DC),
    text: Color(0xFF1E1E1E),
    muted: Color(0xFF6E6B66),
    faint: Color(0xFFADA9A3),
  );

  static const dark = Tokens(
    bg: Color(0xFF161616),
    surface: Color(0xFF242424),
    border: Color(0xFF363636),
    text: Color(0xFFF4F2EE),
    muted: Color(0xFFA8A5A0),
    faint: Color(0xFF6E6B66),
  );

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension TokensOf on BuildContext {
  Tokens get tk => Theme.of(this).extension<Tokens>()!;
}

/// Titolo in Bricolage Grotesque; [strong] per la parola che deve cantare.
TextStyle display(BuildContext context, {double size = 34, bool strong = false, Color? color}) {
  final weight = strong ? 800.0 : 650.0;
  return TextStyle(
    fontFamily: Tokens.display,
    fontSize: size,
    height: 1.04,
    letterSpacing: -0.04 * size,
    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
    fontVariations: [FontVariation('wght', weight), FontVariation('opsz', size.clamp(12, 96).toDouble())],
    color: color ?? context.tk.text,
  );
}

TextStyle monoStyle(BuildContext context, {double size = 11, Color? color}) =>
    TextStyle(fontFamily: Tokens.mono, fontSize: size, color: color ?? context.tk.muted, letterSpacing: 0.2);

ThemeData buildTheme(Brightness b) {
  final tk = b == Brightness.light ? Tokens.light : Tokens.dark;
  const body = Tokens.body;
  final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: body);
  final text = base.textTheme.apply(bodyColor: tk.text, displayColor: tk.text, fontFamily: body);
  return base.copyWith(
    extensions: [tk],
    scaffoldBackgroundColor: tk.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: Tokens.blue,
      onPrimary: Colors.white,
      surface: tk.bg,
      onSurface: tk.text,
      outline: tk.border,
      error: Tokens.red,
    ),
    textTheme: text.copyWith(
      titleMedium: text.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: tk.muted, height: 1.4),
      labelLarge: text.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tk.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: tk.text, size: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: tk.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: tk.faint, fontSize: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Tokens.blue, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tokens.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tk.text,
        minimumSize: const Size(0, 40),
        side: BorderSide(color: tk.border),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tokens.blue,
        minimumSize: const Size(0, 40),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Tokens.blue : tk.border),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF242424),
      contentTextStyle: TextStyle(fontFamily: body, color: Colors.white, fontSize: 14),
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tk.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: tk.border,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
          Row(children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: context.tk.muted),
              ),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
