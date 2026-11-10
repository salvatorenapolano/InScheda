/// Un esercizio così come compare nella scheda: dice QUANTO farlo.
/// Il "come" sta nella libreria, collegato tramite [exerciseId].
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    required this.reps,
    this.sets,
    this.restSeconds,
    this.notes,
    this.alternatives = const [],
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseId: json['exerciseId'] as String,
      sets: json['sets'] as int?,
      reps: json['reps'] as String,
      restSeconds: json['restSeconds'] as int?,
      notes: json['notes'] as String?,
      alternatives: List<String>.from(json['alternatives'] as List? ?? const []),
    );
  }

  final String exerciseId;

  /// null nel riscaldamento, dove non ci sono serie.
  final int? sets;

  /// Testo e non numero: può essere "10–12", "30\"", "10 per lato"...
  final String reps;

  final int? restSeconds;
  final String? notes;

  /// Cosa fare se la macchina è occupata.
  final List<String> alternatives;
}

/// Trasforma una lista JSON in una lista di [PlannedExercise].
List<PlannedExercise> _plannedExercisesFromJson(Object? json) {
  return (json as List)
      .map((item) => PlannedExercise.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Un giorno della scheda (Push, Pull, Legs): il suo riscaldamento e i pesi.
/// Addominali e cardio sono uguali per tutti e stanno in [WorkoutPlan].
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.warmup,
    required this.exercises,
    this.focus,
    this.intro,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      focus: json['focus'] as String?,
      intro: json['intro'] as String?,
      warmup: ExerciseBlock.fromJson(json['warmup'] as Map<String, dynamic>),
      exercises: _plannedExercisesFromJson(json['exercises']),
    );
  }

  final String id;
  final String name;

  /// I muscoli del giorno: "Petto, spalle, tricipiti".
  final String? focus;

  /// Una riga sotto il titolo dei pesi: "20 serie. Prima la schiena…".
  final String? intro;

  final ExerciseBlock warmup;
  final List<PlannedExercise> exercises;

  /// Tutti gli esercizi del giorno, riscaldamento compreso.
  List<PlannedExercise> get allPlannedExercises => [...warmup.exercises, ...exercises];
}

/// Un blocco della seduta fatto di esercizi: riscaldamento o addominali.
class ExerciseBlock {
  const ExerciseBlock({
    required this.title,
    required this.exercises,
    this.durationMinutes,
    this.intro,
  });

  factory ExerciseBlock.fromJson(Map<String, dynamic> json) {
    return ExerciseBlock(
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int?,
      intro: json['intro'] as String?,
      exercises: _plannedExercisesFromJson(json['exercises']),
    );
  }

  final String title;

  /// null se la scheda non indica quanto dura il blocco.
  final int? durationMinutes;
  final String? intro;
  final List<PlannedExercise> exercises;
}

/// Il blocco cardio dopo gli addominali (camminata sul tapis roulant).
class CardioBlock {
  const CardioBlock({
    required this.title,
    required this.durationMinutes,
    required this.inclinePercent,
    required this.speedKmh,
  });

  factory CardioBlock.fromJson(Map<String, dynamic> json) {
    return CardioBlock(
      title: json['title'] as String,
      durationMinutes: json['durationMinutes'] as int,
      // `num`: nel JSON può esserci 10 o 10.5, toDouble() va bene per entrambi.
      inclinePercent: (json['inclinePercent'] as num).toDouble(),
      speedKmh: (json['speedKmh'] as num).toDouble(),
    );
  }

  final String title;
  final int durationMinutes;

  /// Pendenza del tapis roulant, in percentuale (10 = 10%).
  final double inclinePercent;

  /// Velocità in km/h.
  final double speedKmh;
}

/// La regola del calendario: in quali giorni ci si allena e in che ordine
/// si alternano le schede.
class Schedule {
  const Schedule({required this.weekdays, required this.time, required this.rotation});

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      weekdays: List<int>.from(json['weekdays'] as List),
      time: json['time'] as String,
      rotation: List<String>.from(json['rotation'] as List),
    );
  }

  /// Giorni della settimana come in Dart: 1 = lunedì ... 7 = domenica.
  final List<int> weekdays;
  final String time;

  /// Ordine delle schede, ad esempio ["push", "pull", "legs"].
  final List<String> rotation;
}

/// Una seduta nel calendario: un giorno e la scheda da fare.
class ScheduledSession {
  const ScheduledSession({required this.date, required this.workoutId});

  final DateTime date;
  final String workoutId;
}

/// L'intera scheda (workout_plan.json).
class WorkoutPlan {
  const WorkoutPlan({
    required this.name,
    required this.version,
    required this.startDate,
    required this.endDate,
    required this.schedule,
    required this.generalNotes,
    required this.workouts,
    required this.abs,
    required this.cardio,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      name: json['name'] as String,
      version: json['version'] as String,
      // "2026-10-19" diventa la mezzanotte di quel giorno, ora locale.
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      schedule: Schedule.fromJson(json['schedule'] as Map<String, dynamic>),
      generalNotes: json['generalNotes'] as String,
      workouts: (json['workouts'] as List)
          .map((item) => Workout.fromJson(item as Map<String, dynamic>))
          .toList(),
      abs: ExerciseBlock.fromJson(json['abs'] as Map<String, dynamic>),
      cardio: CardioBlock.fromJson(json['cardio'] as Map<String, dynamic>),
    );
  }

  final String name;
  final String version;
  final DateTime startDate;
  final DateTime endDate;
  final Schedule schedule;
  final String generalNotes;
  final List<Workout> workouts;

  /// Gli addominali, dopo i pesi e prima della camminata: uguali tutti i giorni.
  final ExerciseBlock abs;
  final CardioBlock cardio;

  Workout workoutById(String id) => workouts.firstWhere((w) => w.id == id);

  /// Tutti gli esercizi della scheda, da tutti i blocchi.
  List<PlannedExercise> get allPlannedExercises => [
        for (final workout in workouts) ...workout.allPlannedExercises,
        ...abs.exercises,
      ];

  /// Tutte le sedute dal primo all'ultimo giorno, ciascuna con la sua scheda.
  List<ScheduledSession> get sessions {
    final result = <ScheduledSession>[];
    var day = startDate;
    while (!day.isAfter(endDate)) {
      if (schedule.weekdays.contains(day.weekday)) {
        // La 1ª seduta prende rotation[0], la 2ª rotation[1], la 3ª di nuovo
        // rotation[0]... L'operatore % (modulo) fa ripartire il giro.
        final workoutId = schedule.rotation[result.length % schedule.rotation.length];
        result.add(ScheduledSession(date: day, workoutId: workoutId));
      }
      // Non usiamo day.add(Duration(days: 1)): col cambio dell'ora legale
      // (25 ottobre!) un giorno dura 23 o 25 ore e si sballerebbe tutto.
      // Così invece si va sempre al giorno successivo del calendario.
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  /// La prima seduta da [from] in poi, oggi compreso.
  /// Restituisce null se la scheda è terminata.
  ScheduledSession? nextSessionFrom(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    for (final session in sessions) {
      if (!session.date.isBefore(today)) return session;
    }
    return null;
  }
}
