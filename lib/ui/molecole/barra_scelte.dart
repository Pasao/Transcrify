import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atomi.dart';
import '../ds.dart';
import 'fumetto.dart';

/// Si sta scegliendo in qualche pagina (trascrizioni, note, cartelle). Mentre si sceglie la barra delle scelte prende
/// il posto del Dock (6 nov: «è inutile navigare mentre scegli»): la accende [ConSelezione] finché mostra la barra, e
/// chi disegna il Dock la ascolta per farsi da parte. Tutti e due entrano ed escono con [transizione] in [durata]:
/// la barra e il Dock si muovono uguali.
abstract final class Scelta {
  /// Vero mentre una pagina mostra la barra delle scelte.
  static final attiva = ValueNotifier<bool>(false);

  /// Come entra e come esce quello che sta nel posto in fondo (la barra, il Dock): sale un poco dal bordo e appare;
  /// esce scendendo e sparendo.
  static Widget transizione(Widget child, Animation<double> a) {
    final curva = CurvedAnimation(parent: a, curve: Curva.standard, reverseCurve: Curva.uscita);
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(position: Tween(begin: const Offset(0, _sale), end: Offset.zero).animate(curva), child: child),
    );
  }

  static const durata = Durata.normale;

  /// Da quanto sotto arriva (in altezze della barra).
  static const _sale = 0.4;

  /// Chi la sta mostrando: per un attimo possono essere due (una pagina che sfuma nell'altra).
  static final _chi = <Object>{};

  static void _segna(Object chi, bool mostra) {
    final cambia = mostra ? _chi.add(chi) : _chi.remove(chi);
    if (!cambia) return;
    // Mai mentre si costruisce l'albero: chi ascolta (il Dock) si ridisegna al fotogramma dopo.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => attiva.value = _chi.isNotEmpty)
      ..ensureVisualUpdate();
  }
}

/// Una pagina con, in fondo, la barra delle cose scelte. La struttura resta la stessa con o senza barra:
/// se cambiasse, Flutter ricreerebbe la lista (si perde il punto, e il suo ScrollController si attacca a due liste).
/// Mentre c'è la barra: sta nel posto del Dock (che si fa da parte, [Scelta.attiva]) e «indietro» chiude la scelta
/// invece di uscire dall'app o dalla pagina.
class ConSelezione extends StatefulWidget {
  const ConSelezione({super.key, required this.bottom, required this.child, this.bar});

  /// Lo spazio in fondo coperto dal Dock: la barra sta nel suo posto, sullo stesso bordo.
  final double bottom;
  final Widget child;

  /// La barra, solo mentre scegli.
  final SelectionBar? bar;

  /// Quanto spazio in più lasciare in fondo alla lista mentre scegli, oltre a quello del Dock: la barra è più alta di
  /// lui (regola sua: le ultime salgono e la barra non le copre, così vedi cosa stai scegliendo).
  static double spazio(bool scegli) => scegli ? SelectionBar.altezza - Misura.isola : 0;

  @override
  State<ConSelezione> createState() => _ConSelezioneState();
}

class _ConSelezioneState extends State<ConSelezione> {
  @override
  void initState() {
    super.initState();
    Scelta._segna(this, widget.bar != null);
  }

  @override
  void didUpdateWidget(ConSelezione old) {
    super.didUpdateWidget(old);
    Scelta._segna(this, widget.bar != null);
  }

  @override
  void dispose() {
    Scelta._segna(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = widget.bar;
    return PopScope(
      canPop: bar == null,
      // «Indietro» mentre scegli: finisce la scelta, non esce.
      onPopInvokedWithResult: (uscita, _) {
        if (!uscita) bar?.onClose();
      },
      // Tutta la pagina, anche se il contenuto è stretto (poche cartelle): la barra si allinea al Dock, non a lui.
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            left: Spazio.s3,
            right: Spazio.s3,
            // Il bordo basso del Dock: lo spazio che lascia meno la sua isola.
            bottom: widget.bottom - Misura.isola,
            child: AnimatedSwitcher(
              duration: Scelta.durata,
              transitionBuilder: Scelta.transizione,
              child: bar ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un'azione della barra delle cose scelte: icona, nome, e cosa fa. Riceve dove sta il suo tasto sullo
/// schermo, alto fino in cima alla barra: quello che apre (la scelta del colore) spunta sopra la barra, sopra di lui.
/// Senza icona (null) è «Colore», con la ruota dei colori disegnata ([RuotaColori]): si fa con [SelectionBar.colore].
typedef AzioneScelte = (IconData?, String, void Function(Rect dove));

/// La barra delle cose scelte: quante sono, e cosa farne. Come in Samsung Note e nella Galleria, in fondo, al posto
/// del Dock. Sopra quante sono («1 scelta», «3 scelte») e «Fine» (6 nov: la parola, non la X; 7 nov: non
/// «Annulla», perché le azioni valgono subito e qui si esce soltanto); sotto le azioni, ognuna col suo nome (5 nov: si deve capire cosa puoi fare). Senza azioni (non ne hai ancora scelta nessuna) c'è
/// solo la riga di sopra.
///
/// Come si usa (Trascrivi, Pensieri, le cartelle): la pagina la passa a [ConSelezione] solo mentre si sceglie.
/// - [quante]: quante sono scelte (anche 0: si sta scegliendo, ma non ancora niente).
/// - [onClose]: «Fine» (e «indietro»), finito di scegliere.
/// - [actions]: le azioni (icona, nome, cosa fa). Ognuna riceve dove sta il suo tasto sullo schermo: quello che
///   apre (la scelta del colore, i colori dell'unione) spunta lì sopra con `apriFumetto`. «Elimina» è rossa.
///
/// Sta sul fondo «floater», sempre scuro: i colori sono quelli del tema scuro (`Colori.sospesi`), anche col telefono chiaro.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.quante, required this.onClose, required this.actions});

  /// Quanto è alta, con le azioni: le liste le lasciano questo spazio (vedi [ConSelezione.spazio]).
  static const altezza = 2 * Spazio.s2 + Misura.bottoneBasso + _altaAzione;
  static const _altaAzione = Misura.tocco + Spazio.s2;

  /// «Nessuna scelta», «1 scelta», «3 scelte»: la stessa parola per trascrizioni, note e cartelle.
  static String etichetta(int quante) => switch (quante) {
    0 => 'Nessuna scelta',
    1 => '1 scelta',
    final n => '$n scelte',
  };

  final int quante;
  final VoidCallback onClose;
  final List<AzioneScelte> actions;

  /// «Colore» (7 nov: la ruota dei colori, non più la tavolozza da pittore): apre la rosa sopra il tasto.
  static AzioneScelte colore(void Function(Rect dove) onTap) => (null, 'Colore', onTap);

  @override
  Widget build(BuildContext context) {
    final c = Colori.sospesi;
    return BarraInFondo(
      child: AnimatedSize(
        duration: Durata.normale,
        curve: Curva.standard,
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(Spazio.s2),
          decoration: BoxDecoration(color: c.floater, borderRadius: BorderRadius.circular(Raggio.gruppo), boxShadow: Ombra.sospeso),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: Misura.bottoneBasso,
                child: Row(
                  children: [
                    const SizedBox(width: Spazio.s3),
                    Expanded(
                      child: Text(etichetta(quante), maxLines: 1, overflow: TextOverflow.ellipsis, style: Testo.titoloScheda.copyWith(color: c.suFloater)),
                    ),
                    Bottone('Fine', tipo: TipoBottone.testo, alto: false, colore: c.suFloater, onPressed: onClose),
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                SizedBox(
                  height: _altaAzione,
                  child: Row(
                    children: [for (final a in actions) Expanded(child: _AzioneScelte(a, barra: context))],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un'azione della barra: l'icona e, sotto, il suo nome. Su un telefono stretto il nome si stringe, non va a capo.
class _AzioneScelte extends StatelessWidget {
  const _AzioneScelte(this.azione, {required this.barra});

  final AzioneScelte azione;

  /// La barra: quello che l'azione apre spunta sopra di lei, non sopra la sua prima riga.
  final BuildContext barra;

  @override
  Widget build(BuildContext context) {
    final (icona, nome, onTap) = azione;
    final c = Colori.sospesi;
    // Il rosso del pericolo, quello del tema scuro: sul floater si legge (almeno 4,5:1, controllato nei test).
    final colore = nome == 'Elimina' ? c.errore : c.suFloater;
    return Semantics(
      button: true,
      label: nome,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Raggio.campo),
        onTap: () {
          HapticFeedback.selectionClick();
          final tasto = dovSta(context);
          onTap(Rect.fromLTRB(tasto.left, dovSta(barra).top, tasto.right, tasto.bottom));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icona == null) const RuotaColori() else Icon(icona, size: Misura.iconaGrande, color: colore),
            const SizedBox(height: Spazio.s1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spazio.s1),
                child: Text(nome, maxLines: 1, style: Testo.piccolo.copyWith(color: colore)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
