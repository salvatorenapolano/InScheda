import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I pesi che usi per ogni esercizio, salvati sul telefono.
///
/// È un ChangeNotifier: quando un peso cambia chiama notifyListeners()
/// e tutti i widget che lo stanno "ascoltando" si ridisegnano da soli
/// (la riga nella lista e la pagina di dettaglio restano allineate).
class WeightStore extends ChangeNotifier {
  WeightStore(this._prefs);

  final SharedPreferences _prefs;

  /// Apre la memoria del telefono. Va fatto una volta, all'avvio.
  static Future<WeightStore> load() async {
    return WeightStore(await SharedPreferences.getInstance());
  }

  static String _key(String exerciseId) => 'weight_$exerciseId';

  /// Il peso salvato, oppure null se non l'hai ancora inserito.
  double? weightFor(String exerciseId) => _prefs.getDouble(_key(exerciseId));

  /// Salva il peso. Con null (o un valore <= 0) lo cancella.
  Future<void> setWeight(String exerciseId, double? kg) async {
    if (kg == null || kg <= 0) {
      await _prefs.remove(_key(exerciseId));
    } else {
      await _prefs.setDouble(_key(exerciseId), kg);
    }
    notifyListeners();
  }
}

/// Rende il [WeightStore] disponibile a tutti i widget sotto di lui,
/// come fa MaterialApp con il tema: `WeightScope.of(context)` funziona
/// esattamente come `Theme.of(context)`.
///
/// InheritedNotifier fa anche un'altra cosa: quando lo store chiama
/// notifyListeners(), ridisegna i widget che hanno usato `of(context)`.
class WeightScope extends InheritedNotifier<WeightStore> {
  const WeightScope({super.key, required WeightStore store, required super.child})
      : super(notifier: store);

  static WeightStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WeightScope>();
    assert(scope != null, 'Nessun WeightScope sopra questo widget');
    return scope!.notifier!;
  }
}
