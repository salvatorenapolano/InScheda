import 'dart:convert';
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
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_import/plan_import.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/exercise.dart';

import 'helpers/real_io.dart';

void main() {
  // La libreria vera, come nell'app.
  Map<String, Exercise> library() => WorkoutRepository.parse(
        planJson: null,
        exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
      ).exercises;
  final today = DateTime(2026, 11, 11);

  /// Una risposta "come quelle vere": frasi intorno, ```json, virgola di troppo,
  /// numeri scritti come testo, recuperi in minuti, un nome invece dell'id…
  const messyAnswer = '''
Ecco la tua scheda trascritta!

```json
{
  "inscheda": 1,
  "type": "workout",
  "weekdays": ["lun", "Mercoledì", 5],
  "endDate": "2026-12-23",
  "workouts": [
    {
      "name": "Push",
      "exercises": [
        { "exerciseId": "chest_press", "sets": "4", "reps": "8-10", "restSeconds": "1'30\\"" },
        { "name": "Pec deck (Butterfly)", "sets": 3, "reps": "12", "restSeconds": 60 },
        { "name": "Panca declinata con bilanciere", "group": "petto", "sets": 3, "reps": "10", "restSeconds": "2'" },
        { "exerciseId": "chest_press", "sets": 2, "reps": "15" },
        { "exerciseId": "plank", "sets": 3, "reps": "30" },
        { "exerciseId": "tapis_roulant", "reps": "20 min", "speedKmh": "5,5", "inclinePercent": 10, "level": 4 },
      ]
    },
    { "name": "Vuota", "exercises": [] }
  ],
  "warnings": ["Non ero sicuro della panca declinata"]
}
```

Fammi sapere se vuoi cambiare qualcosa.
''';

  group('il prompt', () {
    test('contiene il formato, le regole e tutta la libreria', () {
      final lib = library();
      final prompt = buildPlanPrompt(lib.values);
      expect(prompt, contains('"type": "workout"'));
      expect(prompt, contains('Non inventare mai un id'));
      expect(prompt, contains('chest_press | Chest press | petto | reps'));
      expect(prompt, contains('plank | Plank | core | time'));
      expect(prompt, contains('tapis_roulant | Tapis roulant | cardio | cardio | speedKmh, inclinePercent'));
      // Tutti gli esercizi, uno per riga.
      for (final id in lib.keys) {
        expect(prompt, contains('\n$id | '));
      }
    });
  });

  group('extractJson', () {
    test('dentro ```json, o tra la prima { e l\'ultima }', () {
      expect(extractJson('Ecco:\n```json\n{"a": 1}\n```\nCiao'), '{"a": 1}');
      expect(extractJson('Ecco la scheda: {"a": {"b": 2}} fine'), '{"a": {"b": 2}}');
    });

    test('senza JSON: un errore che dice cosa fare', () {
      expect(
        () => extractJson('Non riesco a leggere il PDF, puoi mandarlo di nuovo?'),
        throwsA(isA<PlanImportException>().having((e) => e.message, 'message', contains('Copia tutta la risposta'))),
      );
    });
  });

  group('parsePlanImport', () {
    test('una risposta "sporca" si legge lo stesso', () {
      final lib = library();
      final result = parsePlanImport(messyAnswer, lib, today: today);

      expect(result.weekdays, [1, 3, 5]);
      expect(result.endDate, DateTime(2026, 12, 23));
      // La scheda vuota è saltata (con un avviso).
      expect(result.workouts.map((w) => w.name), ['Push']);

      final push = result.workouts.single.exercises;
      // chest_press compare due volte: resta la prima.
      expect(push.map((p) => p.exerciseId), [
        'chest_press',
        'pec_deck', // trovato per nome, maiuscole a parte
        'personale_panca_declinata_con_bilanciere',
        'plank',
        'tapis_roulant',
      ]);
      final chest = push[0];
      expect(chest.sets, 4);
      expect(chest.reps, '8–10'); // trattino lungo, come nell'app
      expect(chest.restSeconds, 90); // 1'30"
      expect(push[2].restSeconds, 120); // 2'
      expect(push[3].reps, '30"'); // il plank è a tempo

      final tapis = push[4];
      expect(tapis.durationMinutes, 20); // preso da "20 min"
      expect(tapis.speedKmh, 5.5);
      expect(tapis.inclinePercent, 10);
      expect(tapis.level, isNull); // il tapis non ha il livello
      expect(tapis.reps, isEmpty);

      final created = result.newExercises.single;
      expect(created.name, 'Panca declinata con bilanciere');
      expect(created.group, MuscleGroup.petto);
      expect(created.custom, isTrue);

      expect(result.warnings, contains('Non ero sicuro della panca declinata'));
      expect(result.warnings.any((w) => w.contains('due volte')), isTrue);
      expect(result.warnings.any((w) => w.contains('"Vuota" non ha esercizi')), isTrue);
    });

    test('date passate, giorni sbagliati e gruppi sconosciuti finiscono negli avvisi', () {
      final result = parsePlanImport(
        '{"weekdays": [1, "boh", 9], "endDate": "2026-01-01", "workouts": [{"exercises": ['
        '{"name": "Esercizio misterioso", "group": "astronauta", "reps": "10"},'
        '{"name": "Stretching a tempo", "group": "riscaldamento", "reps": "45 sec"}]}]}',
        library(),
        today: today,
      );
      expect(result.weekdays, [1]);
      expect(result.endDate, isNull);
      expect(result.workouts.single.name, 'Scheda A'); // senza nome
      expect(result.newExercises.first.group, MuscleGroup.petto);
      expect(result.newExercises.last.measure, ExerciseMeasure.time);
      expect(result.warnings.where((w) => w.contains('giorno')), hasLength(2));
      expect(result.warnings.any((w) => w.contains('già passata')), isTrue);
      expect(result.warnings.any((w) => w.contains('Petto')), isTrue);
    });

    test('un esercizio ripetuto in due schede diventa UN solo esercizio personale', () {
      final result = parsePlanImport(
        '{"workouts": ['
        '{"name": "A", "exercises": [{"name": "Face pull", "group": "spalle"}]},'
        '{"name": "B", "exercises": [{"name": "face pull", "group": "spalle"}]}]}',
        library(),
        today: today,
      );
      expect(result.newExercises, hasLength(1));
      expect(result.workouts.map((w) => w.exercises.single.exerciseId), ['personale_face_pull', 'personale_face_pull']);
    });

    test('errori chiari: non è una scheda, non ci sono esercizi, JSON rotto', () {
      Matcher fails(String text) => throwsA(isA<PlanImportException>().having((e) => e.message, 'message', contains(text)));
      expect(() => parsePlanImport('{"type": "diet", "workouts": []}', library(), today: today), fails('non è una scheda'));
      expect(() => parsePlanImport('{"workouts": []}', library(), today: today), fails('non ci sono schede'));
      expect(
        () => parsePlanImport('{"workouts": [{"name": "A", "exercises": []}]}', library(), today: today),
        fails('nessun esercizio'),
      );
      expect(() => parsePlanImport('{"workouts": [{"name": "A", "exer', library(), today: today), fails('Copia tutta'));
      expect(() => parsePlanImport('{"workouts": [{"name": "A" "x": 1}]}', library(), today: today), fails('non è scritta bene'));
    });
  });

  test('nella bozza: diventa una scheda valida, con gli esercizi nuovi', () {
    final lib = library();
    final result = parsePlanImport(messyAnswer, lib, today: today);
    final draft = PlanDraft()
      ..replaceWith(
        weekdays: result.weekdays,
        endDate: result.endDate,
        workouts: [for (final w in result.workouts) (w.name, w.exercises)],
      );
    expect(draft.hasDays, isTrue);
    expect(draft.workoutsReady, isTrue);

    final plan = draft.toPlan(today: today);
    expect(plan.schedule.weekdays, [1, 3, 5]);
    expect(plan.workouts.single.id, 'scheda_1');

    // Salvata con gli esercizi personali, si rilegge senza errori.
    final again = WorkoutRepository.parse(
      planJson: jsonEncode(plan.toJson()),
      exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
      customExercisesJson: jsonEncode([for (final e in result.newExercises) e.toJson()]),
    );
    expect(again.plan!.workouts.single.exercises, hasLength(5));
  });

  testWidgets('onboarding: Ho un PDF, incollo la risposta, Usa questa scheda', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    final userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));
    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      focus: await FocusStore.load(alerts: SilentFocusAlerts()),
      userData: userData,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniziamo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mario Rossi');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ho un PDF o una foto'));
    await tester.pumpAndSettle();
    expect(find.text('Importa la scheda'), findsOneWidget);
    expect(find.text('Usa questa scheda'), findsNothing);

    // Incollo una risposta senza JSON: l'errore lo dice.
    await tester.enterText(find.byType(TextField), 'Scusa, non riesco ad aprire il PDF.');
    await tester.pump();
    expect(find.textContaining('Copia tutta la risposta'), findsOneWidget);

    // Ora quella buona: anteprima e pulsante.
    await tester.enterText(find.byType(TextField), messyAnswer);
    await tester.pumpAndSettle();
    expect(find.text('Scheda letta'), findsOneWidget);
    expect(find.textContaining('1 scheda · lun, mer, ven · 5 esercizi'), findsOneWidget);
    expect(find.textContaining('1 esercizio nuovo, che non è nella libreria'), findsOneWidget);

    await tester.tap(find.text('Usa questa scheda'));
    // L'esercizio nuovo si scrive su file: tempo vero.
    await pumpUntil(tester, () => find.text('Quando ti alleni?').evaluate().isNotEmpty);
    expect(userData.hasCustomExercises, isTrue);

    // I giorni sono già scelti: Avanti è acceso, e la scheda c'è.
    await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('5 esercizi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Avanti'), findsOneWidget);
  });
}
