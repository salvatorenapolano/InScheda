import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/data_bundle.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/workout_plan.dart';

import 'helpers/fixtures.dart';

/// Una scheda come la creerà l'editor: niente orario, niente data di fine,
/// niente riscaldamento/addominali/cardio. Due schede col nome scelto.
WorkoutPlan userPlan({List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7]}) {
  final today = DateTime.now();
  return WorkoutPlan(
    name: 'La mia scheda',
    startDate: DateTime(today.year, today.month, today.day),
    schedule: Schedule(weekdays: weekdays),
    workouts: const [
      Workout(id: 'a', name: 'Giorno A', exercises: [
        PlannedExercise(exerciseId: 'chest_press', sets: 3, reps: '10', restSeconds: 90),
      ]),
      Workout(id: 'b', name: 'Giorno B', exercises: [
        PlannedExercise(exerciseId: 'hack_squat', sets: 4, reps: '8–10', restSeconds: 120),
      ]),
    ],
  );
}

void main() {
  // Serve per leggere gli asset (rootBundle) fuori da testWidgets.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('toJson', () {
    test('la scheda di esempio fa andata e ritorno senza perdere niente', () {
      final original = jsonDecode(fixture('workout_plan.json'));
      final plan = WorkoutPlan.fromJson(original as Map<String, dynamic>);
      // Da oggetto a JSON e di nuovo a oggetto: deve tornare identica.
      final again = WorkoutPlan.fromJson(jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
      expect(again.toJson(), plan.toJson());
      expect(again.sessions, hasLength(17));
      expect(again.cardio!.speedKmh, 5.5);
    });

    test('i campi vuoti non finiscono nel JSON', () {
      final json = userPlan().toJson();
      expect(json.containsKey('endDate'), isFalse);
      expect(json.containsKey('cardio'), isFalse);
      expect(json['schedule'], {'weekdays': [1, 2, 3, 4, 5, 6, 7]});
      final firstExercise = (json['workouts'] as List).first['exercises'][0] as Map;
      expect(firstExercise.containsKey('notes'), isFalse);
      expect(json['startDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('Scheda senza data di fine', () {
    test('le sedute continuano e alternano le schede nell\'ordine scritto', () {
      final plan = userPlan(weekdays: const [DateTime.monday, DateTime.thursday]);
      // take(6): ne chiediamo solo 6, il generatore non va oltre.
      final sessions = plan.sessions.take(6).toList();
      expect(sessions.map((s) => s.workoutId), ['a', 'b', 'a', 'b', 'a', 'b']);
      expect(sessions.every((s) => s.date.weekday == DateTime.monday || s.date.weekday == DateTime.thursday), isTrue);

      // Anche tra due anni c'è una prossima seduta.
      final later = DateTime.now().add(const Duration(days: 730));
      expect(plan.nextSessionFrom(later), isNotNull);
    });

    test('senza giorni non ci sono sedute (e niente ciclo infinito)', () {
      final plan = userPlan(weekdays: const []);
      expect(plan.sessions, isEmpty);
      expect(plan.nextSessionFrom(DateTime.now()), isNull);
    });
  });

  group('UserDataStore', () {
    late Directory root;

    setUp(() {
      rootBundle.clear();
      root = Directory.systemTemp.createTempSync('my_workout_utente');
    });

    test('senza scheda dell\'utente non c\'è nessuna scheda, ma la libreria sì', () async {
      final store = await UserDataStore.open(root);
      expect(store.hasPlan, isFalse);
      final data = await WorkoutRepository(bundle: store.bundleOver(rootBundle)).load();
      // L'app non ha più una scheda sua: al primo avvio si parte vuoti.
      expect(data.plan, isNull);
      expect(data.exercises['chest_press']?.name, 'Chest press');
    });

    test('salvata la scheda, l\'app legge quella (e la libreria resta dell\'app)', () async {
      final store = await UserDataStore.open(root);
      var notified = 0;
      store.addListener(() => notified++);

      await store.savePlan(userPlan());
      expect(store.hasPlan, isTrue);
      expect(store.revision, 1);
      expect(notified, 1);

      final data = await WorkoutRepository(bundle: store.bundleOver(rootBundle)).load();
      expect(data.plan!.workouts.map((w) => w.name), ['Giorno A', 'Giorno B']);
      // La scheda è dell'utente, ma il "come si fa" arriva dagli asset.
      expect(data.exerciseFor(data.plan!.workouts.first.exercises.first).name, 'Chest press');

      // Riaprendo (= riavvio dell'app) la scheda c'è ancora.
      final reopened = await UserDataStore.open(root);
      expect(reopened.hasPlan, isTrue);
    });

    test('cancellata la scheda, non ce n\'è più nessuna', () async {
      final store = await UserDataStore.open(root);
      await store.savePlan(userPlan());
      await store.deletePlan();
      expect(store.hasPlan, isFalse);
      final data = await WorkoutRepository(bundle: store.bundleOver(rootBundle)).load();
      expect(data.plan, isNull);
    });

    test('il bundle si riusa finché non cambia niente', () async {
      final store = await UserDataStore.open(root);
      final first = store.bundleOver(rootBundle);
      expect(store.bundleOver(rootBundle), same(first));

      await store.savePlan(userPlan());
      expect(store.bundleOver(rootBundle), isNot(same(first)));

      // Cambia il piano di sotto: bundle nuovo.
      final afterSave = store.bundleOver(rootBundle);
      expect(store.bundleOver(DataBundle()), isNot(same(afterSave)));
    });
  });

  testWidgets('la tab Allenamento mostra la scheda dell\'utente', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});
    // I file veri vanno scritti fuori dal "tempo finto" dei widget test.
    final userData = (await tester.runAsync(() async {
      final store = await UserDataStore.open(Directory.systemTemp.createTempSync('my_workout_utente'));
      await store.savePlan(userPlan());
      return store;
    }))!;

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      userData: userData,
    ));
    // La pagina legge file veri dal disco (exists, poi readAsBytes...).
    // Nei widget test il tempo è "finto": runAsync concede tempo vero per
    // l'I/O, pump() fa proseguire il codice che aspettava. Si alternano
    // finché la rotellina di caricamento sparisce.
    for (var i = 0; i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // Ci si allena tutti i giorni: oggi tocca la prima scheda.
    expect(find.text('Oggi: Giorno A'), findsOneWidget);
    expect(find.text('Giorno B'), findsOneWidget);
    expect(find.text('Chest press'), findsOneWidget);
    // Niente riscaldamento, addominali e cardio: la scheda non li ha.
    expect(find.text('Riscaldamento'), findsNothing);
    expect(find.text('Cardio'), findsNothing);
    expect(find.text('Push'), findsNothing);
  });
}
