import 'package:flutter/material.dart';

import '../ds.dart';

enum TipoBottone {
  /// L'azione principale di una pagina (una sola).
  pieno,

  /// Le azioni secondarie.
  tenue,

  /// Annulla, Tutte, Riprova: solo testo.
  testo,
}

/// Un solo bottone, tre tipi, due altezze (48 alto, 40 basso), con o senza icona. Sempre a pillola.
class Bottone extends StatelessWidget {
  const Bottone(
    this.testo, {
    super.key,
    required this.onPressed,
    this.tipo = TipoBottone.pieno,
    this.alto = true,
    this.icona,
    this.colore,
  });

  final String testo;
  final VoidCallback? onPressed;
  final TipoBottone tipo;
  final bool alto;
  final IconData? icona;

  /// Solo per i casi dichiarati (rosso: Elimina, Rimuovi): il testo di un «Testo», il fondo di un «Pieno». Di base: i
  /// colori del tipo.
  final Color? colore;

  /// Lo stile di un tipo: lo usano il Bottone e i temi dei bottoni di Material (theme.dart).
  static ButtonStyle stile(
    Colori c,
    TipoBottone tipo, {
    bool alto = true,
    Color? colore,
  }) {
    final (fondo, su) = switch (tipo) {
      TipoBottone.pieno => (colore ?? c.azione, c.suAzione),
      TipoBottone.tenue => (c.azioneTenue, c.suAzioneTenue),
      TipoBottone.testo => (Colors.transparent, colore ?? c.azione),
    };
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) && tipo != TipoBottone.testo
            ? c.linea
            : fondo,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? c.testoSecondario : su,
      ),
      overlayColor: WidgetStatePropertyAll(su.withValues(alpha: 0.1)),
      minimumSize: WidgetStatePropertyAll(
        Size(0, alto ? Misura.bottoneAlto : Misura.bottoneBasso),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: alto ? Spazio.s6 : Spazio.s4),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      side: const WidgetStatePropertyAll(BorderSide.none),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(
        alto ? Testo.titoloScheda : Testo.etichetta,
      ),
      iconSize: WidgetStatePropertyAll(
        alto ? Misura.iconaMedia : Misura.iconaPiccola,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = stile(context.col, tipo, alto: alto, colore: colore);
    return icona == null
        ? TextButton(style: s, onPressed: onPressed, child: Text(testo))
        : TextButton.icon(
            style: s,
            onPressed: onPressed,
            icon: Icon(icona),
            label: Text(testo),
          );
  }
}
