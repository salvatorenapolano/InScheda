import 'package:flutter/foundation.dart';

import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';

/// Una scheda (giorno) mentre l'utente la sta preparando: nome ed esercizi.
/// A differenza di [Workout] è modificabile, ma solo passando da [PlanDraft],
/// che così può avvisare chi ascolta.
class WorkoutDraft {
  WorkoutDraft._({required this.id, required this._name, List<PlannedExercise>? exercises})
      : _exercises = exercises ?? [];

  /// Non cambia mai, anche se cambia il nome: il calendario usa questo.
  final String id;

  String _name;
  final List<PlannedExercise> _exercises;

  String get name => _name;

  /// Una copia in sola lettura: per cambiarla si usano i metodi di PlanDraft.
  List<PlannedExercise> get exercises => List.unmodifiable(_exercises);

  /// true se l'esercizio è già in questa scheda.
  bool contains(String exerciseId) => _exercises.any((p) => p.exerciseId == exerciseId);
}

/// La scheda in preparazione, nell'onboarding o in "Modifica la scheda".
///
/// È un ChangeNotifier come gli store, ma vive solo finché l'editor è
/// aperto: ogni modifica chiama notifyListeners() e le pagine dell'editor
/// (che lo ascoltano con ListenableBuilder) si ridisegnano. Solo alla fine,
/// con [toPlan], diventa una WorkoutPlan da salvare.
class PlanDraft extends ChangeNotifier {
  /// Una scheda nuova: nessun giorno, una sola scheda vuota ("Scheda A").
  PlanDraft() {
    _workouts.add(_newWorkout());
  }

  /// Per modificare una scheda già salvata.
  PlanDraft.fromPlan(WorkoutPlan plan)
      : _name = plan.name,
        _startDate = plan.startDate,
        _endDate = plan.endDate {
    _weekdays.addAll(plan.schedule.weekdays);
    for (final workout in plan.workouts) {
      _workouts.add(WorkoutDraft._(id: workout.id, name: workout.name, exercises: [...workout.exercises]));
    }
    if (_workouts.isEmpty) _workouts.add(_newWorkout());
  }

  /// Serie, ripetizioni e recupero di un esercizio appena aggiunto:
  /// un punto di partenza, poi l'utente li cambia.
  static const defaultSets = 3;
  static const defaultReps = '10';
  static const defaultRestSeconds = 90;

  String _name = 'La mia scheda';
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<int> _weekdays = {};
  final List<WorkoutDraft> _workouts = [];

  /// Giorni della settimana come in Dart: 1 = lunedì … 7 = domenica.
  /// `toList()..sort()`: ".." (cascade) chiama sort() sulla lista appena
  /// creata e restituisce la lista stessa, non il risultato di sort().
  List<int> get weekdays => _weekdays.toList()..sort();

  DateTime? get endDate => _endDate;

  List<WorkoutDraft> get workouts => List.unmodifiable(_workouts);

  /// Si può andare avanti dalla pagina dei giorni?
  bool get hasDays => _weekdays.isNotEmpty;

  /// Ogni scheda ha un nome e almeno un esercizio?
  bool get workoutsReady =>
      _workouts.isNotEmpty && _workouts.every((w) => w.name.trim().isNotEmpty && w._exercises.isNotEmpty);

  void toggleWeekday(int weekday) {
    // Set.remove restituisce false se il giorno non c'era: allora lo aggiungiamo.
    if (!_weekdays.remove(weekday)) _weekdays.add(weekday);
    notifyListeners();
  }

  /// null = la scheda non ha una scadenza.
  void setEndDate(DateTime? date) {
    _endDate = date == null ? null : DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  WorkoutDraft addWorkout() {
    final workout = _newWorkout();
    _workouts.add(workout);
    notifyListeners();
    return workout;
  }

  void renameWorkout(WorkoutDraft workout, String name) {
    workout._name = name.trim();
    notifyListeners();
  }

  void removeWorkout(WorkoutDraft workout) {
    _workouts.remove(workout);
    notifyListeners();
  }

  /// Aggiunge in fondo gli esercizi scelti, con valori di partenza adatti a
  /// come si misurano (vedi [defaultsFor]). [library] serve a saperlo: senza,
  /// sono trattati come esercizi coi pesi. Quelli già presenti vengono saltati.
  void addExercises(WorkoutDraft workout, Iterable<String> exerciseIds, [Map<String, Exercise> library = const {}]) {
    for (final id in exerciseIds) {
      if (workout.contains(id)) continue;
      workout._exercises.add(defaultsFor(id, library[id]));
    }
    notifyListeners();
  }

  /// Da dove parte un esercizio appena aggiunto, poi l'utente lo cambia:
  /// - cardio: 20 minuti (velocità 5,5 km/h e pendenza 5% sul tapis, livello 5);
  /// - a tempo: 3 × 30", recupero 60";
  /// - riscaldamento: solo 10 ripetizioni, senza serie né recupero;
  /// - tutto il resto: 3 × 10, recupero 90".
  static PlannedExercise defaultsFor(String id, Exercise? exercise) {
    final settings = exercise?.cardioSettings ?? const <CardioSetting>[];
    return switch ((exercise?.measure, exercise?.category)) {
      (ExerciseMeasure.cardio, _) => PlannedExercise(
          exerciseId: id,
          durationMinutes: 20,
          speedKmh: settings.contains(CardioSetting.speed) ? 5.5 : null,
          inclinePercent: settings.contains(CardioSetting.incline) ? 5 : null,
          level: settings.contains(CardioSetting.level) ? 5 : null,
        ),
      (ExerciseMeasure.time, _) => PlannedExercise(exerciseId: id, sets: 3, reps: '30"', restSeconds: 60),
      (_, ExerciseCategory.warmup) => PlannedExercise(exerciseId: id, reps: defaultReps),
      _ => PlannedExercise(
          exerciseId: id,
          sets: defaultSets,
          reps: defaultReps,
          restSeconds: defaultRestSeconds,
        ),
    };
  }

  void updateExercise(WorkoutDraft workout, int index, PlannedExercise planned) {
    workout._exercises[index] = planned;
    notifyListeners();
  }

  void removeExercise(WorkoutDraft workout, int index) {
    workout._exercises.removeAt(index);
    notifyListeners();
  }

  /// Sposta un esercizio (trascinandolo nella lista).
  void moveExercise(WorkoutDraft workout, int from, int to) {
    final planned = workout._exercises.removeAt(from);
    workout._exercises.insert(to, planned);
    notifyListeners();
  }

  /// La scheda finita, pronta da salvare. Le schede si alternano
  /// nell'ordine in cui sono scritte (la rotazione non serve).
  WorkoutPlan toPlan({required DateTime today}) {
    return WorkoutPlan(
      name: _name,
      // Una scheda nuova parte oggi; una modificata tiene il suo inizio,
      // così il giro delle schede non riparte da capo.
      startDate: _startDate ?? DateTime(today.year, today.month, today.day),
      endDate: _endDate,
      schedule: Schedule(weekdays: weekdays),
      workouts: [
        for (final w in _workouts)
          Workout(id: w.id, name: w.name.trim(), exercises: [...w._exercises]),
      ],
    );
  }

  /// Una scheda nuova: "Scheda A", "Scheda B"… e un id mai usato.
  WorkoutDraft _newWorkout() {
    final letter = String.fromCharCode('A'.codeUnitAt(0) + _workouts.length % 26);
    var n = _workouts.length + 1;
    while (_workouts.any((w) => w.id == 'scheda_$n')) {
      n++;
    }
    return WorkoutDraft._(id: 'scheda_$n', name: 'Scheda $letter');
  }
}
