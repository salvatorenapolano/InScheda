import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/models/body_weight.dart';

/// Lo storico delle pesate, salvato sul telefono.
///
/// Come [WeightStore]: è un ChangeNotifier, quindi quando aggiungi o
/// togli una pesata avvisa i widget che lo ascoltano e si ridisegnano.
///
/// Le pesate sono una lista, non un singolo numero: le salviamo come
/// testo JSON in una sola chiave ("body_weights").
class BodyWeightStore extends ChangeNotifier {
  BodyWeightStore._(this._prefs, this._entries);

  static const _key = 'body_weights';

  final SharedPreferences _prefs;
  final List<BodyWeightEntry> _entries;

  /// Apre la memoria del telefono e legge le pesate già salvate.
  static Future<BodyWeightStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final entries = raw == null
        ? <BodyWeightEntry>[]
        : [
            for (final item in jsonDecode(raw) as List)
              BodyWeightEntry.fromJson(item as Map<String, dynamic>),
          ];
    // `..` (cascade): chiama _sort() sull'oggetto appena creato
    // e restituisce l'oggetto stesso (non il risultato di _sort).
    return BodyWeightStore._(prefs, entries).._sort();
  }

  /// Le pesate, dalla più recente alla più vecchia.
  ///
  /// UnmodifiableListView: chi la legge non può modificarla per sbaglio
  /// (per cambiare le pesate si passa da save/remove, che salvano e avvisano).
  List<BodyWeightEntry> get entries => UnmodifiableListView(_entries);

  /// Salva la pesata di quel giorno. Se ce n'era già una, la sostituisce.
  Future<void> save(DateTime date, double kg) async {
    final day = dateOnly(date);
    _entries
      ..removeWhere((e) => e.date == day)
      ..add(BodyWeightEntry(date: day, kg: kg));
    _sort();
    // Prima avvisiamo (la lista sullo schermo si aggiorna subito),
    // poi scriviamo sul telefono.
    notifyListeners();
    await _persist();
  }

  /// Cancella la pesata di quel giorno.
  Future<void> remove(DateTime date) async {
    final day = dateOnly(date);
    _entries.removeWhere((e) => e.date == day);
    notifyListeners();
    await _persist();
  }

  void _sort() => _entries.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _persist() {
    return _prefs.setString(_key, jsonEncode([for (final e in _entries) e.toJson()]));
  }
}

/// Rende il [BodyWeightStore] disponibile a tutta l'app, come [WeightScope]:
/// `BodyWeightScope.of(context)` restituisce lo store e "iscrive" il widget
/// ai cambiamenti.
class BodyWeightScope extends InheritedNotifier<BodyWeightStore> {
  const BodyWeightScope({super.key, required BodyWeightStore store, required super.child})
      : super(notifier: store);

  static BodyWeightStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BodyWeightScope>();
    assert(scope != null, 'Nessun BodyWeightScope sopra questo widget');
    return scope!.notifier!;
  }
}
