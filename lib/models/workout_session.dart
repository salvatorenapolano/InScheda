/// Un allenamento finito in modalità Focus: quello che finisce nello
/// "Storico allenamenti" del profilo.
class WorkoutSession {
  const WorkoutSession({
    required this.startedAt,
    required this.duration,
    required this.workoutName,
    required this.kcal,
    required this.rests,
    required this.bodyKg,
    this.colorIndex,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        startedAt: DateTime.parse(json['startedAt'] as String),
        duration: Duration(seconds: json['seconds'] as int),
        workoutName: json['workout'] as String,
        kcal: (json['kcal'] as num).toDouble(),
        rests: json['rests'] as int? ?? 0,
        bodyKg: (json['bodyKg'] as num).toDouble(),
        colorIndex: json['colorIndex'] as int?,
      );

  /// Quando hai premuto "Inizia allenamento". Fa anche da identificativo:
  /// due allenamenti non partono nello stesso istante.
  final DateTime startedAt;

  /// Quanto è durato, da "Inizia" a "Termina".
  final Duration duration;

  /// Il nome della scheda fatta ("Push", "Scheda A"...).
  final String workoutName;

  /// Le kcal stimate (vedi estimateKcal).
  final double kcal;

  /// Quanti recuperi hai fatto partire.
  final int rests;

  /// Il peso corporeo usato per la stima delle kcal.
  final double bodyKg;

  /// Il colore della scheda (la sua posizione, vedi workoutColor), fissato
  /// quando l'hai fatta: se poi riordini le schede, lo storico non cambia.
  /// null negli allenamenti salvati prima che le schede avessero un colore.
  final int? colorIndex;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'seconds': duration.inSeconds,
        'workout': workoutName,
        'kcal': kcal,
        'rests': rests,
        'bodyKg': bodyKg,
        if (colorIndex != null) 'colorIndex': colorIndex,
      };
}
