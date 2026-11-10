import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';

import 'helpers/fixtures.dart';

void main() {
  late WeightStore weights;
  late BodyWeightStore bodyWeights;
  late ShoppingStore shopping;
  late ProfileStore profile;
  late UserDataStore userData;
  // Scheda, dieta e spesa di prova al posto degli asset (l'app non le ha più).
  final assets = FixtureBundle();

  // Nei test non c'è una WebView: niente player YouTube, solo l'anteprima.
  setUpAll(() => ExerciseMedia.videoEnabled = false);

  setUp(() async {
    // rootBundle tiene in cache i file già letti. Nei test ogni testWidgets
    // ha il suo "tempo finto": un caricamento iniziato nel test precedente
    // non si completerebbe mai in quello dopo. Svuotiamo la cache ogni volta.
    rootBundle.clear();
    // Onboarding già fatto: questi test partono direttamente dalle tab.
    SharedPreferences.setMockInitialValues({
      'weight_hack_squat': 16.0,
      'onboarding_done': true,
      'profile_name': 'Mario Rossi',
    });
    weights = await WeightStore.load();
    bodyWeights = await BodyWeightStore.load();
    shopping = await ShoppingStore.load();
    profile = await ProfileStore.load();
    // Nessuna scheda dell'utente: si vede quella di esempio.
    userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));
  });

  testWidgets('La tab Allenamento mostra la scheda dal JSON', (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Chest press'), findsOneWidget);
    expect(find.text("4 × 8–12 · rec. 2'"), findsOneWidget);

    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();
    expect(find.text('Hack squat'), findsOneWidget);
    // Il peso salvato compare già nella riga.
    expect(find.text('16 kg'), findsOneWidget);

    // In fondo c'è la camminata: 30 min, 10%, 5,5 km/h.
    await tester.scrollUntilVisible(find.text('⏱️ 30 min'), 200);
    expect(find.text('💨 5,5 km/h'), findsOneWidget);
  });

  testWidgets('Nel dettaglio il peso cambia e la lista si aggiorna', (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legs'));
    await tester.pumpAndSettle();

    // Apro il dettaglio dell'hack squat (prima lo porto sullo schermo).
    await tester.ensureVisible(find.text('Hack squat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hack squat'));
    await tester.pumpAndSettle();
    expect(find.text('Il tuo peso'), findsOneWidget);
    expect(find.text('16 kg'), findsOneWidget);

    // + aumenta di 1 kg.
    await tester.tap(find.byTooltip('Aumenta'));
    await tester.pumpAndSettle();
    expect(find.text('17 kg'), findsOneWidget);

    // Scrivo il peso a mano nel dialog.
    await tester.tap(find.text('17 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '22,5');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('22,5 kg'), findsOneWidget);

    // La card Muscoli: toccandola si apre lo schermo intero con lo zoom.
    // ensureVisible scorre la pagina finché la card è sullo schermo.
    await tester.ensureVisible(find.text('Tocca per ingrandire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tocca per ingrandire'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    // pageBack() cerca il tooltip inglese "Back": con l'app in italiano
    // è "Indietro", quindi tocchiamo direttamente il BackButton.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // La pagina è lunga: scorro finché compare la spiegazione.
    await tester.scrollUntilVisible(find.text('Come si esegue'), 200);
    expect(find.text('Come si esegue'), findsOneWidget);

    // Torno indietro: la riga nella lista mostra il nuovo peso.
    // pageBack() cerca il tooltip inglese "Back": con l'app in italiano
    // è "Indietro", quindi tocchiamo direttamente il BackButton.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('22,5 kg'), findsOneWidget);
    expect(weights.weightFor('hack_squat'), 22.5);
  });

  testWidgets("L'header ha il nome dell'app e il profilo mostra il nome", (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();
    expect(find.text('myWorkout'), findsOneWidget);
    expect(find.text('MR'), findsOneWidget);

    // Tocco il cerchio: si apre il pannello dal basso, col nome.
    await tester.tap(find.byTooltip('Profilo'));
    await tester.pumpAndSettle();
    expect(find.text('Mario Rossi'), findsOneWidget);
    // Il download da GitHub non c'è più.
    expect(find.text('Scarica gli ultimi dati'), findsNothing);
  });

  testWidgets('La barra in basso cambia pagina', (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Lun'), findsOneWidget);

    // Scelgo lunedì dalle schede in alto.
    await tester.tap(find.widgetWithText(Tab, 'Lun'));
    await tester.pumpAndSettle();
    expect(find.text('Pasta al pomodoro e tonno'), findsOneWidget);
    expect(find.text('Palestra'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Settimanale'), findsOneWidget);
  });

  testWidgets('Tab Pesata: aggiungo, correggo e cancello una pesata', (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessuna pesata salvata'), findsOneWidget);

    // Il + apre il dialog: scrivo il peso di oggi.
    await tester.tap(find.byTooltip('Aggiungi pesata'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '78,4');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('78,4 kg'), findsOneWidget);
    expect(bodyWeights.entries.single.kg, 78.4);

    // Tocco la riga per correggerla.
    await tester.tap(find.text('78,4 kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '78');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('78 kg'), findsOneWidget);

    // Trascino la riga verso sinistra: sparisce, poi "Annulla" la rimette.
    await tester.drag(find.text('78 kg'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(bodyWeights.entries, isEmpty);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('78 kg'), findsOneWidget);
  });

  testWidgets('Tab Spesa: spunto, Reset e Annulla', (tester) async {
    await tester.pumpWidget(MyWorkoutApp(weights: weights, bodyWeights: bodyWeights, shopping: shopping, profile: profile, userData: userData, assets: assets));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    // Si apre sulla spesa settimanale: spunto le uova.
    expect(find.text('Proteine e latticini'), findsOneWidget);
    await tester.tap(find.text('Uova'));
    await tester.pumpAndSettle();
    expect(shopping.isChecked('uova'), isTrue);
    expect(find.text('1/7'), findsOneWidget);

    // Reset toglie la spunta, Annulla la rimette.
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(shopping.isChecked('uova'), isFalse);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(shopping.isChecked('uova'), isTrue);

    // Nella scheda Mensile ci sono i prodotti della dispensa.
    await tester.tap(find.widgetWithText(Tab, 'Mensile'));
    await tester.pumpAndSettle();
    expect(find.text('Whey con creatina'), findsOneWidget);
  });
}
