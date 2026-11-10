/// Una lista della spesa (settimanale o mensile), divisa in sezioni.
class ShoppingList {
  const ShoppingList({required this.id, required this.name, required this.sections});

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: [
        for (final s in json['sections'] as List) ShoppingSection.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final String id;

  /// Il nome della scheda in alto ("Settimanale", "Mensile").
  final String name;
  final List<ShoppingSection> sections;

  /// Tutti i prodotti della lista, sezione dopo sezione.
  /// `expand` "appiattisce" una lista di liste in una lista sola.
  Iterable<ShoppingItem> get items => sections.expand((s) => s.items);
}

/// Una sezione ("Frutta", "Surgelati"...) con i suoi prodotti.
class ShoppingSection {
  const ShoppingSection({required this.name, required this.items});

  factory ShoppingSection.fromJson(Map<String, dynamic> json) {
    return ShoppingSection(
      name: json['name'] as String,
      items: [
        for (final i in json['items'] as List) ShoppingItem.fromJson(i as Map<String, dynamic>),
      ],
    );
  }

  final String name;
  final List<ShoppingItem> items;
}

/// Un prodotto da comprare. L'`id` serve a ricordare la spunta sul telefono:
/// deve essere unico e non va cambiato, il nome invece sì.
class ShoppingItem {
  const ShoppingItem({required this.id, required this.name, this.quantity});

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
    );
  }

  final String id;
  final String name;

  /// "~500 g", "2 buste"... null se non serve (es. le spezie).
  final String? quantity;
}
