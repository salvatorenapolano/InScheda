import 'package:flutter/foundation.dart';

import 'package:my_workout/models/diet.dart';
import 'package:my_workout/utils/slug.dart';

/// Un alimento di un pasto mentre lo scrivi: "Pasta · 90 g".
class FoodItemDraft {
  const FoodItemDraft({required this.name, this.quantity, this.quantityMax, this.unit, this.note, this.foodId});

  final String name;
  final double? quantity;

  /// Per gli intervalli: "250–300" → quantity 250, quantityMax 300.
  final double? quantityMax;
  final String? unit;
  final String? note;

  /// L'id nel catalogo, se l'alimento arriva da una dieta già salvata:
  /// lo teniamo, così il riquadro dei legumi (che cerca "legumi") resta.
  final String? foodId;

  /// "90 g", "250–300 g" o null: lo calcola MealItem, che lo sa già fare.
  String? get amountLabel =>
      MealItem(foodId: '', quantity: quantity, quantityMax: quantityMax, unit: unit).amountLabel;
}

/// Un pasto (il pranzo del lunedì) mentre lo scrivi.
class MealDraft {
  MealDraft();

  /// Il nome del piatto, facoltativo.
  String title = '';
  final List<FoodItemDraft> items = [];

  // Arrivano da una dieta completa (del nutrizionista): l'editor non li
  // modifica, ma li conserva così non si perdono salvando.
  String? description;
  String? alternative;
  List<String> rules = const [];

  /// Vuoto = non finisce nella dieta salvata.
  bool get isEmpty => title.trim().isEmpty && items.isEmpty && description == null && rules.isEmpty;

  /// Un "riassunto" del contenuto: due pasti con la stessa firma sono
  /// uguali (stesso piatto, stessi alimenti nello stesso ordine...).
  String get signature => [
        title,
        for (final i in items) '${i.name}/${i.quantity}/${i.quantityMax}/${i.unit}/${i.note}',
        '$description',
        '$alternative',
        ...rules,
      ].join('|');

  /// Una copia indipendente (per "Copia il giorno"): cambiare l'una non
  /// cambia l'altra. `..` (cascade) imposta i campi sulla copia appena creata.
  MealDraft copy() => MealDraft()
    ..title = title
    ..items.addAll(items)
    ..description = description
    ..alternative = alternative
    ..rules = rules;
}

/// La dieta in preparazione, nell'editor della dieta.
///
/// Stessa idea di PlanDraft: un ChangeNotifier che vive finché l'editor è
/// aperto e diventa una [Diet] solo con [toDiet], al salvataggio.
class DietDraft extends ChangeNotifier {
  /// Una dieta nuova: pranzo e cena accesi, tutti i giorni vuoti.
  DietDraft() : _slots = {for (final slot in defaultSlots) slot.id: slot} {
    _active.addAll(const ['pranzo', 'cena']);
  }

  /// Per modificare una dieta già salvata.
  DietDraft.fromDiet(Diet diet)
      : _name = diet.name,
        _original = diet,
        // `...`: prima i momenti di default, poi quelli della dieta. Se un
        // id c'è in tutte e due vince quello della dieta (ha l'orario giusto),
        // e quelli in più (es. "Pranzo e cena") finiscono in fondo.
        _slots = {for (final slot in defaultSlots) slot.id: slot, ...diet.slots} {
    for (final (index, day) in diet.days.take(7).indexed) {
      for (final meal in day.meals) {
        _active.add(meal.slotId);
        _days[index][meal.slotId] = MealDraft()
          ..title = meal.title
          ..items.addAll([
            for (final item in meal.items)
              FoodItemDraft(
                name: diet.foods[item.foodId]?.name ?? item.foodId,
                quantity: item.quantity,
                quantityMax: item.quantityMax,
                unit: item.unit,
                note: item.note,
                foodId: item.foodId,
              ),
          ])
          ..description = meal.description
          ..alternative = meal.alternative
          ..rules = meal.rules;
      }
    }
    // Un pasto identico in tutti e 7 i giorni era "uguale tutti i giorni":
    // lo ricolleghiamo, così la spunta si ritrova accesa.
    for (final slotId in _active) {
      final meals = [for (final day in _days) day[slotId]];
      if (meals.every((m) => m != null && !m.isEmpty && m.signature == meals.first!.signature)) {
        _share(0, slotId);
      }
    }
  }

  static const dayNames = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

  /// I momenti che si possono accendere, nell'ordine della giornata.
  static const defaultSlots = [
    MealSlot(id: 'colazione', name: 'Colazione', emoji: '☕'),
    MealSlot(id: 'spuntino', name: 'Spuntino', emoji: '🍎'),
    MealSlot(id: 'pranzo', name: 'Pranzo', emoji: '☀️'),
    MealSlot(id: 'merenda', name: 'Merenda', emoji: '🥪'),
    MealSlot(id: 'cena', name: 'Cena', emoji: '🌙'),
  ];

  String _name = 'La mia dieta';

  /// La dieta da cui siamo partiti (se c'era): ne teniamo legumi, note,
  /// reparti e catalogo.
  Diet? _original;

  final Map<String, MealSlot> _slots;
  final Set<String> _active = {};

  /// I momenti "uguali tutti i giorni": per questi i 7 giorni puntano allo
  /// STESSO MealDraft, quindi cambiarlo in un giorno lo cambia in tutti.
  final Set<String> _everyDay = {};

  /// Sette giorni, ognuno con i suoi pasti per momento (slot id → pasto).
  /// List.generate crea 7 mappe diverse (con `List.filled` sarebbero
  /// 7 volte la STESSA mappa: cambiare il lunedì cambierebbe tutti!).
  final List<Map<String, MealDraft>> _days = List.generate(7, (_) => {});

  /// Tutti i momenti che si possono scegliere.
  List<MealSlot> get slots => _slots.values.toList();

  /// Solo quelli accesi, nell'ordine della giornata.
  List<MealSlot> get activeSlots => [for (final slot in _slots.values) if (_active.contains(slot.id)) slot];

  bool isActive(String slotId) => _active.contains(slotId);

  /// Il pasto di quel giorno e momento (vuoto se non l'hai ancora scritto).
  MealDraft meal(int day, String slotId) => _days[day].putIfAbsent(slotId, MealDraft.new);

  /// C'è almeno un pasto scritto? Senza, non c'è niente da salvare.
  bool get hasContent => [
        for (final day in _days)
          for (final slot in activeSlots) day[slot.id],
      ].any((meal) => meal != null && !meal.isEmpty);

  void toggleSlot(String slotId) {
    if (!_active.remove(slotId)) _active.add(slotId);
    notifyListeners();
  }

  /// true se quel pasto è uguale in tutti i giorni.
  bool isEveryDay(String slotId) => _everyDay.contains(slotId);

  /// Accendere la spunta "Uguale tutti i giorni" cambierebbe qualche altro
  /// giorno? (Serve per chiedere conferma prima.)
  bool othersDiffer(int day, String slotId) {
    final signature = meal(day, slotId).signature;
    return [
      for (var i = 0; i < 7; i++)
        if (i != day) _days[i][slotId],
    ].any((other) => other != null && !other.isEmpty && other.signature != signature);
  }

  /// Accende o spegne "Uguale tutti i giorni" partendo dal pasto di [day].
  /// Accesa: il pasto di [day] va in tutti i giorni (sostituendo gli altri).
  /// Spenta: ogni giorno si tiene una sua copia, che poi cambia da sola.
  void setEveryDay(int day, String slotId, bool value) {
    if (value) {
      _share(day, slotId);
    } else {
      _everyDay.remove(slotId);
      for (final d in _days) {
        final shared = d[slotId];
        if (shared != null) d[slotId] = shared.copy();
      }
    }
    notifyListeners();
  }

  void _share(int day, String slotId) {
    final shared = meal(day, slotId);
    for (final d in _days) {
      d[slotId] = shared;
    }
    _everyDay.add(slotId);
  }

  void setTitle(int day, String slotId, String title) {
    meal(day, slotId).title = title.trim();
    notifyListeners();
  }

  void addItem(int day, String slotId, FoodItemDraft item) {
    meal(day, slotId).items.add(item);
    notifyListeners();
  }

  void updateItem(int day, String slotId, int index, FoodItemDraft item) {
    meal(day, slotId).items[index] = item;
    notifyListeners();
  }

  void removeItem(int day, String slotId, int index) {
    meal(day, slotId).items.removeAt(index);
    notifyListeners();
  }

  /// Copia i pasti di [from] sui giorni [to] (sostituendo i loro).
  /// I pasti "uguali tutti i giorni" non si toccano: sono già uguali.
  void copyDay(int from, Iterable<int> to) {
    for (final day in to) {
      if (day == from) continue;
      _days[day]
        ..removeWhere((slotId, _) => !_everyDay.contains(slotId))
        ..addAll({
          for (final entry in _days[from].entries)
            if (!_everyDay.contains(entry.key)) entry.key: entry.value.copy(),
        });
    }
    notifyListeners();
  }

  /// La dieta finita. [trainingWeekdays] sono i giorni della scheda
  /// (1 = lunedì): quei giorni avranno il chip giallo "Palestra".
  Diet toDiet({required Set<int> trainingWeekdays}) {
    final original = _original;
    final foods = <String, Food>{};

    // Ogni alimento scritto diventa (o ritrova) una voce del catalogo.
    String foodIdFor(FoodItemDraft item) {
      final name = item.name.trim();
      // Stesso alimento di prima, con lo stesso nome: teniamo il suo id.
      final known = original?.foods[item.foodId];
      if (known != null && known.name == name) {
        foods[known.id] = known;
        return known.id;
      }
      // Già usato in un altro pasto (stesso nome, maiuscole a parte)?
      for (final food in foods.values) {
        if (food.name.toLowerCase() == name.toLowerCase()) return food.id;
      }
      final id = uniqueId(slugify(name, fallback: 'alimento'), foods.containsKey);
      foods[id] = Food(id: id, name: name);
      return id;
    }

    final days = [
      for (var i = 0; i < 7; i++)
        DietDay(
          name: dayNames[i],
          training: trainingWeekdays.contains(i + 1),
          meals: [
            for (final slot in activeSlots)
              if (_days[i][slot.id] case final draft? when !draft.isEmpty)
                Meal(
                  slotId: slot.id,
                  title: draft.title,
                  items: [
                    for (final item in draft.items)
                      MealItem(
                        foodId: foodIdFor(item),
                        quantity: item.quantity,
                        quantityMax: item.quantityMax,
                        unit: item.unit,
                        note: item.note,
                      ),
                  ],
                  description: draft.description,
                  alternative: draft.alternative,
                  rules: draft.rules,
                ),
          ],
        ),
    ];

    return Diet(
      name: _name,
      version: original?.version,
      slots: {for (final slot in activeSlots) slot.id: slot},
      // I reparti servono solo se qualche alimento ne ha uno.
      categories: foods.values.any((f) => f.category != null) ? original?.categories ?? const [] : const [],
      foods: foods,
      days: days,
      legumes: original?.legumes,
      notes: original?.notes ?? const [],
    );
  }
}
