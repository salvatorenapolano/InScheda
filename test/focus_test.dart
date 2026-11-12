import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/focus_alerts.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/focus/calories.dart';
import 'package:my_workout/features/focus/focus_tutorial_page.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';

import 'helpers/fixtures.dart';

void main() {
  // Chest press 40 kg × 10, 4 serie in scheda: la usano più test.
  const chestPress = StrengthLog(
    group: MuscleGroup.petto,
    loadKg: 40,
    repsPerSet: 10,
    secondsPerSet: 35,
    plannedSets: 4,
  );

  group('Stima delle kcal', () {
    test('senza serie né cardio: 2,5 MET × peso × ore', () {
      expect(estimateKcal(elapsed: const Duration(hours: 1), bodyKg: 80), closeTo(200, 0.01));
      expect(estimateKcal(elapsed: Duration.zero, bodyKg: 80), 0);
    });

    test('il cardio conta coi suoi MET e i minuti scritti, il resto a 2,5', () {
      const cardio = [CardioPart(minutes: 20, met: 6)];
      // 20 min a 6 MET + 40 min a 2,5 MET, per 80 kg.
      expect(
        estimateKcal(elapsed: const Duration(hours: 1), bodyKg: 80, cardio: cardio),
        closeTo((6 * 20 + 2.5 * 40) * 80 / 60, 0.01),
      );
      // Dopo 10 minuti ne è "entrata" metà, e niente altro.
      expect(
        estimateKcal(elapsed: const Duration(minutes: 10), bodyKg: 80, cardio: cardio),
        closeTo(6 * 10 * 80 / 60, 0.01),
      );
    });

    test('una serie: sforzo + lavoro sul carico, per il gruppo muscolare', () {
      // Chest press 40 kg × 10 per 80 kg: sforzo 4,67 + lavoro 1,88 kcal.
      expect(kcalPerSet(chestPress, bodyKg: 80), closeTo(6.54, 0.01));
      // Più carico, più kcal; ma conta di più quanti muscoli muovi.
      const heavier = StrengthLog(group: MuscleGroup.petto, loadKg: 80, repsPerSet: 10, secondsPerSet: 35);
      expect(kcalPerSet(heavier, bodyKg: 80), greaterThan(kcalPerSet(chestPress, bodyKg: 80)));
      const legs = StrengthLog(group: MuscleGroup.gambe, loadKg: 40, repsPerSet: 10, secondsPerSet: 35);
      const curl = StrengthLog(group: MuscleGroup.braccia, loadKg: 40, repsPerSet: 10, secondsPerSet: 35);
      expect(kcalPerSet(legs, bodyKg: 80), greaterThan(kcalPerSet(curl, bodyKg: 80) * 1.8));
    });

    test("serie fatte: un recupero = una serie, più l'ultima, mai oltre la scheda", () {
      expect(chestPress.setsDone, 0);
      final once = chestPress.withRest(loadKg: 40);
      expect(once.setsDone, 2);
      final four = once.withRest(loadKg: 40).withRest(loadKg: 42).withRest(loadKg: 42);
      expect(four.setsDone, 4);
      expect(four.loadKg, 42);
      // Senza serie nella scheda non c'è un tetto.
      const free = StrengthLog(group: MuscleGroup.core, loadKg: 0, repsPerSet: 15, secondsPerSet: 50, rests: 2);
      expect(free.setsDone, 3);
    });

    test('le serie fatte entrano nella stima, il loro tempo esce dal resto', () {
      final log = chestPress.withRest(loadKg: 40); // 2 serie
      final expected = 2 * kcalPerSet(log, bodyKg: 80) + 2.5 * 80 * (60 - 70 / 60) / 60;
      expect(
        estimateKcal(elapsed: const Duration(hours: 1), bodyKg: 80, strength: [log]),
        closeTo(expected, 0.01),
      );
    });

    test('ripetizioni scritte nella scheda → numero', () {
      expect(parseRepsCount('10'), 10);
      expect(parseRepsCount('8–12'), 10);
      expect(parseRepsCount('10 per lato'), 20);
      expect(parseRepsCount('30"'), 30);
      expect(parseRepsCount("1'"), 60);
      expect(parseRepsCount(''), 10);
    });

    test('strengthLogFor: peso salvato, oppure parte del corpo; a tempo niente ripetizioni', () {
      const press = Exercise(
        id: 'chest_press',
        name: 'Chest press',
        category: ExerciseCategory.weights,
        group: MuscleGroup.petto,
        muscles: [],
        description: '',
        tips: [],
        images: [],
      );
      final log = strengthLogFor(
        press,
        const PlannedExercise(exerciseId: 'chest_press', sets: 4, reps: '8–12'),
        savedKg: 40,
        bodyKg: 80,
      );
      expect(log.loadKg, 40);
      expect(log.repsPerSet, 10);
      expect(log.secondsPerSet, 35);
      expect(log.plannedSets, 4);

      const plank = Exercise(
        id: 'plank',
        name: 'Plank',
        category: ExerciseCategory.abs,
        group: MuscleGroup.core,
        muscles: [],
        description: '',
        tips: [],
        images: [],
        measure: ExerciseMeasure.time,
      );
      final hold = strengthLogFor(
        plank,
        const PlannedExercise(exerciseId: 'plank', sets: 3, reps: '30"'),
        savedKg: null,
        bodyKg: 80,
      );
      expect(hold.loadKg, 24);
      expect(hold.repsPerSet, 0);
      expect(hold.secondsPerSet, 30);
    });

    test('tapis roulant con le formule ACSM', () {
      // 5,5 km/h al 5%: camminata in salita, circa 6 MET.
      expect(treadmillMet(speedKmh: 5.5, inclinePercent: 5), closeTo(5.97, 0.01));
      // In piano si consuma meno, correndo di più.
      expect(treadmillMet(speedKmh: 5.5), lessThan(treadmillMet(speedKmh: 5.5, inclinePercent: 5)));
      expect(treadmillMet(speedKmh: 10), greaterThan(9));
    });
  });

  test('colori delle schede: 6, poi si ricomincia', () {
    expect(workoutColor(0), workoutPalette.first);
    expect(workoutColor(1), isNot(workoutColor(0)));
    // La settima scheda torna al colore della prima.
    expect(workoutColor(6), workoutColor(0));
    expect(workoutColor(7), workoutColor(1));
  });

  test("la lettera della scheda per i bollini dello storico", () {
    expect(workoutInitial('Scheda A'), 'A');
    expect(workoutInitial('Scheda 2'), '2');
    expect(workoutInitial('Push'), 'P');
    expect(workoutInitial('gambe e glutei'), 'G');
    expect(workoutInitial(''), '?');
  });

  test('formatClock e formatDurationShort', () {
    expect(formatClock(const Duration(seconds: 75)), '1:15');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
    expect(formatDurationShort(const Duration(minutes: 42)), '42 min');
    expect(formatDurationShort(const Duration(minutes: 65)), '1 h 05 min');
    expect(formatKcal(245.6), '~246 kcal');
  });

  group('FocusStore', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('start, recupero, termina: lo storico resta dopo il riavvio', () async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 11, 11, 18);
      final alerts = SilentFocusAlerts();
      final focus = await FocusStore.load(alerts: alerts, now: () => now);
      expect(focus.isActive, isFalse);

      await focus.start(workoutId: 'push', workoutName: 'Push', bodyKg: 80);
      now = now.add(const Duration(minutes: 30));
      expect(focus.elapsed, const Duration(minutes: 30));
      expect(focus.kcal, closeTo(100, 0.01));

      // Il recupero conta (e vale come serie della chest press); il timer
      // del cardio no.
      await focus.startTimer(key: 'chest_press', label: 'Chest press', seconds: 90, strength: chestPress);
      expect(focus.rest?.key, 'chest_press');
      expect(focus.restLeft, const Duration(seconds: 90));
      await focus.startTimer(key: 'tapis', label: 'Tapis', seconds: 600, countsAsRest: false);
      await focus.stopTimer();
      expect(focus.rest, isNull);
      expect(focus.active?.rests, 1);

      // Riaprendo l'app a metà, il Focus c'è ancora.
      final reopened = await FocusStore.load(alerts: alerts, now: () => now);
      expect(reopened.active?.workoutName, 'Push');
      expect(reopened.active?.rests, 1);
      expect(reopened.active?.strength['chest_press']?.setsDone, 2);

      now = now.add(const Duration(minutes: 15));
      final session = await focus.finish(save: true);
      expect(session?.duration, const Duration(minutes: 45));
      expect(focus.isActive, isFalse);

      final later = await FocusStore.load(alerts: alerts);
      expect(later.isActive, isFalse);
      expect(later.history.single.workoutName, 'Push');
      expect(later.history.single.rests, 1);
      // 2 serie di chest press + il resto dei 45 minuti a 2,5 MET.
      final expected = 2 * kcalPerSet(chestPress, bodyKg: 80) + 2.5 * 80 * (45 - 70 / 60) / 60;
      expect(later.history.single.kcal, closeTo(expected, 0.01));

      await later.deleteSession(later.history.single);
      expect((await FocusStore.load(alerts: alerts)).history, isEmpty);
    });

    test('il colore della scheda resta nello storico', () async {
      SharedPreferences.setMockInitialValues({});
      final focus = await FocusStore.load(alerts: SilentFocusAlerts());
      await focus.start(workoutId: 'legs', workoutName: 'Legs', bodyKg: 80, colorIndex: 2);
      expect((await FocusStore.load(alerts: SilentFocusAlerts())).active?.colorIndex, 2);
      await focus.finish(save: true);
      expect((await FocusStore.load(alerts: SilentFocusAlerts())).history.single.colorIndex, 2);
    });

    test('scartato non finisce nello storico', () async {
      SharedPreferences.setMockInitialValues({});
      final focus = await FocusStore.load(alerts: SilentFocusAlerts());
      await focus.start(workoutId: 'push', workoutName: 'Push', bodyKg: 80);
      expect(await focus.finish(save: false), isNull);
      expect(focus.history, isEmpty);
    });
  });

  group('Modalità Focus nell\'app', () {
    setUpAll(() {
      ExerciseMedia.videoEnabled = false;
      // Un'animazione infinita non lascerebbe mai "assestare" pumpAndSettle.
      FocusGlow.animate = false;
    });
    setUp(() => rootBundle.clear());

    late DateTime now;
    late SilentFocusAlerts alerts;
    late FocusStore focus;
    late BodyWeightStore bodyWeights;

    Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}, bool exact = true}) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi', ...prefs});
      now = DateTime(2026, 11, 11, 18);
      alerts = SilentFocusAlerts(exact: exact);
      focus = await FocusStore.load(alerts: alerts, now: () => now);
      bodyWeights = await BodyWeightStore.load();
      await tester.pumpWidget(MyWorkoutApp(
        weights: await WeightStore.load(),
        bodyWeights: bodyWeights,
        shopping: await ShoppingStore.load(),
        profile: await ProfileStore.load(),
        userData: UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente')),
        focus: focus,
        assets: FixtureBundle(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('inizio, recupero che vibra, termino e lo ritrovo nello storico', (tester) async {
      await pumpApp(tester);
      expect(find.byType(FocusGlow), findsOneWidget);
      expect(find.byTooltip('Allenamento in corso'), findsNothing);

      // La pillola verde nel banner (col tooltip per esteso). Senza pesate chiede il peso.
      expect(find.byTooltip('Inizia allenamento'), findsOneWidget);
      await tester.tap(find.text('Inizia'));
      await tester.pumpAndSettle();
      expect(find.text('Quanto pesi?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '80');
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      // Il Focus è partito: banner, cronometro nell'header, peso salvato.
      expect(focus.isActive, isTrue);
      expect(bodyWeights.entries.single.kg, 80);
      expect(find.textContaining('Focus: '), findsOneWidget);
      expect(find.byTooltip('Allenamento in corso'), findsOneWidget);
      expect(find.text('Inizia'), findsNothing);

      // Passano 10 minuti: il cronometro li mostra.
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('10:00'), findsOneWidget);

      // Il dettaglio della chest press: timer al posto del video.
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Chest press'), 200);
      await tester.tap(find.text('Chest press'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseMedia), findsNothing);
      expect(find.text('2:00'), findsOneWidget);
      // Il video c'è, ma chiuso in un pannello.
      expect(find.text('Video'), findsOneWidget);

      await tester.tap(find.text('Avvia recupero'));
      await tester.pump();
      expect(find.text('Recupero in corso'), findsOneWidget);
      expect(find.text('Ferma'), findsOneWidget);

      // Finiti i 2 minuti il telefono vibra e il timer torna pronto.
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();
      expect(alerts.vibrations, 1);
      expect(find.text('Avvia recupero'), findsOneWidget);

      // Il pannello del video si apre.
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseMedia), findsOneWidget);

      // Torno indietro e termino dal cronometro nell'header.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      now = now.add(const Duration(minutes: 33));
      await tester.tap(find.byTooltip('Allenamento in corso'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Focus: '), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Termina allenamento'));
      await tester.pumpAndSettle();
      expect(find.text("Terminare l'allenamento?"), findsOneWidget);
      // "Termina" c'è anche nella pillola del banner: tocco quello del dialog.
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Termina')));
      await tester.pumpAndSettle();
      expect(find.textContaining('fatto!'), findsOneWidget);
      expect(find.text('45:00'), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      // Focus finito: niente cronometro, il pulsante verde è tornato.
      expect(focus.isActive, isFalse);
      expect(find.byTooltip('Allenamento in corso'), findsNothing);
      // La lista è scorsa giù: torno in cima, dove c'è il banner.
      await tester.scrollUntilVisible(find.text('Inizia'), -200);
      expect(find.text('Inizia'), findsOneWidget);

      // Dal profilo: Storico allenamenti.
      await tester.tap(find.byTooltip('Profilo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Storico allenamenti'));
      await tester.pumpAndSettle();
      expect(find.text('Storico allenamenti'), findsOneWidget);
      expect(find.text(focus.history.single.workoutName), findsOneWidget);
      // Le kcal dipendono dal cardio della scheda (qui la camminata finale):
      // controlliamo durata e recuperi, le kcal le prova il test della stima.
      expect(find.textContaining('45 min · ~'), findsOneWidget);
      expect(find.textContaining('kcal · 1 recupero'), findsOneWidget);
    });

    testWidgets('senza "Sveglie e promemoria" lo spiega una volta sola', (tester) async {
      await pumpApp(tester, exact: false, prefs: {
        'body_weights': '[{"date":"2026-11-10","kg":75.0}]',
      });

      await tester.tap(find.text('Inizia'));
      await tester.pumpAndSettle();
      // C'è già una pesata: non chiede il peso, ma spiega il permesso.
      expect(find.text('Quanto pesi?'), findsNothing);
      expect(find.text('Avvisi a fine recupero'), findsOneWidget);
      await tester.tap(find.text('Più tardi'));
      await tester.pumpAndSettle();
      expect(focus.isActive, isTrue);
      expect(focus.active?.bodyKg, 75);
      expect(focus.exactAlarmAsked, isTrue);

      // Scarto: non finisce nello storico.
      await tester.tap(find.text('Termina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scarta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Scarta'));
      await tester.pumpAndSettle();
      expect(focus.isActive, isFalse);
      expect(focus.history, isEmpty);
    });

    testWidgets('il tutorial si sfoglia fino a "Ho capito"', (tester) async {
      var done = false;
      await tester.pumpWidget(MaterialApp(home: FocusTutorialPage(onDone: () => done = true)));
      expect(find.text('Modalità Focus'), findsOneWidget);
      for (final title in ['Il cronometro', 'Il recupero', 'Lo storico']) {
        await tester.tap(find.text('Avanti'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Ho capito'));
      expect(done, isTrue);
    });
  });
}
