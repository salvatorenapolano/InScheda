import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/planned_exercise_dialog.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';

void main() {
  final library = WorkoutRepository.parse(
    planJson: null,
    exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
  ).exercises;

  test('ogni esercizio ha la misura giusta', () {
    final cardio = [for (final e in library.values) if (e.measure == ExerciseMeasure.cardio) e.id];
    final timed = [for (final e in library.values) if (e.measure == ExerciseMeasure.time) e.id];
    expect(cardio, ['tapis_roulant', 'cyclette', 'stair_climber']);
    expect(timed, ['plank', 'plank_laterale']);
    expect(library['tapis_roulant']!.cardioSettings, [CardioSetting.speed, CardioSetting.incline]);
    expect(library['cyclette']!.cardioSettings, [CardioSetting.level]);
    // Il cardio non ha "Il tuo peso" ed è nel suo gruppo.
    for (final id in cardio) {
      expect(library[id]!.hasWeight, isFalse, reason: id);
      expect(library[id]!.group, MuscleGroup.cardio, reason: id);
    }
    expect(library['cardio_riscaldamento'], isNull, reason: 'ora si chiama tapis_roulant');
  });

  test('i valori di partenza dipendono dalla misura', () {
    PlannedExercise start(String id) => PlanDraft.defaultsFor(id, library[id]);

    expect(formatPlanned(start('tapis_roulant')), '20 min · 5,5 km/h · pendenza 5%');
    expect(formatPlanned(start('cyclette')), '20 min · livello 5');
    expect(formatPlanned(start('plank')), '3 × 30" · rec. 60"');
    // La mobilità del riscaldamento: solo ripetizioni, niente serie né recupero.
    expect(formatPlanned(start('dislocazioni_bastone')), '10');
    expect(formatPlanned(start('chest_press')), '3 × 10 · rec. 90"');
    // Il cardio non ha serie né recupero.
    expect(start('stair_climber').sets, isNull);
    expect(start('stair_climber').restSeconds, isNull);
  });

  test('il cardio fa andata e ritorno in JSON, senza ripetizioni', () {
    const planned = PlannedExercise(exerciseId: 'tapis_roulant', durationMinutes: 30, speedKmh: 5.5, inclinePercent: 10);
    final json = planned.toJson();
    expect(json.containsKey('reps'), isFalse);
    final again = PlannedExercise.fromJson(json);
    expect(again.isCardio, isTrue);
    expect(formatPlanned(again), '30 min · 5,5 km/h · pendenza 10%');
  });

  test('secondi: da numero a testo e ritorno', () {
    expect(formatSeconds(30), '30"');
    expect(formatSeconds(60), "1'");
    expect(formatSeconds(90), "1'30\"");
    expect(parseSeconds('30"'), 30);
    expect(parseSeconds('20" per lato'), 20);
    expect(parseSeconds("1'30\""), 90);
    expect(parseSeconds('10'), isNull);
  });

  /// Apre il dialog per [planned] e restituisce quello che ha salvato.
  Future<PlannedExercise?> editInDialog(WidgetTester tester, PlannedExercise planned, Future<void> Function() edit) async {
    PlannedExercise? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDialog<PlannedExercise>(
            context: context,
            builder: (_) => PlannedExerciseDialog(planned: planned, exercise: library[planned.exerciseId]),
          ),
          child: const Text('apri'),
        ),
      ),
    ));
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await edit();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('tapis roulant: durata, velocità e pendenza, niente serie', (tester) async {
    final result = await editInDialog(tester, PlanDraft.defaultsFor('tapis_roulant', library['tapis_roulant']), () async {
      expect(find.text('Serie'), findsNothing);
      expect(find.text('Ripetizioni'), findsNothing);
      expect(find.text('Livello'), findsNothing);
      await tester.tap(find.byTooltip('Velocità: più'));
      await tester.tap(find.byTooltip('Pendenza: più'));
      await tester.tap(find.byTooltip('Durata: più'));
      await tester.pump();
    });
    expect(formatPlanned(result!), '21 min · 6 km/h · pendenza 5,5%');
  });

  testWidgets('cyclette: solo durata e livello', (tester) async {
    final result = await editInDialog(tester, PlanDraft.defaultsFor('cyclette', library['cyclette']), () async {
      expect(find.text('Velocità'), findsNothing);
      await tester.tap(find.byTooltip('Livello: più'));
      await tester.pump();
    });
    expect(formatPlanned(result!), '20 min · livello 6');
  });

  testWidgets('plank laterale: secondi per lato', (tester) async {
    const planned = PlannedExercise(exerciseId: 'plank_laterale', reps: '20" per lato');
    final result = await editInDialog(tester, planned, () async {
      expect(find.text('20"'), findsOneWidget);
      await tester.tap(find.byTooltip('Durata: più'));
      await tester.pump();
    });
    expect(formatPlanned(result!), '25" per lato');
  });
}
