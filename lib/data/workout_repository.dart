import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';

/// Tutto quello che serve alla tab Allenamento, già pronto da usare.
class WorkoutData {
  const WorkoutData({required this.plan, required this.exercises});

  final WorkoutPlan plan;

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

  static const _planPath = 'assets/data/workout_plan.json';
  static const _exercisesPath = 'assets/data/exercises.json';

  /// `async` + `Future`: leggere un file richiede tempo, quindi la funzione
  /// restituisce subito una "promessa" che si completerà più avanti.
  /// `await` aspetta che la promessa si completi senza bloccare l'app.
  Future<WorkoutData> load() async {
    final planJson = await _bundle.loadString(_planPath);
    final exercisesJson = await _bundle.loadString(_exercisesPath);
    return parse(planJson: planJson, exercisesJson: exercisesJson);
  }

  /// Trasforma il testo JSON in oggetti. È separata da load() così
  /// i test possono usarla passando direttamente il contenuto dei file.
  static WorkoutData parse({required String planJson, required String exercisesJson}) {
    final plan = WorkoutPlan.fromJson(jsonDecode(planJson) as Map<String, dynamic>);

    final exerciseList = (jsonDecode(exercisesJson) as List)
        .map((item) => Exercise.fromJson(item as Map<String, dynamic>));
    // "Collection for": costruisce la mappa id -> esercizio in una riga.
    final exercises = {for (final exercise in exerciseList) exercise.id: exercise};

    // Il JSON lo scrivi a mano, quindi un errore di battitura è facile:
    // meglio accorgersene subito con un messaggio chiaro.
    for (final planned in plan.allPlannedExercises) {
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
