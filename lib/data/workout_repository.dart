import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:my_workout/data/optional_asset.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';

/// Tutto quello che serve alla tab Allenamento, già pronto da usare.
class WorkoutData {
  const WorkoutData({required this.plan, required this.exercises});

  /// null = l'utente non ha ancora una scheda. La libreria invece c'è sempre.
  final WorkoutPlan? plan;

  /// La libreria indicizzata per id: trovare un esercizio è immediato.
  final Map<String, Exercise> exercises;

  /// Da "cosa c'è in scheda" a "come si esegue".
  Exercise exerciseFor(PlannedExercise planned) => exercises[planned.exerciseId]!;
}

/// Legge i file JSON dagli asset e li trasforma in oggetti Dart.
///
/// Le pagine non sanno da dove arrivano i dati: se un giorno la scheda
/// arrivasse da internet, cambieremmo solo questa classe.
class WorkoutRepository {
  WorkoutRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Dove sta la scheda: negli asset dell'app, e allo stesso percorso nelle
  /// cartella dei dati dell'utente.
  static const planPath = 'assets/data/workout_plan.json';
  static const _exercisesPath = 'assets/data/exercises.json';

  /// Gli esercizi creati dall'utente: stesso formato della libreria, ma
  /// solo nella sua cartella (vedi UserDataStore.addCustomExercise).
  static const customExercisesPath = 'assets/data/custom_exercises.json';

  /// `async` + `Future`: leggere un file richiede tempo, quindi la funzione
  /// restituisce subito una "promessa" che si completerà più avanti.
  /// `await` aspetta che la promessa si completi senza bloccare l'app.
  Future<WorkoutData> load() async {
    // La scheda può non esserci (primo avvio): la libreria invece sì.
    final planJson = await _bundle.loadStringOrNull(planPath);
    final exercisesJson = await _bundle.loadString(_exercisesPath);
    final customJson = await _bundle.loadStringOrNull(customExercisesPath);
    return parse(planJson: planJson, exercisesJson: exercisesJson, customExercisesJson: customJson);
  }

  /// Solo la libreria degli esercizi, indicizzata per id: è quello che
  /// serve all'editor della scheda.
  Future<Map<String, Exercise>> loadLibrary() async {
    return parse(
      planJson: null,
      exercisesJson: await _bundle.loadString(_exercisesPath),
      customExercisesJson: await _bundle.loadStringOrNull(customExercisesPath),
    ).exercises;
  }

  /// Trasforma il testo JSON in oggetti. È separata da load() così
  /// i test possono usarla passando direttamente il contenuto dei file.
  ///
  /// [customExercisesJson]: gli esercizi dell'utente, aggiunti in fondo
  /// alla libreria (null = nessuno).
  static WorkoutData parse({required String? planJson, required String exercisesJson, String? customExercisesJson}) {
    final plan = planJson == null
        ? null
        : WorkoutPlan.fromJson(jsonDecode(planJson) as Map<String, dynamic>);

    final exerciseList = [
      for (final json in [exercisesJson, ?customExercisesJson])
        for (final item in jsonDecode(json) as List) Exercise.fromJson(item as Map<String, dynamic>),
    ];
    // "Collection for": costruisce la mappa id -> esercizio in una riga.
    final exercises = {for (final exercise in exerciseList) exercise.id: exercise};

    // Il JSON lo scrivi a mano, quindi un errore di battitura è facile:
    // meglio accorgersene subito con un messaggio chiaro.
    // `?? const []`: senza scheda non c'è niente da controllare.
    for (final planned in plan?.allPlannedExercises ?? const <PlannedExercise>[]) {
      if (!exercises.containsKey(planned.exerciseId)) {
        throw FormatException(
          'workout_plan.json usa "${planned.exerciseId}", '
          'che non esiste in exercises.json',
        );
      }
    }

    return WorkoutData(plan: plan, exercises: exercises);
  }
}
