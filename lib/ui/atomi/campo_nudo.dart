import 'package:flutter/material.dart';

/// Un campo senza fondo né contorno: il testo sta direttamente su quello che c'è sotto (la trascrizione aperta, la nota,
/// la ricerca dentro la sua isola). Uno solo per tutti: chi serve cambia solo il suggerimento.
abstract final class CampoNudo {
  static const decorazione = InputDecoration(
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
  );
}
