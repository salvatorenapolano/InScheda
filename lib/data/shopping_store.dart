import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le spunte della lista della spesa, salvate sul telefono: se chiudi
/// l'app a metà spesa, al rientro i prodotti già presi sono ancora spuntati.
///
/// Salviamo solo gli id dei prodotti spuntati, come lista di stringhe.
class ShoppingStore extends ChangeNotifier {
  ShoppingStore._(this._prefs, this._checked);

  static const _key = 'shopping_checked';

  final SharedPreferences _prefs;

  /// Un Set: come una lista, ma senza doppioni e con ricerca immediata.
  final Set<String> _checked;

  static Future<ShoppingStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ShoppingStore._(prefs, {...?prefs.getStringList(_key)});
  }

  bool isChecked(String itemId) => _checked.contains(itemId);

  /// Spunta o toglie la spunta.
  Future<void> setChecked(String itemId, bool checked) async {
    if (checked) {
      _checked.add(itemId);
    } else {
      _checked.remove(itemId);
    }
    notifyListeners();
    await _persist();
  }

  /// Toglie la spunta a tutti questi prodotti (il tasto Reset).
  /// Restituisce quelli che erano spuntati, per poterli rimettere con "Annulla".
  Future<Set<String>> uncheckAll(Iterable<String> itemIds) async {
    final removed = {for (final id in itemIds) if (_checked.contains(id)) id};
    _checked.removeAll(removed);
    notifyListeners();
    await _persist();
    return removed;
  }

  /// Rimette le spunte (l'"Annulla" dopo il Reset).
  Future<void> checkAll(Iterable<String> itemIds) async {
    _checked.addAll(itemIds);
    notifyListeners();
    await _persist();
  }

  /// Dimentica le spunte dei prodotti che non ci sono più (dopo aver
  /// salvato la lista). Così un prodotto nuovo che riprende l'id di uno
  /// cancellato non parte già spuntato.
  Future<void> retainOnly(Set<String> itemIds) async {
    final before = _checked.length;
    _checked.retainWhere(itemIds.contains);
    if (_checked.length == before) return;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _prefs.setStringList(_key, _checked.toList());
}

/// Rende lo [ShoppingStore] disponibile a tutta l'app, come [WeightScope].
class ShoppingScope extends InheritedNotifier<ShoppingStore> {
  const ShoppingScope({super.key, required ShoppingStore store, required super.child})
      : super(notifier: store);

  static ShoppingStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShoppingScope>();
    assert(scope != null, 'Nessun ShoppingScope sopra questo widget');
    return scope!.notifier!;
  }
}
