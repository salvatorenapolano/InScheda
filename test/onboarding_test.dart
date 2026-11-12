import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/focus_alerts.dart';
import 'package:my_workout/data/focus_store.dart';
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
      // Di default la vista guidata, con video e consigli.
      expect(profile.essentialView, isFalse);
    });

    test('la vista essenziale si salva e resta dopo il riavvio', () async {
      SharedPreferences.setMockInitialValues({});
      final profile = await ProfileStore.load();
      await profile.completeOnboarding(name: 'Mario', essentialView: true);
      expect(profile.essentialView, isTrue);

      await profile.setEssentialView(false);
      expect((await ProfileStore.load()).essentialView, isFalse);
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
        focus: await FocusStore.load(alerts: SilentFocusAlerts()),
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

      // Hai già una scheda? La creo da zero.
      expect(find.text('Hai già una scheda?'), findsOneWidget);
      await tester.tap(find.text('La creo da zero'));
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

      // Prima di inserirli chiede serie e ripetizioni, uno alla volta.
      // Chest press: porto le serie a 4 e aggiungo.
      expect(find.text('Esercizio 1 di 2'), findsOneWidget);
      expect(find.text('Chest press'), findsOneWidget);
      await tester.tap(find.byTooltip('Serie: più'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
      await tester.pumpAndSettle();
      // Pec deck: lascio i valori di partenza.
      expect(find.text('Esercizio 2 di 2'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
      await tester.pumpAndSettle();

      // Ci sono tutti e due, ognuno con le sue serie.
      expect(find.text('4 × 10 · rec. 90"'), findsOneWidget);
      expect(find.text('3 × 10 · rec. 90"'), findsOneWidget);
      // Con il numero d'ordine, come nella tab Allenamento.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // La matita riapre il dialog: le ripetizioni della chest press a 8.
      await tester.tap(find.byTooltip('Modifica Chest press'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8');
      await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
      await tester.pumpAndSettle();
      expect(find.text('4 × 8 · rec. 90"'), findsOneWidget);

      // Torno alle schede: ora "Avanti" si accende.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('2 esercizi'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
      await tester.pumpAndSettle();

      // La vista degli esercizi: guidata già scelta, passo all'essenziale.
      expect(find.text('Come vuoi vedere gli esercizi?'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.text('Essenziale'));
      await tester.pumpAndSettle();
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
      expect(find.textContaining('con la matita accanto al titolo'), findsOneWidget);
      expect(find.textContaining('Google Drive'), findsOneWidget);

      // "Entra" salva la scheda su file: serve tempo vero (vedi pumpUntil).
      await tester.tap(find.text('Entra'));
      // Prima delle tab, una volta sola, il tutorial della modalità Focus.
      await pumpUntil(tester, () => find.text('Modalità Focus').evaluate().isNotEmpty);
      expect(profile.focusTutorialPending, isTrue);
      await tester.tap(find.text('Salta'));
      await pumpUntil(tester, () => find.text('Chest press').evaluate().isNotEmpty);
      expect(profile.focusTutorialPending, isFalse);

      // Onboarding finito: le tab, il profilo e la scheda sono salvati.
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(profile.onboardingDone, isTrue);
      expect(profile.name, 'Mario Rossi');
      expect(profile.weighInWeekday, DateTime.sunday);
      expect(profile.essentialView, isTrue);
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
      // Il tutorial del Focus lo prova il test qui sopra: qui lo saltiamo.
      await profile.markFocusTutorialSeen();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Profilo'));
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

    testWidgets('dalla tab Pesata si cambia il giorno della pesata', (tester) async {
      final profile = await pumpApp(tester);
      await profile.completeOnboarding(name: 'Mario Rossi');
      // Il tutorial del Focus lo prova il test qui sopra: qui lo saltiamo.
      await profile.markFocusTutorialSeen();
      await tester.pumpAndSettle();
      expect(profile.weighInWeekday, DateTime.friday);

      // Il calendario in alto, nella tab Pesata.
      await tester.tap(find.text('Pesata'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Giorno della pesata'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lun'));
      await tester.pump();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(profile.weighInWeekday, DateTime.monday);
    });

    testWidgets("finito l'onboarding le tab sono vuote: niente dati di altri", (tester) async {
      final profile = await pumpApp(tester);
      await profile.completeOnboarding(name: 'Mario Rossi');
      // Il tutorial del Focus lo prova il test qui sopra: qui lo saltiamo.
      await profile.markFocusTutorialSeen();
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
