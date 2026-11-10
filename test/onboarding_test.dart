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
import 'package:my_workout/features/onboarding/onboarding_page.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';

import 'helpers/real_io.dart';

void main() {
  group('initialsOf', () {
    test('prende la prima lettera delle prime due parole', () {
      expect(initialsOf('Mario Rossi'), 'MR');
      expect(initialsOf('mario rossi'), 'MR');
      expect(initialsOf('Anna'), 'A');
      expect(initialsOf('  Maria   Grazia  Bianchi '), 'MG');
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });

  group('ProfileStore', () {
    test('al primo avvio non c\'è nome e l\'onboarding è da fare', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await ProfileStore.load();
      expect(profile.name, '');
      expect(profile.onboardingDone, isFalse);
    });

    test('completeOnboarding salva il nome e avvisa', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await ProfileStore.load();
      var notified = 0;
      profile.addListener(() => notified++);

      await profile.completeOnboarding(name: '  Mario Rossi ');
      expect(profile.name, 'Mario Rossi');
      expect(profile.initials, 'MR');
      expect(profile.onboardingDone, isTrue);
      expect(notified, 1);

      // Riaprendo lo store (= riavvio dell'app) il profilo c'è ancora.
      final reopened = await ProfileStore.load();
      expect(reopened.onboardingDone, isTrue);
      expect(reopened.name, 'Mario Rossi');
    });
  });

  group('Onboarding', () {
    setUpAll(() => ExerciseMedia.videoEnabled = false);
    setUp(() => rootBundle.clear());

    late UserDataStore userData;

    Future<ProfileStore> pumpApp(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final profile = await ProfileStore.load();
      userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));
      await tester.pumpWidget(MyWorkoutApp(
        weights: await WeightStore.load(),
        bodyWeights: await BodyWeightStore.load(),
        shopping: await ShoppingStore.load(),
        profile: profile,
        userData: userData,
      ));
      await tester.pumpAndSettle();
      return profile;
    }

    testWidgets('al primo avvio: nome, giorni, scheda con esercizi, poi le tab', (tester) async {
      final profile = await pumpApp(tester);

      // Si parte dal benvenuto, non dalle tab.
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('Iniziamo'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.text('Iniziamo'));
      await tester.pumpAndSettle();
      expect(find.text('Come ti chiami?'), findsOneWidget);

      // Senza nome "Avanti" è spento.
      final avanti = find.widgetWithText(FilledButton, 'Avanti');
      expect(tester.widget<FilledButton>(avanti).onPressed, isNull);

      // Scrivendo, le iniziali compaiono nell'avatar e il pulsante si accende.
      await tester.enterText(find.byType(TextField), 'Mario Rossi');
      await tester.pump();
      expect(find.text('MR'), findsOneWidget);
      expect(tester.widget<FilledButton>(avanti).onPressed, isNotNull);
      await tester.tap(avanti);
      await tester.pumpAndSettle();

      // Giorni: senza giorni non si va avanti.
      expect(find.text('Quando ti alleni?'), findsOneWidget);
      expect(find.text('Scegli almeno un giorno'), findsOneWidget);
      await tester.tap(find.text('Lun'));
      await tester.tap(find.text('Gio'));
      await tester.pumpAndSettle();
      expect(find.text('Nessuna scadenza'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
      await tester.pumpAndSettle();

      // Schede: c'è già "Scheda A", ma senza esercizi non si va avanti.
      expect(find.text('Le tue schede'), findsOneWidget);
      expect(find.text('Scheda A'), findsOneWidget);
      expect(find.text('Ogni scheda ha bisogno di esercizi'), findsOneWidget);

      // Apro la scheda e scelgo due esercizi dalla libreria.
      await tester.tap(find.text('Scheda A'));
      await tester.pumpAndSettle();
      expect(find.text('Nessun esercizio'), findsOneWidget);
      await tester.tap(find.text('Aggiungi esercizi'));
      await tester.pumpAndSettle();
      // La libreria è divisa per gruppi: Petto è la prima sezione.
      expect(find.text('Petto'), findsOneWidget);
      await tester.tap(find.text('Chest press'));
      await tester.tap(find.text('Pec deck (butterfly)'));
      await tester.pump();
      await tester.tap(find.text('Aggiungi (2)'));
      await tester.pumpAndSettle();

      // Ci sono, con serie e recupero di default.
      expect(find.text('Chest press'), findsOneWidget);
      expect(find.text('3 × 10 · rec. 90"'), findsNWidgets(2));

      // Cambio le serie della chest press: 4.
      await tester.tap(find.text('Chest press'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Serie: più'));
      await tester.pump();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(find.text('4 × 10 · rec. 90"'), findsOneWidget);

      // Torno alle schede: ora "Avanti" si accende.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('2 esercizi'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
      await tester.pumpAndSettle();

      // La pesata: venerdì già scelto, la cambio in domenica.
      expect(find.text('Quando ti pesi?'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ven')).selected, isTrue);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dom'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
      await tester.pumpAndSettle();

      // Il riepilogo, e dove si cambia tutto dopo.
      expect(find.text('Tutto pronto, Mario!'), findsOneWidget);
      expect(find.text('1 scheda · lun · gio'), findsOneWidget);
      expect(find.text('Pesata ogni domenica'), findsOneWidget);
      expect(find.textContaining('toccando il cerchio del profilo'), findsOneWidget);

      // "Entra" salva la scheda su file: serve tempo vero (vedi pumpUntil).
      await tester.tap(find.text('Entra'));
      await pumpUntil(tester, () => find.text('Chest press').evaluate().isNotEmpty);

      // Onboarding finito: le tab, il profilo e la scheda sono salvati.
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(profile.onboardingDone, isTrue);
      expect(profile.name, 'Mario Rossi');
      expect(profile.weighInWeekday, DateTime.sunday);
      expect(userData.hasPlan, isTrue);
    });

    testWidgets('la freccia indietro torna alla pagina prima', (tester) async {
      await pumpApp(tester);
      expect(find.byTooltip('Indietro'), findsNothing);

      await tester.tap(find.text('Iniziamo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Indietro'));
      await tester.pumpAndSettle();
      expect(find.text('Iniziamo'), findsOneWidget);
    });

    testWidgets('dal profilo si cambia il nome', (tester) async {
      final profile = await pumpApp(tester);
      await profile.completeOnboarding(name: 'Mario Rossi');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Profilo e impostazioni'));
      await tester.pumpAndSettle();
      expect(find.text('Mario Rossi'), findsOneWidget);

      await tester.tap(find.byTooltip('Cambia nome'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Luca Bianchi');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(profile.name, 'Luca Bianchi');
      expect(find.text('Luca Bianchi'), findsOneWidget);
      // L'avatar nell'header e quello nel pannello: entrambi "LB".
      expect(find.text('LB'), findsNWidgets(2));
    });

    testWidgets('dal profilo si cambia il giorno della pesata', (tester) async {
      final profile = await pumpApp(tester);
      await profile.completeOnboarding(name: 'Mario Rossi');
      await tester.pumpAndSettle();
      expect(profile.weighInWeekday, DateTime.friday);

      await tester.tap(find.byTooltip('Profilo e impostazioni'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifica giorno pesata (Attualmente è venerdì)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lun'));
      await tester.pump();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(profile.weighInWeekday, DateTime.monday);
      expect(find.text('Modifica giorno pesata (Attualmente è lunedì)'), findsOneWidget);
    });

    testWidgets("finito l'onboarding le tab sono vuote: niente dati di altri", (tester) async {
      final profile = await pumpApp(tester);
      await profile.completeOnboarding(name: 'Mario Rossi');
      await tester.pumpAndSettle();

      expect(find.text('Nessuna scheda'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Nessuna dieta'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Nessuna lista della spesa'), findsOneWidget);
    });
  });
}
