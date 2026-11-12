import 'dart:math' as math;

import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';

/// La stima delle kcal di un allenamento, esercizio per esercizio.
///
/// Si somma tutto in "MET" ("equivalenti metabolici"): quante volte consumi
/// di più rispetto a stare seduto fermo. 1 MET ≈ 1 kcal per kg di peso
/// corporeo all'ora, quindi kcal = MET × peso (kg) × ore.
///
/// I tre pezzi dell'allenamento:
/// - **le serie dei pesi**: lo sforzo della serie (più muscoli muovi, più
///   consumi) e il lavoro per sollevare il carico, vedi [kcalPerSet];
/// - **il cardio**: i minuti scritti nella scheda, con l'intensità della
///   macchina (velocità, pendenza, livello), vedi [cardioMet];
/// - **il resto del tempo** (recuperi, spostamenti, riscaldamento): a
///   intensità bassa, [restMet].
///
/// È una stima, non una misura (anche gli smartwatch sbagliano del 20-40%).
/// I valori vengono dal Compendium of Physical Activities e, per il tapis
/// roulant, dalle formule dell'ACSM (American College of Sports Medicine).

/// MET durante una serie di pesi: "resistance training, vigorous effort".
const setMet = 6.0;

/// MET del tempo fuori dalle serie e dal cardio: in piedi, ci si muove, il
/// cuore è ancora alto dopo la serie.
const restMet = 2.5;

/// MET di una macchina cardio di cui non sappiamo le impostazioni.
const defaultCardioMet = 6.0;

/// Il rendimento del muscolo: del lavoro che fa, solo circa un quinto
/// diventa movimento, il resto è calore. Per sollevare 1 kcal di "lavoro"
/// ne bruci circa 5.
const muscleEfficiency = 0.2;

/// Quanto dura una ripetizione, in secondi (salita + discesa controllata).
const secondsPerRep = 3.5;

/// Joule in una kcal.
const _joulePerKcal = 4184.0;

/// Un pezzo di cardio della scheda: quanti minuti e con che intensità.
///
/// Lo salviamo all'inizio dell'allenamento, così la stima non dipende
/// dalla scheda (che nel frattempo potresti modificare).
class CardioPart {
  const CardioPart({required this.minutes, required this.met});

  factory CardioPart.fromJson(Map<String, dynamic> json) => CardioPart(
        minutes: (json['minutes'] as num).toDouble(),
        met: (json['met'] as num).toDouble(),
      );

  final double minutes;
  final double met;

  Map<String, dynamic> toJson() => {'minutes': minutes, 'met': met};
}

/// Le serie fatte di un esercizio coi pesi durante il Focus.
///
/// Non contiamo le serie a mano: ogni "Avvia recupero" vuol dire "ho appena
/// finito una serie". L'ultima serie, dopo cui di solito non si riposa, la
/// aggiungiamo noi (vedi [setsDone]).
class StrengthLog {
  const StrengthLog({
    required this.group,
    required this.loadKg,
    required this.repsPerSet,
    required this.secondsPerSet,
    this.plannedSets,
    this.rests = 0,
  });

  factory StrengthLog.fromJson(Map<String, dynamic> json) => StrengthLog(
        group: MuscleGroup.values.byName(json['group'] as String),
        loadKg: (json['loadKg'] as num).toDouble(),
        repsPerSet: (json['reps'] as num).toDouble(),
        secondsPerSet: (json['seconds'] as num).toDouble(),
        plannedSets: json['plannedSets'] as int?,
        rests: json['rests'] as int? ?? 0,
      );

  /// Il gruppo muscolare: decide quanti muscoli muovi e quanto è lunga la corsa.
  final MuscleGroup group;

  /// Il carico sollevato (il peso che hai salvato per l'esercizio).
  final double loadKg;

  /// Ripetizioni per serie (0 per gli esercizi a tempo, come il plank).
  final double repsPerSet;

  /// Quanto dura una serie, in secondi.
  final double secondsPerSet;

  /// Le serie scritte nella scheda (null se non ne ha).
  final int? plannedSets;

  /// Quanti recuperi hai avviato per questo esercizio.
  final int rests;

  /// Le serie fatte: una per ogni recupero, più l'ultima. Mai più di quelle
  /// della scheda (se avvii il recupero anche dopo l'ultima serie, non conta).
  int get setsDone {
    if (rests == 0) return 0;
    final planned = plannedSets;
    return planned == null ? rests + 1 : math.min(rests + 1, planned);
  }

  /// Una copia con un recupero in più e il carico di adesso (puoi averlo
  /// cambiato col + fra una serie e l'altra).
  StrengthLog withRest({required double loadKg}) => StrengthLog(
        group: group,
        loadKg: loadKg,
        repsPerSet: repsPerSet,
        secondsPerSet: secondsPerSet,
        plannedSets: plannedSets,
        rests: rests + 1,
      );

  Map<String, dynamic> toJson() => {
        'group': group.name,
        'loadKg': loadKg,
        'reps': repsPerSet,
        'seconds': secondsPerSet,
        if (plannedSets != null) 'plannedSets': plannedSets,
        'rests': rests,
      };
}

/// Prepara lo [StrengthLog] di un esercizio (ancora senza recuperi).
///
/// [savedKg] è il peso salvato col − / + (null se non l'hai mai scritto).
/// Per addominali e riscaldamento, che non hanno un peso, il "carico" è
/// una parte del corpo che muovi: il 30% del tuo peso.
StrengthLog strengthLogFor(
  Exercise exercise,
  PlannedExercise planned, {
  required double? savedKg,
  required double bodyKg,
}) {
  final count = parseRepsCount(planned.reps);
  final timed = exercise.measure == ExerciseMeasure.time;
  return StrengthLog(
    group: exercise.group,
    loadKg: exercise.hasWeight ? savedKg ?? 0 : bodyKg * 0.3,
    // A tempo (plank): niente ripetizioni da sollevare, solo la durata.
    repsPerSet: timed ? 0 : count,
    secondsPerSet: timed ? count : count * secondsPerRep,
    plannedSets: planned.sets,
  );
}

/// Le kcal di UNA serie (senza il recupero, che conta come "resto del tempo").
///
/// - sforzo: [setMet] per la durata della serie;
/// - lavoro: carico × g (9,81) × corsa del movimento × ripetizioni, diviso
///   per il rendimento del muscolo.
///
/// Tutto moltiplicato per il fattore del gruppo: una serie di leg press
/// muove molta più massa muscolare di una di curl.
///
/// Esempio, chest press a 40 kg, 10 ripetizioni, per chi pesa 80 kg:
/// lavoro ≈ 1,9 kcal + sforzo ≈ 4,7 kcal ≈ 6,5 kcal.
double kcalPerSet(StrengthLog log, {required double bodyKg}) {
  final effort = setMet * bodyKg * log.secondsPerSet / 3600;
  final joules = log.loadKg * 9.81 * rangeOfMotion(log.group) * log.repsPerSet;
  final work = joules / muscleEfficiency / _joulePerKcal;
  return (effort + work) * groupFactor(log.group);
}

/// Quanti muscoli muove un esercizio di questo gruppo, rispetto a petto e schiena.
double groupFactor(MuscleGroup group) => switch (group) {
      MuscleGroup.gambe => 1.3,
      MuscleGroup.petto || MuscleGroup.schiena => 1.0,
      MuscleGroup.spalle || MuscleGroup.braccia => 0.7,
      MuscleGroup.core || MuscleGroup.riscaldamento || MuscleGroup.cardio => 0.6,
    };

/// Di quanti metri si sposta il carico in una ripetizione (in media).
double rangeOfMotion(MuscleGroup group) => switch (group) {
      MuscleGroup.gambe || MuscleGroup.schiena => 0.5,
      MuscleGroup.spalle => 0.45,
      MuscleGroup.petto => 0.4,
      MuscleGroup.braccia => 0.35,
      MuscleGroup.core || MuscleGroup.riscaldamento || MuscleGroup.cardio => 0.3,
    };

/// Le ripetizioni (o i secondi) scritti nella scheda, come numero:
/// "10" → 10, "8–12" → 10 (la media), "10 per lato" → 20, "1'" → 60.
/// Se non c'è un numero, 10.
double parseRepsCount(String reps) {
  final numbers = [for (final m in RegExp(r'\d+').allMatches(reps)) int.parse(m.group(0)!)];
  if (numbers.isEmpty) return 10;
  var value = numbers.length >= 2 ? (numbers[0] + numbers[1]) / 2 : numbers[0].toDouble();
  // Minuti ("1'") e non secondi ("30\""): li portiamo in secondi.
  if (reps.contains("'") && !reps.contains('"')) value *= 60;
  if (reps.contains('lato')) value *= 2;
  return value;
}

/// Le kcal stimate dopo [elapsed] di allenamento, per chi pesa [bodyKg].
///
/// - le serie fatte di ogni esercizio ([strength]) contano con [kcalPerSet];
/// - il cardio ([cardio]) con i minuti scritti nella scheda. Se il tempo
///   passato (tolte le serie) non basta per tutto il cardio, ne contiamo
///   solo la parte che ci sta: non sappiamo cosa hai fatto davvero;
/// - il tempo che avanza vale [restMet].
double estimateKcal({
  required Duration elapsed,
  required double bodyKg,
  List<CardioPart> cardio = const [],
  Iterable<StrengthLog> strength = const [],
}) {
  final minutes = elapsed.inSeconds / 60;
  if (minutes <= 0 || bodyKg <= 0) return 0;

  var setMinutes = 0.0;
  var setKcal = 0.0;
  for (final log in strength) {
    setMinutes += log.setsDone * log.secondsPerSet / 60;
    setKcal += log.setsDone * kcalPerSet(log, bodyKg: bodyKg);
  }

  final cardioMinutes = cardio.fold<double>(0, (sum, part) => sum + part.minutes);
  final available = math.max(0.0, minutes - setMinutes);
  // Quanto del cardio scritto "entra" nel tempo rimasto (da 0 a 1).
  final cardioShare = cardioMinutes <= 0 ? 0.0 : math.min(1.0, available / cardioMinutes);
  final cardioMetMinutes = cardio.fold<double>(0, (sum, part) => sum + part.met * part.minutes) * cardioShare;
  final otherMinutes = math.max(0.0, available - cardioMinutes * cardioShare);

  return setKcal + (cardioMetMinutes + restMet * otherMinutes) * bodyKg / 60;
}

/// I pezzi di cardio di una seduta: gli esercizi cardio della scheda
/// ([workout]) e il blocco cardio finale del piano, se c'è.
List<CardioPart> cardioPartsFor(Workout workout, {CardioBlock? planCardio}) {
  return [
    for (final planned in workout.allPlannedExercises)
      if (planned.durationMinutes case final minutes?)
        CardioPart(minutes: minutes.toDouble(), met: cardioMet(planned)),
    if (planCardio != null)
      CardioPart(
        minutes: planCardio.durationMinutes.toDouble(),
        met: treadmillMet(speedKmh: planCardio.speedKmh, inclinePercent: planCardio.inclinePercent),
      ),
  ];
}

/// Il MET di un esercizio cardio della scheda, dalle sue impostazioni.
double cardioMet(PlannedExercise planned) {
  if (planned.speedKmh case final speed?) {
    return treadmillMet(speedKmh: speed, inclinePercent: planned.inclinePercent ?? 0);
  }
  if (planned.level case final level?) {
    // Le macchine "a livelli" non dicono i watt: da livello 1 a 20 andiamo
    // da un'intensità leggera a una molto intensa (valori del Compendium).
    final l = level.clamp(1, 20) - 1;
    return switch (planned.exerciseId) {
      'stair_climber' => 4.0 + l * 0.4, // scale: 4 → 11,6 MET
      _ => 3.5 + l * 0.35, // cyclette e simili: 3,5 → 10,2 MET
    };
  }
  return defaultCardioMet;
}

/// Il MET del tapis roulant con le formule dell'ACSM.
///
/// Si calcola il consumo di ossigeno (ml per kg al minuto) e lo si divide
/// per 3,5, che è il consumo a riposo (1 MET). Sopra gli 8 km/h si corre:
/// la formula cambia.
double treadmillMet({required double speedKmh, double inclinePercent = 0}) {
  final metersPerMinute = speedKmh * 1000 / 60;
  final grade = inclinePercent / 100;
  final vo2 = speedKmh < 8
      ? 3.5 + 0.1 * metersPerMinute + 1.8 * metersPerMinute * grade
      : 3.5 + 0.2 * metersPerMinute + 0.9 * metersPerMinute * grade;
  return vo2 / 3.5;
}
