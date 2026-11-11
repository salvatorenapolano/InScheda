import 'dart:convert';
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
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/exercise.dart';

import 'helpers/fixtures.dart';
import 'helpers/real_io.dart';

void main() {
  group('PlanDraft', () {
    test('parte con una "Scheda A" vuota e nessun giorno', () {
      final draft = PlanDraft();
      expect(draft.workouts.map((w) => w.name), ['Scheda A']);
      expect(draft.hasDays, isFalse);
      expect(draft.workoutsReady, isFalse);
    });

    test('giorni: si accendono e si spengono, in ordine', () {
      final draft = PlanDraft();
      draft.toggleWeekday(DateTime.friday);
      draft.toggleWeekday(DateTime.monday);
      draft.toggleWeekday(DateTime.wednesday);
      draft.toggleWeekday(DateTime.wednesday);
      expect(draft.weekdays, [1, 5]);
    });

    test('schede nuove: B, C… con id sempre diversi', () {
      final draft = PlanDraft();
      final b = draft.addWorkout();
      final c = draft.addWorkout();
      expect([b.name, c.name], ['Scheda B', 'Scheda C']);
      draft.removeWorkout(b);
      final again = draft.addWorkout();
      expect(draft.workouts.map((w) => w.id).toSet(), hasLength(3));
      expect(again.id, isNot(c.id));
    });

    test('esercizi: default 3 × 10 rec. 90", niente doppioni, si spostano', () {
      final draft = PlanDraft();
      final a = draft.workouts.first;
      draft.addExercises(a, ['chest_press', 'pec_deck', 'chest_press']);
      expect(a.exercises.map((p) => p.exerciseId), ['chest_press', 'pec_deck']);
      expect(a.exercises.first.sets, 3);
      expect(a.exercises.first.reps, '10');
      expect(a.exercises.first.restSeconds, 90);

      draft.moveExercise(a, 1, 0);
      expect(a.exercises.map((p) => p.exerciseId), ['pec_deck', 'chest_press']);
      draft.removeExercise(a, 0);
      expect(a.exercises.map((p) => p.exerciseId), ['chest_press']);
      expect(draft.workoutsReady, isTrue);
    });

    test('toPlan: parte oggi, niente orario, data di fine facoltativa', () {
      final draft = PlanDraft()
        ..toggleWeekday(1)
        ..toggleWeekday(4)
        ..setEndDate(DateTime(2027, 1, 31, 18, 30));
      draft.addExercises(draft.workouts.first, ['chest_press']);
      final plan = draft.toPlan(today: DateTime(2026, 11, 10, 9));

      expect(plan.startDate, DateTime(2026, 11, 10));
      expect(plan.endDate, DateTime(2027, 1, 31));
      expect(plan.schedule.weekdays, [1, 4]);
      expect(plan.schedule.time, isNull);
      expect(plan.workouts.single.name, 'Scheda A');
      // La prima seduta è il primo lunedì o giovedì da oggi: giovedì 12/11.
      expect(plan.nextSessionFrom(DateTime(2026, 11, 10))?.date, DateTime(2026, 11, 12));
    });

    test('fromPlan: si riparte dalla scheda salvata, con lo stesso inizio', () {
      final original = WorkoutRepository.parse(
        planJson: fixture('workout_plan.json'),
        exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
      ).plan!;
      final draft = PlanDraft.fromPlan(original);
      expect(draft.workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
      expect(draft.weekdays, [1, 3, 5]);

      final again = draft.toPlan(today: DateTime(2030));
      expect(again.startDate, original.startDate);
      expect(again.workouts.first.exercises.length, original.workouts.first.exercises.length);
    });
  });

  test('ogni esercizio della libreria ha un gruppo muscolare', () {
    final library = WorkoutRepository.parse(
      planJson: null,
      exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
    ).exercises;
    // Almeno un esercizio per ogni gruppo: nessuna sezione vuota nell'editor.
    for (final group in MuscleGroup.values) {
      expect(library.values.where((e) => e.group == group), isNotEmpty, reason: group.label);
    }
  });

  testWidgets('dal profilo: Modifica la scheda, aggiungo il sabato e salvo', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});
    final userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      // La scheda di prova (Push/Pull/Legs) al posto degli asset.
      assets: FixtureBundle(),
      profile: await ProfileStore.load(),
      userData: userData,
    ));
    await tester.pumpAndSettle();

    // La matita in alto, nella tab Allenamento.
    await tester.tap(find.byTooltip('Modifica la scheda'));
    await tester.pumpAndSettle();

    // L'editor parte dalla scheda attuale.
    expect(find.text('La tua scheda'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);

    await tester.tap(find.text('Sab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    // Salvare scrive un file vero: aspettiamo che l'editor si chiuda.
    await pumpUntil(tester, () => find.text('La tua scheda').evaluate().isEmpty);

    expect(userData.hasPlan, isTrue);
    final saved = await tester.runAsync(
      () => WorkoutRepository(bundle: userData.bundleOver(FixtureBundle())).load(),
    );
    expect(saved!.plan!.schedule.weekdays, [1, 3, 5, 6]);
    expect(saved.plan!.workouts.map((w) => w.name), ['Push', 'Pull', 'Legs']);
  });

  group('Esercizi personali', () {
    const custom = Exercise(
      id: 'personale_panca_multipower',
      name: 'Panca al multipower',
      category: ExerciseCategory.weights,
      group: MuscleGroup.petto,
      muscles: ['Pettorali'],
      description: '',
      tips: [],
      images: [],
      custom: true,
    );

    test('toJson fa andata e ritorno, e il gruppo decide la famiglia', () {
      final again = Exercise.fromJson(jsonDecode(jsonEncode(custom.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), custom.toJson());
      expect(again.custom, isTrue);
      expect(again.hasWeight, isTrue);
      expect(MuscleGroup.core.category, ExerciseCategory.abs);
      expect(MuscleGroup.riscaldamento.category, ExerciseCategory.warmup);
    });

    test('salvati nei dati dell\'utente, finiscono in fondo alla libreria', () async {
      rootBundle.clear();
      final store = await UserDataStore.open(Directory.systemTemp.createTempSync('my_workout_utente'));
      await store.addCustomExercise(custom);
      await store.addCustomExercise(const Exercise(
        id: 'personale_face_pull',
        name: 'Face pull',
        category: ExerciseCategory.weights,
        group: MuscleGroup.spalle,
        muscles: [],
        description: 'Corda all\'altezza degli occhi.',
        tips: [],
        images: [],
        custom: true,
      ));
      expect(store.hasCustomExercises, isTrue);

      final library = await WorkoutRepository(bundle: store.bundleOver(rootBundle)).loadLibrary();
      // 46 della libreria + i 2 personali, in fondo.
      expect(library, hasLength(48));
      expect(library.keys.skip(46), ['personale_panca_multipower', 'personale_face_pull']);
      expect(library['personale_face_pull']?.group, MuscleGroup.spalle);

      // Riaprendo lo store (riavvio dell'app) ci sono ancora.
      expect((await UserDataStore.open(store.root)).hasCustomExercises, isTrue);
    });
  });

  testWidgets('dalla libreria: Crea un esercizio e aggiungilo alla scheda', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});
    final userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      userData: userData,
      assets: FixtureBundle(),
    ));
    await tester.pumpAndSettle();

    // La matita in alto, nella tab Allenamento.
    await tester.tap(find.byTooltip('Modifica la scheda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi esercizi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crea un esercizio'));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo esercizio'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Panca al multipower');
    await tester.pump();
    await tester.tap(find.text('Crea'));
    // Salvarlo scrive un file: aspettiamo che compaia spuntato.
    await pumpUntil(tester, () => find.text('Aggiungi (1)').evaluate().isNotEmpty);
    expect(userData.hasCustomExercises, isTrue);

    await tester.tap(find.text('Aggiungi (1)'));
    await tester.pumpAndSettle();
    // Un esercizio solo: niente "1 di 1", e si conferma con Aggiungi.
    expect(find.textContaining(' di 1'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();
    // Nella scheda Push, con l'anteprima "P" del colore del petto.
    await tester.scrollUntilVisible(find.text('Panca al multipower'), 200);
    expect(find.text('Panca al multipower'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('aggiungendo, "Annulla" salta l\'esercizio', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      userData: UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente')),
      assets: FixtureBundle(),
    ));
    await tester.pumpAndSettle();
    // La matita in alto, nella tab Allenamento.
    await tester.tap(find.byTooltip('Modifica la scheda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi esercizi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Croci ai cavi'));
    await tester.pump();
    await tester.tap(find.text('Aggiungi (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Croci ai cavi'), findsNothing);
  });
}
