// In cima e in fondo (6 nov, giro 4): l'intestazione che scorrendo diventa pillole, la lente e il ⋮, la ricerca
// col campo in fondo (i filtri, dal giro 6, sotto il titolo di Trascrivi), la data che resta in cima scorrendo i giorni, il Dock che si fa da parte
// mentre si sceglie e si muove senza salti.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcrify/core/filtro_voci.dart';
import 'package:transcrify/core/native.dart';
import 'package:transcrify/ui/azioni_pagina.dart';
import 'package:transcrify/ui/cerca.dart';
import 'package:transcrify/ui/dock.dart';
import 'package:transcrify/ui/molecole/barra_scelte.dart';
import 'package:transcrify/ui/filtri_trascrivi.dart';
import 'package:transcrify/ui/molecole/filtri_voci.dart';
import 'package:transcrify/ui/molecole/intestazione.dart';
import 'package:transcrify/ui/molecole/isola.dart';
import 'package:transcrify/ui/molecole/riga_in_attesa.dart';
import 'package:transcrify/ui/molecole/riga_trovata.dart';
import 'package:transcrify/ui/molecole/scheda_trascrizione.dart';
import 'package:transcrify/ui/molecole/titolo_giorno.dart';
import 'package:transcrify/ui/pensieri.dart';
import 'package:transcrify/ui/theme.dart';
import 'package:transcrify/ui/trascrivi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  const channel = MethodChannel('transcrify/core');
  final oggi = DateTime.now();

  // Trascrizioni e note finte, tutte con «treno»: da WhatsApp, da Telegram, dettate, una privata.
  Map<String, Object?> voce(String testo, int giorniFa, {String? source, String? mode, String? colore, bool privata = false}) => {
    'text': testo,
    'at': oggi.subtract(Duration(days: giorniFa)).millisecondsSinceEpoch,
    'purified': mode != null,
    'mode': mode,
    'source': source,
    'colore': colore,
    'privata': privata,
  };
  final voci = [
    voce('Il vocale del treno in ritardo', 0, source: 'com.whatsapp', mode: 'fedele'),
    voce('Il treno di ieri sera, riassunto', 1, source: 'org.telegram.messenger', mode: 'riassunto'),
    voce('Il treno che ho dettato io', 2, mode: 'pulita', colore: '2:3'),
    voce('Il treno segreto', 3, privata: true),
  ];
  Map<String, Object?> nota(String id, String testo, {String? source}) => {
    'id': id,
    'title': '',
    'text': testo,
    'created': oggi.millisecondsSinceEpoch,
    'updated': oggi.millisecondsSinceEpoch,
    'source': source,
  };
  final note = [nota('n1', 'Una nota sul treno'), nota('n2', 'Un vocale sul treno, nella nota', source: 'whatsapp')];
  // Il motore trova «treno» dappertutto (la frase è tutto il testo).
  final trovati = [
    for (final v in voci) {'tipo': 'voce', 'id': '${v['at']}', 'start': 0, 'end': (v['text'] as String).length, 'esatto': true},
    for (final n in note) {'tipo': 'nota', 'id': n['id'], 'start': 0, 'end': (n['text'] as String).length, 'esatto': true},
  ];
  var storia = voci;

  setUp(() {
    storia = voci;
    Core.live.value = const Live();
    TrascriviPage.scegliendo.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'history' => storia,
        'notes' => note,
        // «aereo» non c'è da nessuna parte.
        // Tutto per parola, niente per senso.
        'cerca' => (call.arguments as Map)['testo'] == 'aereo' || (call.arguments as Map)['senso'] == true ? const [] : trovati,
        _ => null,
      };
    });
  });

  // Le macchie della privata girano sempre: qui ferme (come con «riduci le animazioni»).
  Widget app(Widget child, {double testo = 1.3, Brightness luce = Brightness.dark}) => MaterialApp(
    theme: buildTheme(luce),
    builder: (context, figlio) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(testo), disableAnimations: true),
      child: figlio!,
    ),
    home: Scaffold(body: child),
  );

  Future<void> telefono(WidgetTester t, {double largo = 360}) async {
    t.view.physicalSize = Size(largo, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> fine(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }

  /// Il fondo dell'isola delle azioni (quella che ha la lente).
  bool fondoAzioni(WidgetTester t) => t.widget<Isola>(find.ancestor(of: find.byTooltip('Cerca'), matching: find.byType(Isola)).first).fondo;

  Widget pagina({VoidCallback? onSeleziona, VoidCallback? onImpostazioni}) => Builder(
    builder: (context) => Intestazione(
      titolo: 'Trascrivi',
      segno: const ChipStato('Dati finti', tipo: TipoChip.azione),
      sotto: RigaInAttesa(quante: 12, riprovando: false, onRiprova: () {}, onApri: (_) {}),
      accanto: const InAttesaCorto(quante: 12),
      azioni: azioniPagina(context, onSeleziona: onSeleziona, onImpostazioni: onImpostazioni ?? () {}),
      child: ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('Riga $i'))]),
    ),
  );

  group("L'intestazione", () {
    for (final largo in [320.0, 412.0]) {
      testWidgets('ferma è una barra, scorrendo due pillole sopra la pagina, in cima torna barra ($largo dp, testo grande)', (t) async {
        await telefono(t, largo: largo);
        await t.pumpWidget(app(pagina(), testo: 1.5));
        await t.pumpAndSettle();
        // Ferma: il titolo (grande quanto nella pillola, 10 nov), le azioni nude.
        expect(t.widget<Text>(find.text('Trascrivi')).style!.fontSize, Testo.titoloPillola.fontSize);
        expect(fondoAzioni(t), isFalse);
        expect(find.byType(RigaInAttesa), findsOneWidget);

        await t.drag(find.text('Riga 3'), const Offset(0, -300));
        await t.pumpAndSettle();
        // Scorsa: il titolo è in una pillola (piccolo), le azioni sono un'isola, la riga in attesa è accanto al titolo.
        final titolo = find.text('Trascrivi').hitTestable();
        expect(titolo, findsOneWidget);
        expect(t.widget<Text>(titolo).style!.fontSize, Testo.titoloPillola.fontSize);
        expect(find.ancestor(of: titolo, matching: find.byType(Isola)), findsOneWidget);
        expect(fondoAzioni(t), isTrue);
        expect(find.byType(InAttesaCorto).hitTestable(), findsOneWidget);
        // La pagina scorre sotto le pillole: una riga sta dietro la pillola del titolo.
        final pillola = t.getRect(find.ancestor(of: titolo, matching: find.byType(Isola)));
        final sotto = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Riga ')).evaluate().map((e) => t.getRect(find.byWidget(e.widget)));
        expect(sotto.any((r) => r.top < pillola.bottom), isTrue);

        await t.drag(find.text('Riga 12'), const Offset(0, 2000));
        await t.pumpAndSettle();
        expect(t.widget<Text>(find.text('Trascrivi').hitTestable()).style!.fontSize, Testo.titoloPillola.fontSize);
        expect(fondoAzioni(t), isFalse);
        await fine(t);
      });
    }

    testWidgets('il ⋮ ha «Seleziona» e «Impostazioni»; senza scelta solo «Impostazioni»', (t) async {
      await telefono(t);
      var scelto = 0, impostazioni = 0;
      await t.pumpWidget(app(pagina(onSeleziona: () => scelto++, onImpostazioni: () => impostazioni++)));
      await t.pumpAndSettle();
      // Niente più ingranaggio né tasto per scegliere in cima: solo la lente e il ⋮.
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byTooltip('Cerca'), findsOneWidget);
      await t.tap(find.byTooltip('Altre opzioni'));
      await t.pumpAndSettle();
      expect(find.text('Seleziona'), findsOneWidget);
      expect(find.text('Impostazioni'), findsOneWidget);
      await t.tap(find.text('Seleziona'));
      await t.pumpAndSettle();
      expect((scelto, impostazioni), (1, 0));
      expect(find.text('Seleziona'), findsNothing);
      await t.tap(find.byTooltip('Altre opzioni'));
      await t.pumpAndSettle();
      await t.tap(find.text('Impostazioni'));
      await t.pumpAndSettle();
      expect((scelto, impostazioni), (1, 1));

      await t.pumpWidget(app(pagina()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Altre opzioni'));
      await t.pumpAndSettle();
      expect(find.text('Seleziona'), findsNothing);
      expect(find.text('Impostazioni'), findsOneWidget);
      await fine(t);
    });
  });

  testWidgets(
    'Con ‹ (una cartella aperta): a sinistra del titolo, nella barra e nella pillola',
    (t) async {
      await telefono(t, largo: 320);
      var indietro = 0;
      await t.pumpWidget(
        app(
          Intestazione(
            titolo: 'Una cartella dal nome lungo',
            indietro: () => indietro++,
            child: ListView(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 60, child: Text('Riga $i')),
              ],
            ),
          ),
          testo: 1.5,
        ),
      );
      await t.pumpAndSettle();
      final titolo = t.getRect(
        find.text('Una cartella dal nome lungo').hitTestable(),
      );
      expect(
        t.getRect(find.byTooltip('Indietro').hitTestable()).right,
        lessThanOrEqualTo(titolo.left),
      );
      await t.tap(find.byTooltip('Indietro').hitTestable());
      await t.drag(find.text('Riga 3'), const Offset(0, -300));
      await t.pumpAndSettle();
      final pillola = find.ancestor(
        of: find.text('Una cartella dal nome lungo').hitTestable(),
        matching: find.byType(Isola),
      );
      expect(
        find.descendant(of: pillola, matching: find.byTooltip('Indietro')),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Indietro').hitTestable());
      expect(indietro, 2);
      await fine(t);
    },
  );

  group('La ricerca', () {
    Future<void> apri(WidgetTester t, {double largo = 360, double testo = 1.3}) async {
      await telefono(t, largo: largo);
      await t.pumpWidget(app(pagina(), testo: testo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Cerca'));
      await t.pumpAndSettle();
    }

    Future<void> cerca(WidgetTester t, String testo) async {
      await t.enterText(find.byType(TextField), testo);
      await t.pump(Durata.normale);
      await t.pumpAndSettle();
    }

    testWidgets('la lente la apre: il campo in fondo, già pronto a scrivere; i filtri non stanno qui', (t) async {
      await apri(t);
      expect(find.byType(CercaPage), findsOneWidget);
      final campo = t.getRect(find.byType(TextField));
      expect(campo.bottom, greaterThan(720 * 0.85));
      expect(find.byType(ChipFiltro), findsNothing);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);
      expect(t.testTextInput.isVisible, isTrue);
      await fine(t);
    });

    testWidgets('trova note e trascrizioni (mai le private)', (t) async {
      // Le righe costruite (la lista è pigra: quelle in fondo possono stare fuori dallo schermo).
      final righe = find.byType(RigaTrovata, skipOffstage: false);
      await apri(t);
      await cerca(t, 'treno');
      expect(righe, findsNWidgets(5));
      expect(find.textContaining('segreto'), findsNothing);
      await fine(t);
    });

    testWidgets('«Annulla» e «indietro» la chiudono', (t) async {
      await apri(t);
      await t.tap(find.text('Annulla'));
      await t.pumpAndSettle();
      expect(find.byType(CercaPage), findsNothing);
      await t.tap(find.byTooltip('Cerca'));
      await t.pumpAndSettle();
      expect(find.byType(CercaPage), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(CercaPage), findsNothing);
      await fine(t);
    });

    testWidgets('stretta col testo grande, coi risultati e il nulla trovato: niente sborda', (t) async {
      await apri(t, largo: 320, testo: 1.6);
      await cerca(t, 'treno');
      expect(find.byType(RigaTrovata), findsWidgets);
      await cerca(t, 'aereo');
      expect(find.textContaining('Niente con'), findsOneWidget);
      await fine(t);
    });

    testWidgets('Nelle Note il campo in cima non c\'è più: si cerca dalla lente', (t) async {
      await telefono(t);
      await t.pumpWidget(app(const PensieriPage(bottom: 76)));
      await t.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(NoteCard), findsNWidgets(2));
      await fine(t);
    });
  });

  testWidgets('Scorrendo i giorni, la data del giorno in cima: al centro, poi se ne va', (t) async {
    await telefono(t);
    storia = [for (var i = 0; i < 40; i++) voce('Trascrizione numero $i, abbastanza lunga.', i)];
    await t.pumpWidget(app(const TrascriviPage(bottom: 76)));
    await t.pumpAndSettle();
    AnimatedOpacity velo() => t.widget<AnimatedOpacity>(find.ancestor(of: find.byType(EtichettaSospesa), matching: find.byType(AnimatedOpacity)).first);
    await t.drag(find.byType(ListView).first, const Offset(0, 900));
    await t.pump();
    await t.pump(Durata.normale);
    expect(find.byType(EtichettaSospesa), findsOneWidget);
    expect(velo().opacity, 1);
    // Al centro, appena sotto le pillole.
    final data = t.getRect(find.byType(EtichettaSospesa));
    expect(data.center.dx, moreOrLessEquals(180, epsilon: 1));
    expect(data.top, moreOrLessEquals(Intestazione.sottoPillole, epsilon: 1));
    // È il giorno che c'è lì sotto, non uno a caso.
    final giorno = t.widget<Text>(find.descendant(of: find.byType(EtichettaSospesa), matching: find.byType(Text))).data!;
    expect(find.text(giorno), findsWidgets);
    await t.pump(Durata.conferma);
    await t.pumpAndSettle();
    expect(velo().opacity, 0);
    await fine(t);
  });

  /// Trascrivi con la sua intestazione, collegati come nella shell: il tasto «Filtri» tra le azioni, i filtri accesi
  /// sotto il titolo.
  Widget trascrivi() => ListenableBuilder(
    listenable: FiltriTrascrivi.cambia,
    builder: (context, _) => Intestazione(
      titolo: 'Trascrivi',
      azioni: [?FiltriTrascrivi.tasto(), ...azioniPagina(context, onImpostazioni: () {})],
      filtri: FiltriTrascrivi.accesi(),
      child: const TrascriviPage(bottom: 76),
    ),
  );

  /// Le schede che si vedono (la lista è pigra).
  List<String> schede(WidgetTester t) => [for (final s in t.widgetList<SchedaTrascrizione>(find.byType(SchedaTrascrizione))) s.entry.text];

  /// Il tasto «Filtri», col numero di quelli accesi.
  Finder tasto(int quanti) => find.bySemanticsLabel(quanti == 0 ? 'Filtri' : (quanti == 1 ? 'Filtri, 1 acceso' : 'Filtri, $quanti accesi'));

  /// Un filtro del pannello aperto.
  Finder nelPannello(String nome) => find.descendant(of: find.byType(PannelloFiltri), matching: find.widgetWithText(ChipFiltro, nome));

  test('I filtri che servono: solo quelli che lasciano passare qualcuna ma non tutte; quelli accesi restano', () {
    final tutte = [for (final v in voci) Entry(v)];
    final p = FiltriPossibili.da(tutte, [Colore.da('2:3')!], const FiltroVoci());
    expect(p.fonti, Fonte.values);
    expect(p.modi, ['fedele', 'pulita', 'riassunto']);
    expect(p.colori, [Colore.da('2:3')]);
    // Solo dettate, senza modo né colore: niente da filtrare.
    final dettate = [for (final v in voci.skip(3)) Entry(v)];
    expect(FiltriPossibili.da(dettate, const [], const FiltroVoci()).vuoti, isTrue);
    // Ma un filtro acceso resta, per spegnerlo.
    expect(FiltriPossibili.da(dettate, const [], const FiltroVoci().conFonte(Fonte.whatsapp)).fonti, [Fonte.whatsapp]);
    // Dentro una fila basta uno, tra le file servono tutte.
    final f = const FiltroVoci().conFonte(Fonte.whatsapp).conFonte(Fonte.dettate);
    expect([for (final e in tutte) if (f.ammette(e)) e.text], ['Il vocale del treno in ritardo', 'Il treno che ho dettato io', 'Il treno segreto']);
    expect([for (final e in tutte) if (f.conModo('pulita').ammette(e)) e.text], ['Il treno che ho dettato io']);
  });

  for (final luce in Brightness.values) {
    testWidgets('Il tasto «Filtri» apre tre file; sotto il titolo solo quelli accesi, a sinistra ($luce, stretto, testo grande)', (t) async {
      await telefono(t, largo: 320);
      TrascriviPage.filtro.value = const FiltroVoci();
      storia = [...voci, for (var i = 4; i < 30; i++) voce('Altra trascrizione $i, abbastanza lunga.', i, mode: 'fedele')];
      await t.pumpWidget(app(trascrivi(), testo: 1.4, luce: luce));
      await t.pumpAndSettle();
      // Niente acceso: sotto il titolo niente; il tasto sta prima della lente.
      expect(find.byType(ChipFiltro), findsNothing);
      final prima = t.getRect(tasto(0));
      expect(prima.right, lessThanOrEqualTo(t.getRect(find.byTooltip('Cerca')).left + 1));
      // Il pannello: tre file col loro nome.
      await t.tap(tasto(0));
      await t.pumpAndSettle();
      for (final nome in ['DA DOVE', 'COME', 'COLORE']) {
        expect(find.descendant(of: find.byType(PannelloFiltri), matching: find.text(nome)), findsOneWidget);
      }
      // WhatsApp o Dettate, e Pulita.
      // 7 nov: ogni fila scorre di lato per conto suo, se non ci sta (stretto, testo grande): si porta in vista e si tocca.
      for (final nome in ['WhatsApp', 'Dettate', 'Pulita']) {
        await t.ensureVisible(nelPannello(nome));
        await t.pumpAndSettle();
        await t.tap(nelPannello(nome));
        await t.pumpAndSettle();
      }
      expect(TrascriviPage.filtro.value.quanti, 3);
      expect(schede(t), ['Il treno che ho dettato io']);
      // Chiuso il pannello (un tocco fuori), sotto il titolo restano i tre accesi, da sinistra, con la ×.
      await t.tapAt(const Offset(4, 600));
      await t.pumpAndSettle();
      expect(find.byType(PannelloFiltri), findsNothing);
      final accesi = find.descendant(of: find.byType(FiltriAccesi), matching: find.byType(ChipFiltro));
      expect(accesi, findsNWidgets(3));
      expect(t.getRect(accesi.first).left, moreOrLessEquals(Spazio.s5, epsilon: 6));
      expect(t.getRect(accesi.first).top, greaterThan(t.getRect(find.text('Trascrivi')).bottom));
      expect(find.descendant(of: find.byType(FiltriAccesi), matching: find.byIcon(Icons.close_rounded)), findsNWidgets(3));
      expect(tasto(3), findsOneWidget);
      // Toccato uno acceso, si spegne.
      // 7 nov: una fila sola che scorre di lato (non va più a capo).
      expect(t.getRect(accesi.at(2)).top, moreOrLessEquals(t.getRect(accesi.first).top, epsilon: 0.5));
      final pulita = find.descendant(of: find.byType(FiltriAccesi), matching: find.widgetWithText(ChipFiltro, 'Pulita'));
      await t.ensureVisible(pulita);
      await t.pumpAndSettle();
      await t.tap(pulita);
      await t.pumpAndSettle();
      expect(TrascriviPage.filtro.value.quanti, 2);
      // Scorrendo, il tasto resta allo stesso posto (ora in un'isola) e apre lo stesso pannello.
      await t.drag(find.byType(ListView).first, const Offset(0, 500));
      await t.pumpAndSettle();
      expect(t.getRect(tasto(2).hitTestable()), prima);
      await t.tap(tasto(2));
      await t.pumpAndSettle();
      expect(find.byType(PannelloFiltri), findsOneWidget);
      await t.tapAt(const Offset(4, 600));
      await t.pumpAndSettle();
      TrascriviPage.filtro.value = const FiltroVoci();
      await fine(t);
    });
  }

  testWidgets('Senza niente da filtrare il tasto non c\'è; nel pannello solo quello che hanno le trascrizioni', (t) async {
    await telefono(t);
    TrascriviPage.filtro.value = const FiltroVoci();
    storia = [for (var i = 0; i < 3; i++) voce('Dettata $i', i, mode: 'fedele')];
    await t.pumpWidget(app(trascrivi()));
    await t.pumpAndSettle();
    expect(tasto(0), findsNothing);
    // Una da WhatsApp: c'è da dove (WhatsApp, Dettate), non «Altre app», niente modi né colori.
    storia = [...storia, voce('Il vocale', 4, source: 'com.whatsapp', mode: 'fedele')];
    Core.refresh();
    await t.pumpAndSettle();
    await t.tap(tasto(0));
    await t.pumpAndSettle();
    expect(nelPannello('WhatsApp'), findsOneWidget);
    expect(nelPannello('Dettate'), findsOneWidget);
    expect(nelPannello('Altre app'), findsNothing);
    expect(find.text('COME'), findsNothing);
    expect(find.text('COLORE'), findsNothing);
    await t.tapAt(const Offset(4, 600));
    await t.pumpAndSettle();
    await fine(t);
  });

  testWidgets('Arrivati in cima scorrendo (il giorno più vecchio), le pillole non coprono la data: stanno sul fondo vuoto', (t) async {
    await telefono(t);
    TrascriviPage.filtro.value = const FiltroVoci();
    storia = [for (var i = 0; i < 30; i++) voce('Trascrizione numero $i, abbastanza lunga.', i)];
    await t.pumpWidget(app(trascrivi()));
    await t.pumpAndSettle();
    // Fino in cima: la lista cresce dal basso, in cima c'è il giorno più vecchio.
    for (var i = 0; i < 12; i++) {
      await t.drag(find.byType(ListView).first, const Offset(0, 1500));
      await t.pump();
    }
    await t.pumpAndSettle();
    final pillole = [
      for (final e in find.ancestor(of: find.text('Trascrivi').hitTestable(), matching: find.byType(Isola)).evaluate()) t.getRect(find.byWidget(e.widget)),
      t.getRect(find.ancestor(of: find.byTooltip('Cerca'), matching: find.byType(Isola)).first),
    ];
    expect(pillole, hasLength(2));
    final titoli = find.byType(TitoloGiorno);
    final primo = titoli.evaluate().map((e) => t.getRect(find.byWidget(e.widget))).reduce((a, b) => a.top < b.top ? a : b);
    for (final p in pillole) {
      expect(primo.overlaps(p), isFalse, reason: '$primo e $p');
    }
    expect(primo.top, greaterThanOrEqualTo(Intestazione.sottoPillole - 1));
    await fine(t);
  });

  group('Il Dock', () {
    Widget dock({int pagina = 0, Power potere = Power.pensieri}) => Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<bool>(
        valueListenable: Scelta.attiva,
        builder: (context, scegli, _) => Dock(
          power: potere,
          onTocco: () {},
          onProssimo: () {},
          onTira: (_) {},
          nest: const SizedBox.square(dimension: Misura.tondo),
          action: (Icons.edit_rounded, 'Scrivi', () {}),
          pages: const [(Icons.notes_rounded, 'Note'), (Icons.bubble_chart_rounded, 'Argomenti')],
          page: pagina,
          nascosto: scegli,
        ),
      ),
    );

    testWidgets('più piccolo, ma i tasti restano grandi quanto un dito', (t) async {
      await telefono(t, largo: 320);
      await t.pumpWidget(app(dock(), testo: 1.6));
      await t.pumpAndSettle();
      expect(Misura.isola, lessThan(64));
      expect(t.getSize(find.byTooltip('Scrivi')).height, greaterThanOrEqualTo(Misura.tocco));
      expect(t.getSize(find.byTooltip('Note')).height, greaterThanOrEqualTo(Misura.tocco));
      await fine(t);
    });

    testWidgets('le pillole in cima, scorrendo, sono alte e tonde come le isole del Dock (6 nov: «o uguali o sembra strano»)', (t) async {
      for (final largo in [320.0, 412.0]) {
        await telefono(t, largo: largo);
        await t.pumpWidget(app(dock(), testo: 1.6));
        await t.pumpAndSettle();
        final isolaDock = find.ancestor(of: find.byTooltip('Scrivi'), matching: find.byType(Isola)).first;
        final altaDock = t.getSize(isolaDock).height;
        await t.pumpWidget(app(pagina(), testo: 1.6));
        await t.pumpAndSettle();
        await t.drag(find.text('Riga 3'), const Offset(0, -300));
        await t.pumpAndSettle();
        final titolo = find.ancestor(of: find.text('Trascrivi').hitTestable(), matching: find.byType(Isola));
        final azioni = find.ancestor(of: find.byTooltip('Cerca'), matching: find.byType(Isola)).first;
        for (final isola in [titolo, azioni]) {
          expect(t.getSize(isola).height, altaDock, reason: '$largo');
          expect(t.widget<Isola>(isola).raggio, isNull, reason: 'a pillola, come il Dock');
          expect((t.widget<Isola>(isola).padding as EdgeInsets).vertical, 2 * Isola.margine);
        }
        expect(altaDock, Misura.isola);
        // Il titolo nella pillola è piccolo in proporzione; fermo in cima, un passo sotto il vecchio 28.
        expect(Testo.titoloPillola.fontSize, lessThan(Testo.titoloSezione.fontSize!));
        expect(Testo.titoloPagina.fontSize, lessThan(28));
        await fine(t);
      }
    });

    testWidgets('mentre si sceglie scende e sparisce, e non si tocca; poi torna', (t) async {
      await telefono(t);
      await t.pumpWidget(app(dock()));
      await t.pumpAndSettle();
      final prima = t.getRect(find.byTooltip('Scrivi'));
      Scelta.attiva.value = true;
      await t.pump();
      await t.pump(Scelta.durata ~/ 2);
      // A metà strada: già più giù, non ancora sparito.
      expect(t.getRect(find.byTooltip('Scrivi')).top, greaterThan(prima.top));
      await t.pumpAndSettle();
      expect(find.byTooltip('Scrivi').hitTestable(), findsNothing);
      Scelta.attiva.value = false;
      await t.pumpAndSettle();
      expect(find.byTooltip('Scrivi').hitTestable(), findsOneWidget);
      expect(t.getRect(find.byTooltip('Scrivi')), prima);
      await fine(t);
    });

    testWidgets('cambiando pagina il fondo acceso scivola, non salta', (t) async {
      await telefono(t);
      Rect fondo() => t.getRect(find.descendant(of: find.byKey(const ValueKey('pagina scelta')), matching: find.byType(DecoratedBox)));
      await t.pumpWidget(app(dock()));
      await t.pumpAndSettle();
      final da = fondo();
      expect(fondo().center.dx, moreOrLessEquals(t.getRect(find.byTooltip('Note')).center.dx, epsilon: 0.5));
      await t.pumpWidget(app(dock(pagina: 1)));
      await t.pump(Durata.normale ~/ 2);
      final mezzo = fondo();
      await t.pumpAndSettle();
      final a = fondo();
      expect(a.center.dx, moreOrLessEquals(t.getRect(find.byTooltip('Argomenti')).center.dx, epsilon: 0.5));
      expect(mezzo.left, greaterThan(da.left));
      expect(mezzo.left, lessThan(a.left));
      await fine(t);
    });

    testWidgets('cambiando potere il segno nel medaglione passa all\'altro, non compare di colpo', (t) async {
      await telefono(t);
      await t.pumpWidget(app(dock(potere: Power.trascrivi)));
      await t.pumpAndSettle();
      await t.pumpWidget(app(dock(potere: Power.pensieri)));
      await t.pump(Durata.normale ~/ 2);
      // A metà: ci sono tutti e due, quello che va e quello che arriva.
      expect(find.byIcon(Power.trascrivi.icon), findsOneWidget);
      expect(find.byIcon(Power.pensieri.icon), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byIcon(Power.trascrivi.icon), findsNothing);
      await fine(t);
    });
  });
}
