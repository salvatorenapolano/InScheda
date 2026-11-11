import 'dart:convert';

import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/search.dart';
import 'package:my_workout/utils/slug.dart';

/// Importare una scheda scritta da un'IA (ChatGPT, Gemini, Claude…).
///
/// Il giro completo:
/// 1. [buildPlanPrompt] scrive le istruzioni per l'IA, con dentro l'elenco
///    degli esercizi della libreria (così l'IA usa i nostri id);
/// 2. l'utente le dà all'IA insieme al PDF e copia la risposta;
/// 3. [parsePlanImport] trova il JSON nella risposta e lo legge con
///    "manica larga": le IA a volte scrivono "4" invece di 4, "1'30"" invece
///    di 90, aggiungono frasi intorno… Quello che si può capire si capisce,
///    il resto finisce negli avvisi.
///
/// Qui non c'è niente di Flutter: è logica pura, facile da testare.

/// La versione del formato: se un giorno cambia, i JSON vecchi si riconoscono.
const planImportVersion = 1;

/// Qualcosa nella risposta non va: [message] è in italiano, da mostrare così com'è.
class PlanImportException implements Exception {
  const PlanImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Una scheda letta dalla risposta dell'IA: nome ed esercizi già pronti.
class ImportedWorkout {
  const ImportedWorkout({required this.name, required this.exercises});

  final String name;
  final List<PlannedExercise> exercises;
}

/// Tutto quello che è uscito dalla risposta dell'IA.
class PlanImport {
  const PlanImport({
    required this.weekdays,
    required this.endDate,
    required this.workouts,
    required this.newExercises,
    required this.warnings,
  });

  /// 1 = lunedì … 7 = domenica. Vuota se l'IA non li ha scritti.
  final List<int> weekdays;
  final DateTime? endDate;
  final List<ImportedWorkout> workouts;

  /// Esercizi che non sono nella libreria: diventeranno esercizi personali.
  final List<Exercise> newExercises;

  /// Cose da controllare: i dubbi dell'IA e quello che abbiamo dovuto aggiustare.
  final List<String> warnings;

  int get exerciseCount => workouts.fold(0, (sum, w) => sum + w.exercises.length);
}

// ---------------------------------------------------------------------------
// 1. Il prompt
// ---------------------------------------------------------------------------

/// Le istruzioni da dare all'IA, con l'elenco aggiornato degli esercizi
/// (compresi quelli personali dell'utente).
String buildPlanPrompt(Iterable<Exercise> library) {
  String settingsOf(Exercise e) => [
        if (e.cardioSettings.contains(CardioSetting.speed)) 'speedKmh',
        if (e.cardioSettings.contains(CardioSetting.incline)) 'inclinePercent',
        if (e.cardioSettings.contains(CardioSetting.level)) 'level',
      ].join(', ');

  final lines = [
    for (final e in library)
      [
        e.id,
        e.name,
        e.group.name,
        e.measure.name,
        if (e.measure == ExerciseMeasure.cardio && e.cardioSettings.isNotEmpty) settingsOf(e),
      ].join(' | '),
  ];
  final groups = MuscleGroup.values.map((g) => g.name).join(' | ');

  // Una stringa su più righe: ''' … '''. ${…} inserisce un valore.
  return '''
Ti allego la mia scheda di allenamento (PDF o foto). Trascrivila per l'app InScheda.

Rispondi con UN SOLO blocco ```json, senza altro testo prima o dopo, in questo formato:

{
  "inscheda": $planImportVersion,
  "type": "workout",
  "weekdays": [1, 3, 5],
  "endDate": "2026-12-23",
  "workouts": [
    {
      "name": "Push",
      "exercises": [
        { "exerciseId": "chest_press", "sets": 4, "reps": "8-10", "restSeconds": 90, "notes": "Settimana 1: serie leggera" },
        { "name": "Panca declinata con bilanciere", "group": "petto", "sets": 3, "reps": "10", "restSeconds": 120 },
        { "exerciseId": "plank", "sets": 3, "reps": "30\\"", "restSeconds": 60 },
        { "exerciseId": "tapis_roulant", "durationMinutes": 20, "speedKmh": 5.5, "inclinePercent": 10 }
      ]
    }
  ],
  "warnings": ["Non ero sicuro se 'pressa' fosse la leg press orizzontale o a 45°"]
}

I CAMPI
- "weekdays": i giorni di allenamento, 1 = lunedì … 7 = domenica.
- "endDate": facoltativo, la data di fine della scheda (AAAA-MM-GG). Se non c'è, omettilo.
- "workouts": una voce per ogni scheda/giorno (Scheda A, B, Push, Pull…), nell'ordine del PDF.
  "name" è il nome della scheda; "exercises" i suoi esercizi, nell'ordine del PDF.
- "warnings": cosa non hai capito, cosa hai dovuto indovinare, quali esercizi hai abbinato con dubbi.

OGNI ESERCIZIO
- Se è nella LIBRERIA qui sotto: "exerciseId" con l'id ESATTO copiato dalla lista.
- Se non c'è: niente "exerciseId", ma "name" (il nome scritto nel PDF) e "group", uno tra: $groups.
- Misura "reps" (colonna misura della libreria): "sets" (numero), "reps" (testo: "10", "8-10", "12 per lato"), "restSeconds" (numero).
- Misura "time" (plank e simili): "sets", "reps" con i secondi (es. "30\\""), "restSeconds".
- Misura "cardio": "durationMinutes" e, solo se scritti nel PDF, le impostazioni indicate in libreria (speedKmh, inclinePercent, level).
- Riscaldamento e mobilità: anche solo "reps", senza serie né recupero.
- "notes": facoltativo, tutto il resto (tecnica, progressioni, alternative se la macchina è occupata).

REGOLE
1. Usa SOLO "exerciseId" presenti nella libreria. Non inventare mai un id. Se un esercizio somiglia a uno della libreria ma non sei sicuro, usa quello più vicino e scrivilo in "warnings".
2. Il recupero va sempre in secondi: 1'30" = 90, 2' = 120, 3 minuti = 180.
3. Non inventare dati: se il PDF non dice serie, ripetizioni o recupero, ometti quel campo.
4. Se il PDF ha più fasi, mesi o settimane diverse, oppure non dice in che giorni ci si allena, CHIEDIMELO prima di scrivere il JSON.
5. Non dividere un esercizio in più voci: le varianti per settimana vanno in "notes".
6. Prima di rispondere ricontrolla: ogni "exerciseId" è nella libreria? ogni scheda ha almeno un esercizio? il JSON è valido (virgolette dritte, niente commenti, niente virgole prima di } o ])?

LIBRERIA (id | nome | gruppo | misura | impostazioni cardio)
${lines.join('\n')}
''';
}

// ---------------------------------------------------------------------------
// 2. Trovare il JSON nella risposta
// ---------------------------------------------------------------------------

/// Il blocco JSON dentro la risposta dell'IA: dentro i ```json … ``` se ci
/// sono, altrimenti dalla prima `{` all'ultima `}`.
String extractJson(String text) {
  // [\s\S]*? = "qualsiasi carattere, anche a capo, il meno possibile".
  final fence = RegExp(r'```[a-zA-Z]*\s*([\s\S]*?)```').firstMatch(text);
  final candidate = fence?.group(1) ?? text;
  final start = candidate.indexOf('{');
  final end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const PlanImportException(
      "Nella risposta non trovo la scheda. Copia tutta la risposta dell'IA, dall'inizio alla fine.",
    );
  }
  return candidate.substring(start, end + 1);
}

/// jsonDecode, ma perdona i due errori più comuni delle IA: le virgolette
/// "tipografiche" (“ ”) e la virgola prima di } o ].
Object? _decodeLenient(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    final fixed = json
        .replaceAll(RegExp('[“”]'), '"')
        // replaceAllMapped: sostituisce usando quello che ha trovato (m[1] = la parentesi).
        .replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
    try {
      return jsonDecode(fixed);
    } on FormatException {
      throw const PlanImportException(
        "La scheda non è scritta bene, forse la risposta è incompleta. "
        "Chiedi all'IA di riscrivere il JSON per intero e ricopialo.",
      );
    }
  }
}

// ---------------------------------------------------------------------------
// 3. Leggere la scheda
// ---------------------------------------------------------------------------

/// Legge la risposta dell'IA (anche con testo intorno) e la trasforma in
/// una [PlanImport]. Lancia [PlanImportException] se non c'è niente da usare.
///
/// [library] serve a riconoscere gli esercizi; [today] a scartare una data
/// di fine già passata.
PlanImport parsePlanImport(String text, Map<String, Exercise> library, {required DateTime today}) {
  final decoded = _decodeLenient(extractJson(text));
  if (decoded is! Map<String, dynamic>) {
    throw const PlanImportException('La risposta non contiene una scheda.');
  }
  final type = decoded['type'];
  if (type != null && type != 'workout') {
    throw PlanImportException('Questo non è una scheda di allenamento (type: "$type").');
  }
  final version = _int(decoded['inscheda']);
  if (version != null && version > planImportVersion) {
    throw const PlanImportException('Questa scheda è per una versione più nuova di InScheda: aggiorna l\'app.');
  }

  final warnings = <String>[
    for (final w in _list(decoded['warnings'] ?? const [])) ?_text(w),
    if (decoded['warnings'] case final String single) single,
  ];

  // Giorni: 1…7, ma anche "lun", "Lunedì", "monday"…
  final weekdays = <int>{};
  for (final day in _list(decoded['weekdays'])) {
    final weekday = _weekday(day);
    if (weekday == null) {
      warnings.add('Non ho capito il giorno "$day": controlla i giorni di allenamento.');
    } else {
      weekdays.add(weekday);
    }
  }

  DateTime? endDate;
  if (_text(decoded['endDate']) case final text?) {
    final date = DateTime.tryParse(text);
    final todayDate = DateTime(today.year, today.month, today.day);
    if (date == null) {
      warnings.add('Non ho capito la data di fine "$text": l\'ho tolta.');
    } else if (date.isBefore(todayDate)) {
      warnings.add('La data di fine (${date.day}/${date.month}/${date.year}) è già passata: l\'ho tolta.');
    } else {
      endDate = DateTime(date.year, date.month, date.day);
    }
  }

  final resolver = _ExerciseResolver(library, warnings);
  final workouts = <ImportedWorkout>[];
  final rawWorkouts = _list(decoded['workouts']);
  if (rawWorkouts.isEmpty) {
    throw const PlanImportException('Nella risposta non ci sono schede ("workouts" è vuoto o manca).');
  }
  for (final (index, raw) in rawWorkouts.indexed) {
    if (raw is! Map<String, dynamic>) continue;
    final letter = String.fromCharCode('A'.codeUnitAt(0) + index % 26);
    final name = _text(raw['name']) ?? 'Scheda $letter';

    final exercises = <PlannedExercise>[];
    for (final rawExercise in _list(raw['exercises'])) {
      if (rawExercise is! Map<String, dynamic>) continue;
      final exercise = resolver.resolve(rawExercise);
      if (exercise == null) {
        warnings.add('$name: un esercizio senza nome è stato saltato.');
        continue;
      }
      // PlanDraft non vuole doppioni nella stessa scheda.
      if (exercises.any((p) => p.exerciseId == exercise.id)) {
        warnings.add('$name: "${exercise.name}" compare due volte, l\'ho tenuto una volta sola.');
        continue;
      }
      exercises.add(_planned(exercise, rawExercise));
    }

    if (exercises.isEmpty) {
      warnings.add('"$name" non ha esercizi: l\'ho saltata.');
    } else {
      workouts.add(ImportedWorkout(name: name, exercises: exercises));
    }
  }
  if (workouts.isEmpty) {
    throw const PlanImportException('Nella risposta ci sono schede, ma nessun esercizio da importare.');
  }

  return PlanImport(
    weekdays: weekdays.toList()..sort(),
    endDate: endDate,
    workouts: workouts,
    newExercises: resolver.created,
    warnings: warnings,
  );
}

/// Trova l'esercizio della libreria (per id o per nome) o ne crea uno personale.
class _ExerciseResolver {
  _ExerciseResolver(this.library, this.warnings)
      : _byName = {for (final e in library.values) normalizeForSearch(e.name): e};

  final Map<String, Exercise> library;
  final List<String> warnings;
  final Map<String, Exercise> _byName;

  /// Gli esercizi personali creati in questo import, nell'ordine.
  final List<Exercise> created = [];

  Exercise? resolve(Map<String, dynamic> json) {
    final id = _text(json['exerciseId']);
    final name = _text(json['name']);

    final byId = id == null ? null : library[id];
    if (byId != null) return byId;
    // Un nome uguale a uno della libreria (o a uno appena creato): è quello.
    for (final candidate in [name, id]) {
      if (candidate == null) continue;
      if (_byName[normalizeForSearch(candidate)] case final known?) return known;
    }

    // Non c'è: diventa un esercizio personale. Il nome è quello scritto,
    // oppure l'id inventato dall'IA reso leggibile ("croci_cavi" → "Croci cavi").
    final displayName = name ?? (id == null ? null : _humanize(id));
    if (displayName == null) return null;

    var group = _group(json['group']);
    if (group == null) {
      group = MuscleGroup.petto;
      warnings.add('Non so a che gruppo muscolare appartiene "$displayName": l\'ho messo in Petto.');
    }
    final reps = _text(json['reps']) ?? '';
    final measure = switch (_text(json['measure'])) {
      _ when group == MuscleGroup.cardio => ExerciseMeasure.cardio,
      'time' => ExerciseMeasure.time,
      'cardio' => ExerciseMeasure.cardio,
      _ when json['durationMinutes'] != null => ExerciseMeasure.cardio,
      // "30\"", "45 sec": si misura a tempo.
      _ when RegExp(r'^\s*\d+\s*("|s\b|sec)').hasMatch(reps) => ExerciseMeasure.time,
      _ => ExerciseMeasure.reps,
    };
    final exercise = Exercise(
      // "personale_" davanti, come per quelli creati a mano.
      id: uniqueId(
        'personale_${slugify(displayName, fallback: 'esercizio')}',
        (id) => library.containsKey(id) || created.any((e) => e.id == id),
      ),
      name: displayName,
      category: measure == ExerciseMeasure.cardio ? ExerciseCategory.cardio : group.category,
      group: measure == ExerciseMeasure.cardio ? MuscleGroup.cardio : group,
      muscles: const [],
      description: '',
      tips: const [],
      images: const [],
      custom: true,
      measure: measure,
      cardioSettings: measure == ExerciseMeasure.cardio ? const [CardioSetting.level] : const [],
    );
    created.add(exercise);
    _byName[normalizeForSearch(displayName)] = exercise; // la prossima volta lo ritrova
    return exercise;
  }
}

/// Serie, ripetizioni, recupero (o minuti per il cardio) di un esercizio.
PlannedExercise _planned(Exercise exercise, Map<String, dynamic> json) {
  final notes = _text(json['notes']);
  final defaults = PlanDraft.defaultsFor(exercise.id, exercise);

  if (exercise.measure == ExerciseMeasure.cardio) {
    final settings = exercise.cardioSettings;
    return PlannedExercise(
      exerciseId: exercise.id,
      // Se l'IA ha messo i minuti in "reps" ("20 min"), li prendiamo da lì.
      durationMinutes: _int(json['durationMinutes']) ?? _int(json['reps']) ?? defaults.durationMinutes,
      speedKmh: settings.contains(CardioSetting.speed) ? _double(json['speedKmh']) : null,
      inclinePercent: settings.contains(CardioSetting.incline) ? _double(json['inclinePercent']) : null,
      level: settings.contains(CardioSetting.level) ? _int(json['level']) : null,
      notes: notes,
    );
  }

  var reps = _text(json['reps']) ?? defaults.reps;
  // "8-10" → "8–10": nell'app gli intervalli hanno il trattino lungo.
  reps = reps.replaceAllMapped(RegExp(r'(\d)\s*-\s*(\d)'), (m) => '${m[1]}–${m[2]}');
  // A tempo, "30" da solo vuol dire 30 secondi.
  if (exercise.measure == ExerciseMeasure.time && RegExp(r'^\d+$').hasMatch(reps)) reps = '$reps"';

  return PlannedExercise(
    exerciseId: exercise.id,
    sets: _int(json['sets']),
    reps: reps,
    restSeconds: _seconds(json['restSeconds']),
    notes: notes,
  );
}

// ---------------------------------------------------------------------------
// Piccoli "lettori" tolleranti
// ---------------------------------------------------------------------------

List<Object?> _list(Object? value) => value is List ? value : const [];

/// Testo pulito, o null se vuoto. Accetta anche numeri (10 → "10").
String? _text(Object? value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// 4, 4.0, "4", "4 serie" → 4.
int? _int(Object? value) {
  if (value is num) return value.round();
  final match = RegExp(r'\d+').firstMatch(_text(value) ?? '');
  return match == null ? null : int.parse(match[0]!);
}

/// 5.5, "5,5", "5.5 km/h" → 5.5.
double? _double(Object? value) {
  if (value is num) return value.toDouble();
  final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(_text(value) ?? '');
  return match == null ? null : double.parse(match[0]!.replaceAll(',', '.'));
}

/// Il recupero in secondi: 90, "90", "90s", "90\"", "1'30\"", "1:30", "2'", "2 min".
int? _seconds(Object? value) {
  if (value is num) return value.round();
  final text = (_text(value) ?? '').toLowerCase();
  // Minuti e secondi: 1'30" o 1:30.
  if (RegExp(r"^(\d+)\s*[:']\s*(\d{1,2})").firstMatch(text) case final m?) {
    return int.parse(m[1]!) * 60 + int.parse(m[2]!);
  }
  // Solo minuti: 2', 2 min, 1,5 min.
  if (RegExp(r"^(\d+(?:[.,]\d+)?)\s*(?:min|m\b|')").firstMatch(text) case final m?) {
    return (double.parse(m[1]!.replaceAll(',', '.')) * 60).round();
  }
  return _int(text);
}

/// 1…7, "1", "lun", "Lunedì", "monday" → 1…7.
int? _weekday(Object? value) {
  if (value is num) return value >= 1 && value <= 7 ? value.toInt() : null;
  final text = normalizeForSearch(_text(value) ?? '');
  if (int.tryParse(text) case final n?) return n >= 1 && n <= 7 ? n : null;
  if (text.length < 3) return null;
  const days = {
    'lun': 1, 'mar': 2, 'mer': 3, 'gio': 4, 'ven': 5, 'sab': 6, 'dom': 7,
    'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6, 'sun': 7,
  };
  return days[text.substring(0, 3)];
}

/// "petto", "Addominali", "abs", "bicipiti"… → il gruppo dell'app.
MuscleGroup? _group(Object? value) {
  final text = normalizeForSearch(_text(value) ?? '');
  if (text.isEmpty) return null;
  for (final group in MuscleGroup.values) {
    if (group.name == text || normalizeForSearch(group.label) == text) return group;
  }
  const synonyms = {
    'abs': MuscleGroup.core,
    'addome': MuscleGroup.core,
    'dorso': MuscleGroup.schiena,
    'dorsali': MuscleGroup.schiena,
    'bicipiti': MuscleGroup.braccia,
    'tricipiti': MuscleGroup.braccia,
    'glutei': MuscleGroup.gambe,
    'quadricipiti': MuscleGroup.gambe,
    'femorali': MuscleGroup.gambe,
    'polpacci': MuscleGroup.gambe,
    'warmup': MuscleGroup.riscaldamento,
    'mobilita': MuscleGroup.riscaldamento,
  };
  return synonyms[text];
}

/// "croci_ai_cavi" → "Croci ai cavi".
String _humanize(String id) {
  final words = id.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return words.isEmpty ? id : '${words[0].toUpperCase()}${words.substring(1)}';
}
