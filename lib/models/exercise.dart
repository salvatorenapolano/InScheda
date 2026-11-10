/// Le famiglie di esercizi presenti nella libreria.
/// I nomi corrispondono ai valori di "category" in exercises.json.
enum ExerciseCategory { warmup, weights, abs }

/// Un esercizio della libreria (exercises.json): dice COME si esegue.
///
/// Non sa nulla di serie, ripetizioni o recupero: quelli dipendono
/// dalla scheda e stanno in [PlannedExercise].
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.muscles,
    required this.description,
    required this.tips,
    required this.images,
    this.videoUrl,
    this.muscleImage,
  });

  /// Crea un Exercise dalla mappa che restituisce jsonDecode().
  ///
  /// `as String` dice a Dart "fidati, qui c'è una stringa". Se nel JSON
  /// ci fosse un numero, l'app si fermerebbe con un errore chiaro.
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: ExerciseCategory.values.byName(json['category'] as String),
      muscles: List<String>.from(json['muscles'] as List? ?? const []),
      description: json['description'] as String,
      tips: List<String>.from(json['tips'] as List? ?? const []),
      images: List<String>.from(json['images'] as List? ?? const []),
      // `String?` (col punto di domanda) accetta anche null.
      videoUrl: json['videoUrl'] as String?,
      muscleImage: json['muscleImage'] as String?,
    );
  }

  final String id;
  final String name;
  final ExerciseCategory category;
  final List<String> muscles;
  final String description;
  final List<String> tips;
  final List<String> images;
  final String? videoUrl;

  /// Il nome dell'illustrazione dei muscoli ("petto", "dorsali"...),
  /// null se l'esercizio non ne ha una.
  final String? muscleImage;

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
}
