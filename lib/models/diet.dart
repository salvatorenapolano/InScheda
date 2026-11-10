import 'package:my_workout/utils/formatters.dart';

/// Un alimento del catalogo: nome e reparto del supermercato.
/// Il reparto servirà per raggruppare la lista della spesa.
class Food {
  const Food({required this.id, required this.name, required this.category});

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
    );
  }

  final String id;
  final String name;
  final String category;
}

/// Un ingrediente di un pasto: quale alimento e quanto.
class MealItem {
  const MealItem({
    required this.foodId,
    this.quantity,
    this.quantityMax,
    this.unit,
    this.note,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      foodId: json['foodId'] as String,
      // `num` accetta sia 90 che 90.5; toDouble() li rende uguali.
      // `?.` chiama toDouble() solo se il valore non è null.
      quantity: (json['quantity'] as num?)?.toDouble(),
      quantityMax: (json['quantityMax'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      note: json['note'] as String?,
    );
  }

  final String foodId;

  /// null quando la quantità è libera (es. "insalata").
  final double? quantity;

  /// Per gli intervalli come "250–300 g".
  final double? quantityMax;
  final String? unit;
  final String? note;

  /// "90 g", "250–300 g" oppure null se non c'è una quantità.
  String? get amountLabel {
    final q = quantity;
    if (q == null) return null;
    final max = quantityMax;
    final range = max == null ? formatNumber(q) : '${formatNumber(q)}–${formatNumber(max)}';
    return unit == null ? range : '$range $unit';
  }
}

/// Un momento della giornata: pranzo, cena...
class MealSlot {
  const MealSlot({required this.id, required this.name, this.time, this.emoji});

  factory MealSlot.fromJson(Map<String, dynamic> json) {
    return MealSlot(
      id: json['id'] as String,
      name: json['name'] as String,
      time: json['time'] as String?,
      emoji: json['emoji'] as String?,
    );
  }

  final String id;
  final String name;
  final String? time;

  /// ☀️ per il pranzo, 🌙 per la cena.
  final String? emoji;

  /// "Pranzo · 13:00"
  String get label => time == null ? name : '$name · $time';
}

/// Un pasto. Di solito ha degli ingredienti, ma può anche essere
/// solo una descrizione (la pizza) o delle regole (la domenica).
class Meal {
  const Meal({
    required this.slotId,
    required this.title,
    this.items = const [],
    this.description,
    this.alternative,
    this.rules = const [],
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      slotId: json['slot'] as String,
      title: json['title'] as String,
      items: (json['items'] as List? ?? const [])
          .map((item) => MealItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String?,
      alternative: json['alternative'] as String?,
      rules: List<String>.from(json['rules'] as List? ?? const []),
    );
  }

  final String slotId;
  final String title;
  final List<MealItem> items;
  final String? description;

  /// "Se manca il salmone: ..."
  final String? alternative;
  final List<String> rules;
}

/// Un giorno della settimana tipo.
class DietDay {
  const DietDay({required this.name, required this.training, required this.meals});

  factory DietDay.fromJson(Map<String, dynamic> json) {
    return DietDay(
      name: json['name'] as String,
      training: json['training'] as bool,
      meals: (json['meals'] as List)
          .map((item) => Meal.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String name;

  /// true nei giorni di palestra.
  final bool training;
  final List<Meal> meals;

  /// "Lunedì" → "Lun", per le schede in alto.
  String get shortName => name.substring(0, 3);

  bool usesFood(String foodId) => meals.any((m) => m.items.any((i) => i.foodId == foodId));
}

/// Il riquadro "I legumi a scelta".
class LegumesInfo {
  const LegumesInfo({required this.title, required this.description, required this.options});

  factory LegumesInfo.fromJson(Map<String, dynamic> json) {
    return LegumesInfo(
      title: json['title'] as String,
      description: json['description'] as String,
      options: List<String>.from(json['options'] as List),
    );
  }

  final String title;
  final String description;
  final List<String> options;
}

/// L'intera dieta (diet.json).
class Diet {
  const Diet({
    required this.name,
    required this.version,
    required this.slots,
    required this.categories,
    required this.foods,
    required this.days,
    required this.legumes,
    required this.notes,
  });

  factory Diet.fromJson(Map<String, dynamic> json) {
    final foodList = (json['foods'] as List)
        .map((item) => Food.fromJson(item as Map<String, dynamic>));
    return Diet(
      name: json['name'] as String,
      version: json['version'] as String,
      slots: {
        for (final item in json['slots'] as List)
          (item as Map<String, dynamic>)['id'] as String: MealSlot.fromJson(item),
      },
      categories: List<String>.from(json['categories'] as List),
      foods: {for (final food in foodList) food.id: food},
      days: (json['days'] as List)
          .map((item) => DietDay.fromJson(item as Map<String, dynamic>))
          .toList(),
      legumes: LegumesInfo.fromJson(json['legumes'] as Map<String, dynamic>),
      notes: List<String>.from(json['notes'] as List),
    );
  }

  final String name;
  final String version;
  final Map<String, MealSlot> slots;

  /// I reparti del supermercato, nell'ordine in cui li incontri.
  final List<String> categories;
  final Map<String, Food> foods;
  final List<DietDay> days;
  final LegumesInfo legumes;
  final List<String> notes;

  Food foodFor(MealItem item) => foods[item.foodId]!;
  MealSlot slotFor(Meal meal) => slots[meal.slotId]!;

  /// Controlla che ogni riferimento punti a qualcosa che esiste.
  /// Restituisce l'elenco dei problemi (vuoto = tutto ok).
  List<String> validate() {
    return [
      for (final day in days)
        for (final meal in day.meals) ...[
          if (!slots.containsKey(meal.slotId)) '${day.name}: momento "${meal.slotId}" sconosciuto',
          for (final item in meal.items)
            if (!foods.containsKey(item.foodId)) '${day.name}: alimento "${item.foodId}" non nel catalogo',
        ],
      for (final food in foods.values)
        if (!categories.contains(food.category)) '${food.name}: reparto "${food.category}" sconosciuto',
    ];
  }
}
