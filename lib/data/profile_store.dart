import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/models/body_weight.dart';

/// Chi usa l'app: il nome (da cui ricaviamo le iniziali dell'avatar) e se
/// ha già completato l'onboarding, cioè le pagine del primo avvio.
///
/// Stessa ricetta di WeightStore: ChangeNotifier + shared_preferences.
/// Quando cambia qualcosa chiama notifyListeners() e l'app si ridisegna:
/// è così che, finito l'onboarding, al suo posto compaiono le tab.
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const _nameKey = 'profile_name';
  static const _onboardingKey = 'onboarding_done';
  static const _weighInKey = 'weigh_in_weekday';

  /// Apre la memoria del telefono. Va fatto una volta, all'avvio.
  static Future<ProfileStore> load() async {
    return ProfileStore(await SharedPreferences.getInstance());
  }

  /// Il nome scritto dall'utente, '' se non l'ha ancora inserito.
  String get name => _prefs.getString(_nameKey) ?? '';

  /// "Mario Rossi" → "MR". Vedi [initialsOf].
  String get initials => initialsOf(name);

  /// false al primo avvio: l'app mostra l'onboarding invece delle tab.
  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  /// Il giorno della pesata: 1 = lunedì … 7 = domenica (di default venerdì).
  int get weighInWeekday => _prefs.getInt(_weighInKey) ?? defaultWeighInWeekday;

  /// Cambia il giorno della pesata (dal pannello del profilo).
  Future<void> setWeighInWeekday(int weekday) async {
    await _prefs.setInt(_weighInKey, weekday);
    notifyListeners();
  }

  /// Cambia il nome (dal pannello del profilo).
  Future<void> setName(String name) async {
    await _prefs.setString(_nameKey, name.trim());
    notifyListeners();
  }

  /// L'ultima pagina dell'onboarding: salva il nome e segna che è fatto.
  Future<void> completeOnboarding({required String name, int weighInWeekday = defaultWeighInWeekday}) async {
    await _prefs.setInt(_weighInKey, weighInWeekday);
    await _prefs.setString(_nameKey, name.trim());
    await _prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}

/// Le iniziali di un nome, al massimo due lettere maiuscole:
/// "mario rossi" → "MR", "Anna" → "A", "  " → "".
///
/// `split(RegExp(r'\s+'))` divide il testo dove ci sono spazi (uno o più),
/// `where` scarta i pezzi vuoti, `take(2)` tiene le prime due parole.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word.characters.first.toUpperCase()).join();
}

/// Rende il [ProfileStore] disponibile a tutta l'app: `ProfileScope.of(context)`.
/// Come WeightScope, ridisegna chi lo usa quando lo store cambia.
class ProfileScope extends InheritedNotifier<ProfileStore> {
  const ProfileScope({super.key, required ProfileStore store, required super.child})
      : super(notifier: store);

  static ProfileStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProfileScope>();
    assert(scope != null, 'Nessun ProfileScope sopra questo widget');
    return scope!.notifier!;
  }
}
