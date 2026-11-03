# Transcrify: come si lavora sul codice

Prima di toccare l'interfaccia leggi `DESIGN-SYSTEM.md` (a che punto siamo, cosa manca, le regole).

## Le regole (sempre, e controllate da `test/regole_test.dart`)

1. **Niente doppioni (DRY).** Ogni cosa è definita in un posto solo: una regola, uno stile, un widget,
   un calcolo. Se serve in due posti, si estrae e si usa da entrambi (es. `Bottone.stile` lo usa
   anche il tema). Prima di scrivere un pezzo nuovo, cerca se c'è già.
2. **Una fonte sola per i valori.** Colori dai token (`Token.kt` → `context.col` in Flutter,
   `Token` nel Kotlin); testi, spazi, raggi, misure, durate, ombre da `lib/ui/ds/`. Niente
   numeri o colori scritti a mano nei pezzi. Il conteggio dei valori scritti a mano può solo
   scendere: dopo un miglioramento, `dart run tool/ds_rimasti.dart --tetto` (si rifiuta se un numero è salito:
   non si alza mai il tetto per far passare il test). Nel Kotlin: colori da `Token.kt`/`Palette`, testi da `Caratteri.kt`.
3. **Una responsabilità per file (SOLID, la «S»: Single Responsibility).** Si divide per quello
   che un pezzo fa, non per numero di righe: un widget, un calcolo, una regola. Si costruisce per
   **composizione** (pezzi piccoli messi insieme), non per ereditarietà, come vuole Flutter.
   Cartelle per livello: `lib/ui/ds/` (fondamenta), `lib/ui/atomi/`, `lib/ui/molecole/`, poi le pagine.
   Il test cerca i blocchi di codice copiati (5 righe uguali) tra i pezzi nuovi e il resto.
4. **I pezzi nuovi usano solo i nomi nuovi** (`context.col`, `Testo`, `Spazio`…), mai
   `Tokens.*` o `tk.*` (sono un adattatore temporaneo, da togliere alla fine).
5. **Figma è il riferimento, non una copia.** Il codice si organizza da codice: nomi chiari,
   responsabilità separate, niente trasposizione 1:1 dei livelli di Figma.
6. **Prima di dire «fatto»:** `flutter analyze` pulito, `flutter test` verde (regole incluse),
   `DESIGN-SYSTEM.md` aggiornato (lista e contatore).

## Altro

- Le prove sul telefono si fanno solo coi dati finti (Impostazioni → Prove), mai sui dati veri.
- Commit solo quando lo chiede il proprietario; come Pasao, senza tracce di Claude.
- Kotlin: `JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"` per `./gradlew` (test: `TokenTest`).
