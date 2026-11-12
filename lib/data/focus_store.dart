import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/data/focus_alerts.dart';
import 'package:my_workout/features/focus/calories.dart';
import 'package:my_workout/models/workout_session.dart';

/// L'allenamento in corso in modalità Focus.
class ActiveFocus {
  const ActiveFocus({
    required this.startedAt,
    required this.workoutId,
    required this.workoutName,
    required this.bodyKg,
    this.colorIndex = 0,
    this.cardio = const [],
    this.strength = const {},
    this.rests = 0,
  });

  factory ActiveFocus.fromJson(Map<String, dynamic> json) => ActiveFocus(
        startedAt: DateTime.parse(json['startedAt'] as String),
        workoutId: json['workoutId'] as String,
        workoutName: json['workoutName'] as String,
        bodyKg: (json['bodyKg'] as num).toDouble(),
        colorIndex: json['colorIndex'] as int? ?? 0,
        cardio: [
          for (final part in json['cardio'] as List? ?? const [])
            CardioPart.fromJson(part as Map<String, dynamic>),
        ],
        strength: {
          for (final MapEntry(:key, :value) in (json['strength'] as Map<String, dynamic>? ?? const {}).entries)
            key: StrengthLog.fromJson(value as Map<String, dynamic>),
        },
        rests: json['rests'] as int? ?? 0,
      );

  final DateTime startedAt;
  final String workoutId;
  final String workoutName;

  /// Il peso corporeo per la stima delle kcal.
  final double bodyKg;

  /// La posizione della scheda nel piano, per il suo colore (workoutColor).
  final int colorIndex;

  /// Il cardio della scheda (per la stima delle kcal).
  final List<CardioPart> cardio;

  /// Le serie fatte di ogni esercizio coi pesi (chiave: id dell'esercizio).
  final Map<String, StrengthLog> strength;

  /// Quanti recuperi hai fatto partire finora.
  final int rests;

  /// Una copia con un recupero in più. Gli oggetti "immutabili" non si
  /// modificano: se ne crea uno nuovo con il campo cambiato.
  ///
  /// Con [log] (gli esercizi coi pesi, non il cardio) il recupero vale
  /// anche come serie fatta di quell'esercizio ([key]).
  ActiveFocus withRest({required String key, StrengthLog? log}) => ActiveFocus(
        startedAt: startedAt,
        workoutId: workoutId,
        workoutName: workoutName,
        bodyKg: bodyKg,
        colorIndex: colorIndex,
        cardio: cardio,
        strength: log == null
            ? strength
            : {
                // `...strength`: copia tutte le voci, poi aggiorna quella di [key].
                ...strength,
                key: (strength[key] ?? log).withRest(loadKg: log.loadKg),
              },
        rests: rests + 1,
      );

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'workoutId': workoutId,
        'workoutName': workoutName,
        'bodyKg': bodyKg,
        'colorIndex': colorIndex,
        'cardio': [for (final part in cardio) part.toJson()],
        'strength': {for (final MapEntry(:key, :value) in strength.entries) key: value.toJson()},
        'rests': rests,
      };
}

/// Il timer che sta scorrendo: un recupero o i minuti di un esercizio cardio.
class RestTimer {
  const RestTimer({required this.key, required this.label, required this.total, required this.endsAt});

  /// Di chi è il timer (l'id dell'esercizio): il dettaglio di quell'esercizio
  /// mostra il conto alla rovescia, gli altri dicono "c'è un timer in corso".
  final String key;

  /// Il nome dell'esercizio, per la notifica ("…prossima serie di Panca").
  final String label;

  final Duration total;
  final DateTime endsAt;
}

/// La modalità Focus: l'allenamento in corso, il timer del recupero e lo
/// storico degli allenamenti finiti.
///
/// Come gli altri store è un ChangeNotifier salvato in shared_preferences.
/// L'allenamento in corso si salva subito: se Android chiude l'app a metà,
/// riaprendola il cronometro riparte da dove era (conta l'ora di inizio,
/// non un contatore).
///
/// Il recupero ha due "sveglie", perché un timer di Dart si ferma quando
/// il telefono dorme:
/// - app aperta → un Timer di Dart, che allo scadere fa vibrare;
/// - app in background o schermo spento → una notifica programmata
///   (la mettiamo quando l'app si nasconde, la togliamo quando torna).
class FocusStore extends ChangeNotifier {
  FocusStore._(this._prefs, this._history, this._active, this.alerts, this._now) {
    // AppLifecycleListener: ci avvisa quando l'app sparisce dallo schermo
    // (home, altra app, schermo spento) e quando torna.
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  static const _activeKey = 'focus_active';
  static const _historyKey = 'workout_history';
  static const _exactAskedKey = 'focus_exact_alarm_asked';

  /// Apre la memoria del telefono: storico e, se c'era, l'allenamento in corso.
  ///
  /// [now] serve ai test per far "passare il tempo" a comando.
  static Future<FocusStore> load({required FocusAlerts alerts, DateTime Function()? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getString(_historyKey);
    final rawActive = prefs.getString(_activeKey);
    return FocusStore._(
      prefs,
      [
        if (rawHistory != null)
          for (final item in jsonDecode(rawHistory) as List) WorkoutSession.fromJson(item as Map<String, dynamic>),
      ],
      rawActive == null ? null : ActiveFocus.fromJson(jsonDecode(rawActive) as Map<String, dynamic>),
      alerts,
      now ?? DateTime.now,
    );
  }

  final SharedPreferences _prefs;
  final List<WorkoutSession> _history;
  ActiveFocus? _active;
  RestTimer? _rest;
  Timer? _restTimer;
  bool _visible = true;
  late final AppLifecycleListener _lifecycle;

  /// Vibrazione e notifiche.
  final FocusAlerts alerts;

  final DateTime Function() _now;

  /// L'ora "adesso" secondo lo store (nei test è finta).
  DateTime now() => _now();

  /// L'allenamento in corso, o null se il Focus è spento.
  ActiveFocus? get active => _active;

  bool get isActive => _active != null;

  /// Il timer che sta scorrendo, o null.
  RestTimer? get rest => _rest;

  /// Da quanto ti stai allenando.
  Duration get elapsed {
    final active = _active;
    if (active == null) return Duration.zero;
    final elapsed = now().difference(active.startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Quanto manca alla fine del timer (zero se non c'è).
  Duration get restLeft {
    final rest = _rest;
    if (rest == null) return Duration.zero;
    final left = rest.endsAt.difference(now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Le kcal stimate finora.
  double get kcal {
    final active = _active;
    if (active == null) return 0;
    return estimateKcal(
      elapsed: elapsed,
      bodyKg: active.bodyKg,
      cardio: active.cardio,
      strength: active.strength.values,
    );
  }

  /// Gli allenamenti finiti, dal più recente.
  List<WorkoutSession> get history => UnmodifiableListView(_history);

  /// true se abbiamo già spiegato il permesso "Sveglie e promemoria".
  bool get exactAlarmAsked => _prefs.getBool(_exactAskedKey) ?? false;

  Future<void> markExactAlarmAsked() => _prefs.setBool(_exactAskedKey, true);

  /// "Inizia allenamento": parte il cronometro.
  Future<void> start({
    required String workoutId,
    required String workoutName,
    required double bodyKg,
    int colorIndex = 0,
    List<CardioPart> cardio = const [],
  }) async {
    _active = ActiveFocus(
      startedAt: now(),
      workoutId: workoutId,
      workoutName: workoutName,
      bodyKg: bodyKg,
      colorIndex: colorIndex,
      cardio: cardio,
    );
    notifyListeners();
    await _saveActive();
  }

  /// Fa partire il timer di [seconds] secondi per l'esercizio [key].
  /// Se ce n'era già uno, lo sostituisce.
  ///
  /// [countsAsRest] false per i minuti del cardio: non sono un recupero.
  /// [strength] (esercizi coi pesi): la serie appena finita, per le kcal.
  Future<void> startTimer({
    required String key,
    required String label,
    required int seconds,
    bool countsAsRest = true,
    StrengthLog? strength,
  }) async {
    final active = _active;
    if (active == null) return;
    final total = Duration(seconds: seconds);
    _restTimer?.cancel();
    _rest = RestTimer(key: key, label: label, total: total, endsAt: now().add(total));
    _restTimer = Timer(total, _onRestEnd);
    if (countsAsRest) _active = active.withRest(key: key, log: strength);
    notifyListeners();
    await _saveActive();
  }

  /// "Ferma": il timer sparisce senza vibrare.
  Future<void> stopTimer() async {
    _clearRest();
    notifyListeners();
    await alerts.cancelRestEnd();
  }

  /// "Termina allenamento". Con [save] true finisce nello storico e
  /// restituisce l'allenamento salvato; con false si butta via.
  Future<WorkoutSession?> finish({required bool save}) async {
    final active = _active;
    if (active == null) return null;
    final session = WorkoutSession(
      startedAt: active.startedAt,
      duration: elapsed,
      workoutName: active.workoutName,
      kcal: kcal,
      rests: active.rests,
      bodyKg: active.bodyKg,
      colorIndex: active.colorIndex,
    );
    _clearRest();
    _active = null;
    if (save) _history.insert(0, session);
    notifyListeners();
    await alerts.cancelRestEnd();
    await _prefs.remove(_activeKey);
    if (save) await _saveHistory();
    return save ? session : null;
  }

  /// Cancella un allenamento dallo storico.
  Future<void> deleteSession(WorkoutSession session) async {
    _history.removeWhere((s) => s.startedAt == session.startedAt);
    notifyListeners();
    await _saveHistory();
  }

  void _onRestEnd() {
    // Con l'app aperta vibriamo noi; con l'app nascosta ci pensa la notifica.
    if (_visible) alerts.vibrate();
    _clearRest();
    notifyListeners();
  }

  void _clearRest() {
    _restTimer?.cancel();
    _restTimer = null;
    _rest = null;
  }

  void _onHide() {
    _visible = false;
    final rest = _rest;
    if (rest != null) alerts.scheduleRestEnd(rest.endsAt, exercise: rest.label);
  }

  void _onShow() {
    _visible = true;
    alerts.cancelRestEnd();
    // Se il recupero è finito mentre eri fuori (il Timer di Dart può essere
    // rimasto fermo col telefono addormentato), lo chiudiamo ora.
    if (_rest != null && restLeft == Duration.zero) {
      _clearRest();
      notifyListeners();
    }
  }

  Future<void> _saveActive() async {
    final active = _active;
    if (active == null) return;
    await _prefs.setString(_activeKey, jsonEncode(active.toJson()));
  }

  Future<void> _saveHistory() {
    return _prefs.setString(_historyKey, jsonEncode([for (final s in _history) s.toJson()]));
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }
}

/// Rende disponibile il [FocusStore] a tutta l'app: `FocusModeScope.of(context)`.
///
/// Si chiama FocusModeScope (e non FocusScope) perché Flutter ha già un
/// widget FocusScope, quello del focus della tastiera.
class FocusModeScope extends InheritedNotifier<FocusStore> {
  const FocusModeScope({super.key, required FocusStore store, required super.child}) : super(notifier: store);

  static FocusStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FocusModeScope>();
    assert(scope != null, 'Nessun FocusModeScope sopra questo widget');
    return scope!.notifier!;
  }
}
