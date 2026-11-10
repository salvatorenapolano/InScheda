/// Le famiglie di esercizi presenti nella libreria.
/// I nomi corrispondono ai valori di "category" in exercises.json.
enum ExerciseCategory { warmup, weights, abs, cardio }

/// Come si "misura" un esercizio nella scheda:
/// - [reps]: serie × ripetizioni ("3 × 10"), o solo ripetizioni ("10 per lato");
/// - [time]: serie × secondi ("3 × 30\"", il plank);
/// - [cardio]: minuti e le impostazioni della macchina (velocità, pendenza,
///   livello), senza serie né recupero.
enum ExerciseMeasure { reps, time, cardio }

/// Le impostazioni di una macchina cardio, oltre alla durata.
enum CardioSetting {
  /// Velocità in km/h (tapis roulant).
  speed,

  /// Pendenza in % (tapis roulant).
  incline,

  /// Livello di resistenza o di velocità (cyclette, stair climber...).
  level,
}

/// I gruppi muscolari con cui la libreria è divisa nell'editor della scheda.
/// I nomi corrispondono ai valori di "group" in exercises.json, e l'ordine
/// qui è l'ordine delle sezioni nella lista.
///
/// È un "enhanced enum": ogni valore ha anche dei suoi campi ([label] e
/// [color]), passati al costruttore `const` tra parentesi.
enum MuscleGroup {
  petto('Petto', 0xFFFF2D55),
  schiena('Schiena', 0xFF5E5CE6),
  spalle('Spalle', 0xFFBF5AF2),
  braccia('Braccia', 0xFFFF9F0A),
  gambe('Gambe', 0xFF0A84FF),
  core('Addominali', 0xFF34C759),
  cardio('Cardio', 0xFF30B0C7),
  riscaldamento('Riscaldamento', 0xFFFF6B3D);

  const MuscleGroup(this.label, this.color);

  /// Il nome da mostrare: "Addominali" anche se nel JSON è "core".
  final String label;

  /// Il colore delle anteprime di questo gruppo, come numero 0xAARRGGBB
  /// (lo stesso di tool/generate_exercise_previews.py). È un int e non un
  /// Color perché i modelli non dipendono da Flutter: Color(group.color)
  /// lo fa il widget che lo disegna.
  final int color;

  /// La famiglia di un esercizio di questo gruppo: riscaldamento,
  /// addominali, oppure pesi (gli unici con "Il tuo peso").
  ExerciseCategory get category => switch (this) {
        riscaldamento => ExerciseCategory.warmup,
        core => ExerciseCategory.abs,
        cardio => ExerciseCategory.cardio,
        _ => ExerciseCategory.weights,
      };
}

/// Un esercizio della libreria (exercises.json): dice COME si esegue.
///
/// Non sa nulla di serie, ripetizioni o recupero: quelli dipendono
/// dalla scheda e stanno in [PlannedExercise].
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.group,
    required this.muscles,
    required this.description,
    required this.tips,
    required this.images,
    this.videoUrl,
    this.muscleImage,
    this.custom = false,
    ExerciseMeasure? measure,
    this.cardioSettings = const [],
  }) : measure = measure ?? (category == ExerciseCategory.cardio ? ExerciseMeasure.cardio : ExerciseMeasure.reps);

  /// Crea un Exercise dalla mappa che restituisce jsonDecode().
  ///
  /// `as String` dice a Dart "fidati, qui c'è una stringa". Se nel JSON
  /// ci fosse un numero, l'app si fermerebbe con un errore chiaro.
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ExerciseCategory.values.byName(json['category'] as String),
      group: MuscleGroup.values.byName(json['group'] as String),
      muscles: List<String>.from(json['muscles'] as List? ?? const []),
      description: json['description'] as String? ?? '',
      tips: List<String>.from(json['tips'] as List? ?? const []),
      images: List<String>.from(json['images'] as List? ?? const []),
      // `String?` (col punto di domanda) accetta anche null.
      videoUrl: json['videoUrl'] as String?,
      muscleImage: json['muscleImage'] as String?,
      custom: json['custom'] as bool? ?? false,
      // Senza "measure" si deduce dalla famiglia: cardio → cardio, il resto
      // ripetizioni. Nel JSON lo scriviamo solo quando serve (il plank: "time").
      measure: switch (json['measure']) {
        final String name => ExerciseMeasure.values.byName(name),
        _ => null,
      },
      cardioSettings: [
        for (final name in json['cardioSettings'] as List? ?? const []) CardioSetting.values.byName(name as String),
      ],
    );
  }

  final String id;
  final String name;
  final ExerciseCategory category;

  /// Il gruppo muscolare principale: la sezione in cui compare nell'editor.
  final MuscleGroup group;
  final List<String> muscles;

  /// "Come si esegue". '' negli esercizi personali senza spiegazione.
  final String description;
  final List<String> tips;
  final List<String> images;
  final String? videoUrl;

  /// Il nome dell'illustrazione dei muscoli ("petto", "dorsali"...),
  /// null se l'esercizio non ne ha una.
  final String? muscleImage;

  /// true = creato dall'utente: non ha un'anteprima SVG (vedi ExercisePreview).
  final bool custom;

  /// Come si misura nella scheda: ripetizioni, tempo o cardio.
  final ExerciseMeasure measure;

  /// Solo per il cardio: cosa si imposta sulla macchina oltre ai minuti.
  final List<CardioSetting> cardioSettings;

  /// La misura che avrebbe senza "measure" nel JSON: serve a toJson per
  /// scriverla solo quando è diversa.
  ExerciseMeasure get _defaultMeasure =>
      category == ExerciseCategory.cardio ? ExerciseMeasure.cardio : ExerciseMeasure.reps;

  /// L'anteprima SVG: il file ha lo stesso nome dell'id.
  /// Le genera tool/generate_exercise_previews.py.
  String get previewAsset => 'assets/images/exercises/$id.svg';

  /// Il file dell'illustrazione dei muscoli, o null se non c'è.
  /// Le immagini stanno in `assets/images/muscles/<nome>.webp`.
  String? get muscleAsset {
    final name = muscleImage;
    return name == null ? null : 'assets/images/muscles/$name.webp';
  }

  /// Solo gli esercizi coi pesi hanno un peso da ricordare.
  bool get hasWeight => category == ExerciseCategory.weights;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'group': group.name,
        'muscles': muscles,
        'description': description,
        if (tips.isNotEmpty) 'tips': tips,
        if (images.isNotEmpty) 'images': images,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (muscleImage != null) 'muscleImage': muscleImage,
        if (custom) 'custom': true,
        if (measure != _defaultMeasure) 'measure': measure.name,
        if (cardioSettings.isNotEmpty) 'cardioSettings': [for (final s in cardioSettings) s.name],
      };
}
