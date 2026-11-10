/// Un esercizio così come compare nella scheda: dice QUANTO farlo.
/// Il "come" sta nella libreria, collegato tramite [exerciseId].
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseId,
    this.reps = '',
    this.sets,
    this.restSeconds,
    this.notes,
    this.alternatives = const [],
    this.durationMinutes,
    this.speedKmh,
    this.inclinePercent,
    this.level,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseId: json['exerciseId'] as String,
      sets: json['sets'] as int?,
      reps: json['reps'] as String? ?? '',
      restSeconds: json['restSeconds'] as int?,
      notes: json['notes'] as String?,
      alternatives: List<String>.from(json['alternatives'] as List? ?? const []),
      durationMinutes: json['durationMinutes'] as int?,
      speedKmh: (json['speedKmh'] as num?)?.toDouble(),
      inclinePercent: (json['inclinePercent'] as num?)?.toDouble(),
      level: json['level'] as int?,
    );
  }

  final String exerciseId;

  /// null nel riscaldamento, dove non ci sono serie.
  final int? sets;

  /// Testo e non numero: può essere "10–12", "30\"", "10 per lato"...
  /// '' negli esercizi cardio, che si misurano in minuti.
  final String reps;

  final int? restSeconds;
  final String? notes;

  /// Cosa fare se la macchina è occupata.
  final List<String> alternatives;

  // Solo per il cardio (tapis roulant, cyclette...): quanto dura e come si
  // imposta la macchina. null = non indicato.
  final int? durationMinutes;
  final double? speedKmh;
  final double? inclinePercent;
  final int? level;

  /// true se è un esercizio cardio (si misura in minuti).
  bool get isCardio => durationMinutes != null;

  /// Il contrario di fromJson: da oggetto a mappa, pronta per jsonEncode().
  ///
  /// `if (sets != null) 'sets': sets` è un "collection if": la chiave
  /// finisce nella mappa solo se la condizione è vera. Così il JSON
  /// salvato resta pulito, senza tanti `"notes": null`.
  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        if (sets != null) 'sets': sets,
        if (reps.isNotEmpty) 'reps': reps,
        if (restSeconds != null) 'restSeconds': restSeconds,
        if (notes != null) 'notes': notes,
        if (alternatives.isNotEmpty) 'alternatives': alternatives,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (speedKmh != null) 'speedKmh': speedKmh,
        if (inclinePercent != null) 'inclinePercent': inclinePercent,
        if (level != null) 'level': level,
      };
}

/// Trasforma una lista JSON in una lista di [PlannedExercise].
List<PlannedExercise> _plannedExercisesFromJson(Object? json) {
  return (json as List)
      .map((item) => PlannedExercise.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Il contrario: una lista di [PlannedExercise] in una lista JSON.
List<Map<String, dynamic>> _plannedExercisesToJson(List<PlannedExercise> exercises) {
  return [for (final exercise in exercises) exercise.toJson()];
}

/// Legge un blocco facoltativo: se nel JSON non c'è, resta null.
ExerciseBlock? _blockFromJson(Object? json) {
  return json == null ? null : ExerciseBlock.fromJson(json as Map<String, dynamic>);
}

/// Un giorno della scheda (Push, Pull, Legs... o il nome che preferisci):
/// il suo eventuale riscaldamento e gli esercizi.
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.exercises,
    this.warmup,
    this.focus,
    this.intro,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      focus: json['focus'] as String?,
      intro: json['intro'] as String?,
      warmup: _blockFromJson(json['warmup']),
      exercises: _plannedExercisesFromJson(json['exercises']),
    );
  }

  final String id;
  final String name;

  /// I muscoli del giorno: "Petto, spalle, tricipiti".
  final String? focus;

  /// Una riga sotto il titolo dei pesi: "20 serie. Prima la schiena…".
  final String? intro;

  /// null = questa scheda non ha un blocco di riscaldamento.
  final ExerciseBlock? warmup;
  final List<PlannedExercise> exercises;

  /// Tutti gli esercizi del giorno, riscaldamento compreso.
  /// `...?` (spread "null-aware"): se warmup è null non aggiunge niente.
  List<PlannedExercise> get allPlannedExercises => [...?warmup?.exercises, ...exercises];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (focus != null) 'focus': focus,
        if (intro != null) 'intro': intro,
        // `?.`: chiama toJson() solo se warmup non è null.
        if (warmup != null) 'warmup': warmup?.toJson(),
        'exercises': _plannedExercisesToJson(exercises),
      };
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

  Map<String, dynamic> toJson() => {
        'title': title,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (intro != null) 'intro': intro,
        'exercises': _plannedExercisesToJson(exercises),
      };
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

  Map<String, dynamic> toJson() => {
        'title': title,
        'durationMinutes': durationMinutes,
        'inclinePercent': inclinePercent,
        'speedKmh': speedKmh,
      };
}

/// La regola del calendario: in quali giorni ci si allena e in che ordine
/// si alternano le schede.
class Schedule {
  const Schedule({required this.weekdays, this.time, this.rotation = const []});

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      weekdays: List<int>.from(json['weekdays'] as List),
      time: json['time'] as String?,
      rotation: List<String>.from(json['rotation'] as List? ?? const []),
    );
  }

  /// Giorni della settimana come in Dart: 1 = lunedì ... 7 = domenica.
  final List<int> weekdays;

  /// L'orario ("15:00"). Facoltativo: l'app non lo mostra.
  final String? time;

  /// Ordine delle schede, ad esempio ["push", "pull", "legs"].
  /// Vuota = nell'ordine in cui sono scritte (vedi [WorkoutPlan.rotation]).
  final List<String> rotation;

  Map<String, dynamic> toJson() => {
        'weekdays': weekdays,
        if (time != null) 'time': time,
        if (rotation.isNotEmpty) 'rotation': rotation,
      };
}

/// Una seduta nel calendario: un giorno e la scheda da fare.
class ScheduledSession {
  const ScheduledSession({required this.date, required this.workoutId});

  final DateTime date;
  final String workoutId;
}

/// L'intera scheda (workout_plan.json).
///
/// Può essere quella completa del PT (riscaldamento, addominali, cardio,
/// date di inizio e fine) o una creata nell'app, più semplice: solo le
/// schede con i loro esercizi, i giorni e magari una data di fine.
class WorkoutPlan {
  const WorkoutPlan({
    required this.name,
    required this.startDate,
    required this.schedule,
    required this.workouts,
    this.endDate,
    this.version,
    this.generalNotes,
    this.abs,
    this.cardio,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final endDate = json['endDate'] as String?;
    final cardio = json['cardio'];
    return WorkoutPlan(
      name: json['name'] as String,
      version: json['version'] as String?,
      // "2026-10-19" diventa la mezzanotte di quel giorno, ora locale.
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: endDate == null ? null : DateTime.parse(endDate),
      schedule: Schedule.fromJson(json['schedule'] as Map<String, dynamic>),
      generalNotes: json['generalNotes'] as String?,
      workouts: (json['workouts'] as List)
          .map((item) => Workout.fromJson(item as Map<String, dynamic>))
          .toList(),
      abs: _blockFromJson(json['abs']),
      cardio: cardio == null ? null : CardioBlock.fromJson(cardio as Map<String, dynamic>),
    );
  }

  final String name;
  final String? version;

  /// Da quando conta il calendario: la prima seduta è il primo giorno di
  /// allenamento da qui in poi.
  final DateTime startDate;

  /// null = la scheda non ha una scadenza: le sedute continuano per sempre.
  final DateTime? endDate;
  final Schedule schedule;
  final String? generalNotes;
  final List<Workout> workouts;

  /// Gli addominali, dopo i pesi e prima della camminata: uguali tutti i giorni.
  /// null = la scheda non ha questo blocco.
  final ExerciseBlock? abs;
  final CardioBlock? cardio;

  Workout workoutById(String id) => workouts.firstWhere((w) => w.id == id);

  /// L'ordine delle schede: quello del calendario, oppure quello in cui
  /// sono scritte se il calendario non lo dice.
  List<String> get rotation =>
      schedule.rotation.isNotEmpty ? schedule.rotation : [for (final w in workouts) w.id];

  /// Tutti gli esercizi della scheda, da tutti i blocchi.
  List<PlannedExercise> get allPlannedExercises => [
        for (final workout in workouts) ...workout.allPlannedExercises,
        ...?abs?.exercises,
      ];

  /// Le sedute dal primo giorno in poi, ciascuna con la sua scheda.
  ///
  /// `sync*` crea un generatore: ogni `yield` "consegna" una seduta solo
  /// quando chi legge ne chiede un'altra. Per questo funziona anche senza
  /// data di fine (le sedute sarebbero infinite!): nextSessionFrom() si
  /// ferma alla prima che gli serve e il resto non viene mai calcolato.
  Iterable<ScheduledSession> get sessions sync* {
    final order = rotation;
    // Senza giorni o senza schede non c'è nessuna seduta (e il ciclo
    // qui sotto, senza data di fine, non finirebbe mai).
    if (schedule.weekdays.isEmpty || order.isEmpty) return;
    final end = endDate;
    var count = 0;
    var day = startDate;
    while (end == null || !day.isAfter(end)) {
      if (schedule.weekdays.contains(day.weekday)) {
        // La 1ª seduta prende order[0], la 2ª order[1], la 3ª di nuovo
        // order[0]... L'operatore % (modulo) fa ripartire il giro.
        yield ScheduledSession(date: day, workoutId: order[count % order.length]);
        count++;
      }
      // Non usiamo day.add(Duration(days: 1)): col cambio dell'ora legale
      // (25 ottobre!) un giorno dura 23 o 25 ore e si sballerebbe tutto.
      // Così invece si va sempre al giorno successivo del calendario.
      day = DateTime(day.year, day.month, day.day + 1);
    }
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

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version,
        'startDate': _formatDate(startDate),
        if (endDate case final end?) 'endDate': _formatDate(end),
        'schedule': schedule.toJson(),
        if (generalNotes != null) 'generalNotes': generalNotes,
        'workouts': [for (final workout in workouts) workout.toJson()],
        if (abs != null) 'abs': abs?.toJson(),
        if (cardio != null) 'cardio': cardio?.toJson(),
      };
}

/// 16 novembre 2026 → "2026-11-16", lo stesso formato che legge DateTime.parse.
/// padLeft(2, '0') aggiunge lo zero davanti: 3 → "03".
String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
