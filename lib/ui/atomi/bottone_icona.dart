import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ds.dart';

enum TipoIcona {
  /// Nudo: barre, intestazione, l'azione nel Dock. (Regola: il fondo ce l'hanno solo il potere,
  /// la casa di Transcri e ciò che è selezionato.)
  trasparente,

  /// Un fondo leggero.
  tenue,

  /// Selezionato: la pagina in cui sei.
  acceso,

  /// Registra.
  pieno,
}

/// Ogni bottone tondo con un'icona. Due misure: 40 e 48 (il minimo per un dito; anche nel Dock).
/// Cambiando [tipo] il colore dell'icona passa piano all'altro, come il fondo: nessun salto.
class BottoneIcona extends StatelessWidget {
  const BottoneIcona(
    this.icona, {
    super.key,
    required this.onTap,
    this.tipo = TipoIcona.trasparente,
    this.misura = Misura.tocco,
    this.etichetta,
    this.figlio,
    this.conFondo = true,
  });

  final IconData icona;
  final VoidCallback? onTap;
  final TipoIcona tipo;
  final double misura;

  /// Il suggerimento (e il nome per chi usa il lettore dello schermo).
  final String? etichetta;

  /// Al posto dell'icona, se serve disegnare qualcosa di suo (le barre della grana).
  final Widget? figlio;

  /// Senza: il fondo del tipo lo disegna qualcun altro (nella pillola delle pagine scivola da una pagina all'altra).
  final bool conFondo;

  static (Color?, Color) colori(Colori c, TipoIcona tipo) => switch (tipo) {
    TipoIcona.trasparente => (null, c.testoSecondario),
    TipoIcona.tenue => (c.scheda, c.testoSecondario),
    TipoIcona.acceso => (c.azioneTenue, c.suAzioneTenue),
    TipoIcona.pieno => (c.azione, c.suAzione),
  };

  @override
  Widget build(BuildContext context) {
    final (fondo, su) = colori(context.col, tipo);
    // L'icona segue la misura del tasto: piccola sotto i 40, media fino a 40, grande sopra.
    final dim = misura < Misura.bottoneBasso
        ? Misura.iconaPiccola
        : (misura <= Misura.bottoneBasso
              ? Misura.iconaMedia
              : Misura.iconaGrande);
    final icona =
        figlio ??
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: su),
          duration: Durata.normale,
          curve: Curva.standard,
          builder: (context, colore, _) => Icon(this.icona, size: dim, color: colore),
        );
    final b = Material(
      color: conFondo ? fondo ?? Colors.transparent : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox.square(
          dimension: misura,
          child: Center(child: icona),
        ),
      ),
    );
    return etichetta == null ? b : Tooltip(message: etichetta!, child: b);
  }
}
