import 'package:flutter/material.dart';

import '../atomi.dart';
import '../ds.dart';

/// Dove sta un pezzo sullo schermo: l'àncora di un fumetto, il punto di partenza di un volo.
Rect dovSta(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null || !box.hasSize ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
}

/// Un fumetto: un pezzo piccolo che spunta sopra il controllo che l'ha aperto ([sopra], sullo schermo),
/// centrato su di lui senza uscire dai bordi; sotto, se sopra non c'è posto. La pagina e le barre in fondo
/// restano visibili; un tocco fuori lo chiude. Con la tastiera aperta sale sopra di lei.
Future<T?> apriFumetto<T>(BuildContext context, {required Rect sopra, required WidgetBuilder builder}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Chiudi',
  barrierColor: Colors.transparent,
  // Svelto ad aprirsi e a chiudersi (5 nov: «la chiusura è lentissima»).
  transitionDuration: Durata.veloce,
  // Il movimento sta nella pagina: spunta dal controllo, non dal centro dello schermo.
  transitionBuilder: (_, _, _, child) => child,
  pageBuilder: (fumetto, a, _) {
    final sotto = sopra.center.dy < MediaQuery.sizeOf(fumetto).height / 2;
    return CustomSingleChildLayout(
      delegate: _Posto(sopra, MediaQuery.paddingOf(fumetto), MediaQuery.viewInsetsOf(fumetto).bottom),
      child: Spunta(animazione: a, da: sotto ? Alignment.topCenter : Alignment.bottomCenter, child: builder(fumetto)),
    );
  },
);

/// Dove sta il fumetto: sopra l'àncora (o sotto, se sopra non ci sta), dentro i bordi e sopra la tastiera.
class _Posto extends SingleChildLayoutDelegate {
  _Posto(this.ancora, this.bordi, this.tastiera);

  final Rect ancora;
  final EdgeInsets bordi;
  final double tastiera;

  static const _margine = Spazio.s4, _stacco = Spazio.s2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: (c.maxWidth - 2 * _margine).clamp(0, Misura.tavolozza),
    maxHeight: (c.maxHeight - bordi.top - tastiera - bordi.bottom - 2 * _stacco).clamp(0, double.infinity),
  );

  @override
  Offset getPositionForChild(Size schermo, Size f) {
    final x = (ancora.center.dx - f.width / 2).clamp(_margine, (schermo.width - _margine - f.width).clamp(_margine, double.infinity));
    final alto = bordi.top + _stacco;
    final basso = schermo.height - (tastiera > 0 ? tastiera : bordi.bottom) - _stacco - f.height;
    final sopra = ancora.top - _stacco - f.height;
    final y = sopra >= alto ? sopra : ancora.bottom + _stacco;
    return Offset(x, y.clamp(alto, basso < alto ? alto : basso));
  }

  @override
  bool shouldRelayout(_Posto old) => old.ancora != ancora || old.bordi != bordi || old.tastiera != tastiera;
}
