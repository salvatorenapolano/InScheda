import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/data/data_bundle.dart';
import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/models/diet.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/models/workout_plan.dart';

/// I dati creati dall'utente nell'app (scheda, dieta, spesa, esercizi suoi), salvati sul
/// telefono come file JSON.
///
/// L'idea: invece di inventare un formato nuovo, salviamo la scheda
/// nello STESSO formato e allo STESSO percorso degli asset
/// (`<cartella>/assets/data/workout_plan.json`). Poi mettiamo questa
/// cartella come piano più alto del DataBundle: l'app la legge per prima
/// e le pagine non si accorgono di niente.
///
///   dati dell'utente  →  dati dell'app
///   (questo store)       (rootBundle: libreria esercizi e immagini)
///
/// Tutto quello che l'utente non ha creato (la libreria degli esercizi,
/// le immagini, la dieta...) arriva dai piani di sotto.
class UserDataStore extends ChangeNotifier {
  // `this._hasPlan`: un parametro con nome che riempie un campo privato.
  // Chi crea lo store scrive comunque `hasPlan: true`, senza trattino.
  UserDataStore({
    required this.root,
    this._hasPlan = false,
    this._hasDiet = false,
    this._hasShopping = false,
    this._hasCustomExercises = false,
  });

  /// Apre i dati dell'utente nella cartella di supporto dell'app.
  static Future<UserDataStore> load() async {
    final support = await getApplicationSupportDirectory();
    return open(Directory('${support.path}/user_data'));
  }

  /// Come [load], ma con una cartella scelta da noi (comodo nei test).
  static Future<UserDataStore> open(Directory root) async {
    return UserDataStore(
      root: root,
      hasPlan: await File('${root.path}/${WorkoutRepository.planPath}').exists(),
      hasDiet: await File('${root.path}/${DietRepository.dietPath}').exists(),
      hasShopping: await File('${root.path}/${ShoppingRepository.shoppingPath}').exists(),
      hasCustomExercises: await File('${root.path}/${WorkoutRepository.customExercisesPath}').exists(),
    );
  }

  final Directory root;

  bool _hasPlan;
  bool _hasDiet;
  bool _hasShopping;
  bool _hasCustomExercises;
  int _revision = 0;

  // Il bundle "a piani" già pronto, e il piano di sotto con cui l'abbiamo
  // costruito. Vedi bundleOver().
  DataBundle? _bundle;
  AssetBundle? _bundleBelow;

  /// true se l'utente ha salvato una sua scheda.
  bool get hasPlan => _hasPlan;

  /// true se l'utente ha salvato una sua dieta.
  bool get hasDiet => _hasDiet;

  /// true se l'utente ha salvato una sua lista della spesa.
  bool get hasShopping => _hasShopping;

  /// true se l'utente ha creato almeno un esercizio suo.
  bool get hasCustomExercises => _hasCustomExercises;

  /// Cresce a ogni salvataggio: l'app lo usa come Key per ricaricare le pagine.
  int get revision => _revision;

  File get _planFile => File('${root.path}/${WorkoutRepository.planPath}');

  /// Il bundle da mettere in DefaultAssetBundle: i file dell'utente sopra
  /// a [below] (di solito rootBundle, i file dentro l'app).
  ///
  /// Lo costruiamo una volta e lo riusiamo finché non cambia niente:
  /// un bundle nuovo a ogni ridisegno butterebbe via la cache e farebbe
  /// ricaricare tutte le immagini. È una "memoizzazione": ricordarsi un
  /// risultato già calcolato finché gli ingredienti sono gli stessi.
  AssetBundle bundleOver(AssetBundle below) {
    final cached = _bundle;
    // identical(): è proprio lo stesso oggetto di prima?
    if (cached != null && identical(_bundleBelow, below)) return cached;
    _bundleBelow = below;
    final hasFiles = _hasPlan || _hasDiet || _hasShopping || _hasCustomExercises;
    return _bundle = DataBundle(hasFiles ? root : null, below);
  }

  /// Salva la scheda dell'utente: da qui in poi l'app usa questa.
  Future<void> savePlan(WorkoutPlan plan) async {
    await _writeJson(WorkoutRepository.planPath, plan.toJson());
    _hasPlan = true;
    _changed();
  }

  /// Salva la dieta dell'utente: la tab Dieta mostrerà questa.
  Future<void> saveDiet(Diet diet) async {
    await _writeJson(DietRepository.dietPath, diet.toJson());
    _hasDiet = true;
    _changed();
  }

  /// Salva la spesa dell'utente (liste e reparti suoi): la tab Spesa mostrerà questa.
  Future<void> saveShopping(ShoppingData shopping) async {
    await _writeJson(ShoppingRepository.shoppingPath, shopping.toJson());
    _hasShopping = true;
    _changed();
  }

  /// Aggiunge un esercizio creato dall'utente alla sua libreria personale
  /// (custom_exercises.json): da qui in poi compare nella scelta esercizi.
  Future<void> addCustomExercise(Exercise exercise) => addCustomExercises([exercise]);

  /// Come [addCustomExercise], ma tanti in una volta sola (un solo file
  /// scritto): li usa l'import della scheda con l'IA.
  Future<void> addCustomExercises(Iterable<Exercise> exercises) async {
    if (exercises.isEmpty) return;
    final file = File('${root.path}/${WorkoutRepository.customExercisesPath}');
    final existing = await file.exists() ? jsonDecode(await file.readAsString()) as List : const [];
    await _writeJson(WorkoutRepository.customExercisesPath, [
      ...existing,
      for (final exercise in exercises) exercise.toJson(),
    ]);
    _hasCustomExercises = true;
    _changed();
  }

  /// Scrive [json] nel file [path] (relativo alla cartella dell'utente).
  /// `Object`: può essere una mappa (la scheda) o una lista (gli esercizi).
  Future<void> _writeJson(String path, Object json) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    // withIndent: JSON "a capo e rientrato", leggibile anche a occhio.
    final text = const JsonEncoder.withIndent('  ').convert(json);
    // Prima un file temporaneo, poi lo rinominiamo: se l'app si chiude a
    // metà, il file vecchio resta intero invece di essere scritto a metà.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text);
    await tmp.rename(file.path);
  }

  /// Cancella la scheda dell'utente: l'app torna a quella dei piani di sotto.
  Future<void> deletePlan() async {
    final file = _planFile;
    if (await file.exists()) await file.delete();
    _hasPlan = false;
    _changed();
  }

  void _changed() {
    _revision++;
    _bundle = null; // al prossimo bundleOver() se ne crea uno nuovo, senza cache
    notifyListeners();
  }
}

/// Rende disponibile lo [UserDataStore] a tutta l'app: `UserDataScope.of(context)`.
class UserDataScope extends InheritedNotifier<UserDataStore> {
  const UserDataScope({super.key, required UserDataStore store, required super.child})
      : super(notifier: store);

  static UserDataStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<UserDataScope>();
    assert(scope != null, 'Nessun UserDataScope sopra questo widget');
    return scope!.notifier!;
  }
}
