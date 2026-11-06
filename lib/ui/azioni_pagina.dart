import 'package:flutter/material.dart';

import 'cerca.dart';
import 'molecole/tasto_menu.dart';
import 'theme.dart';

/// Le azioni in cima a ogni pagina (6 nov, sua scelta), le stesse ovunque: la lente, che apre la ricerca, e il ⋮ con
/// «Seleziona» (solo dove si sceglie: [onSeleziona]) e «Impostazioni».
List<Widget> azioniPagina(BuildContext context, {VoidCallback? onSeleziona, required VoidCallback onImpostazioni}) => [
  BottoneIcona(Icons.search_rounded, etichetta: 'Cerca', misura: Misura.tondo, onTap: () => apriRicerca(context)),
  TastoMenu(
    voci: [
      if (onSeleziona != null) (Icons.check_circle_outline_rounded, 'Seleziona', onSeleziona),
      (Icons.settings_outlined, 'Impostazioni', onImpostazioni),
    ],
  ),
];
