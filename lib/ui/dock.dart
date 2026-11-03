import 'package:flutter/material.dart';

import 'atomi.dart';
import 'ds.dart';
import 'molecole/isola.dart';
import 'molecole/medaglione.dart';
import 'molecole/pillola_pagine.dart';
import 'molecole/rientra.dart';
import 'potere.dart';

export 'potere.dart';

/// Il Dock, in fondo a ogni pagina. Due lati, due compiti:
/// a sinistra dove sei (il medaglione del potere, e le sue pagine che escono da dietro),
/// a destra cosa crei (l'azione, nuda, e la casa di Transcri).
class Dock extends StatelessWidget {
  const Dock({
    super.key,
    required this.power,
    required this.onTocco,
    required this.onProssimo,
    required this.onTira,
    required this.nest,
    this.action,
    this.pages = const [],
    this.page = 0,
    this.onPage,
  });

  /// Quanto spazio prende, dal fondo: le pagine lasciano libero questo.
  static const height = Misura.isola + Spazio.s3;

  final Power power;

  /// I gesti sul medaglione (vedi [Medaglione]).
  final VoidCallback onTocco;
  final VoidCallback onProssimo;
  final ValueChanged<double> onTira;

  /// La casa di Transcri.
  final Widget nest;

  /// L'azione accanto a Transcri: scrivere in Pensieri, dettare in Trascrivi, buttare mentre ascolta.
  final (IconData, String, VoidCallback)? action;

  /// Le pagine del potere (in Pensieri: Note e Argomenti). Vuote se il potere ne ha una sola.
  final List<(IconData, String)> pages;
  final int page;
  final ValueChanged<int>? onPage;

  @override
  Widget build(BuildContext context) {
    const margine = (Misura.isola - Misura.tondo) / 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spazio.s3, 0, Spazio.s3, Spazio.s3),
      child: Row(
        children: [
          // Il medaglione davanti, le pagine che escono da dietro di lui (e rientrano cambiando potere).
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Misura.isola / 2),
                child: Rientra(
                  id: pages.length > 1 ? pages.map((p) => p.$2).join() : null,
                  da: Alignment.centerLeft,
                  child: PillolaPagine(pagine: pages, pagina: page, onPagina: (i) => onPage?.call(i)),
                ),
              ),
              Medaglione(potere: power, onTocco: onTocco, onProssimo: onProssimo, onTira: onTira),
            ],
          ),
          const Spacer(),
          Isola(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // L'azione esce da Transcri: l'isola si allunga verso sinistra.
                Rientra(
                  id: action?.$1,
                  da: Alignment.centerRight,
                  child: action == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: margine),
                          child: BottoneIcona(action!.$1, etichetta: action!.$2, onTap: action!.$3, misura: Misura.tondo),
                        ),
                ),
                nest,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
