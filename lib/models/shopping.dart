/// Un reparto del supermercato ("Frigo", "Surgelati"...), con il colore e
/// l'icona che lo distinguono nella lista.
///
/// Come MuscleGroup, il modello non dipende da Flutter: il colore è un
/// numero 0xAARRGGBB e l'icona è un nome ("kitchen"), che la UI trasforma
/// in un'icona vera (vedi `department_badge.dart`).
class ShoppingDepartment {
  const ShoppingDepartment({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  factory ShoppingDepartment.fromJson(Map<String, dynamic> json) {
    return ShoppingDepartment(
      id: json['id'] as String,
      name: json['name'] as String,
      color: parseHexColor(json['color'] as String?) ?? otherDepartment.color,
      icon: json['icon'] as String? ?? otherDepartment.icon,
    );
  }

  final String id;
  final String name;

  /// 0xFFRRGGBB: nel JSON si scrive "#RRGGBB", più facile da leggere.
  final int color;
  final String icon;

  /// true se l'ha creato l'utente (non è tra quelli dell'app).
  bool get isCustom => !defaultDepartments.any((d) => d.id == id);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': formatHexColor(color),
        'icon': icon,
      };

  /// I reparti che l'app offre già, nell'ordine di un giro al supermercato.
  static const defaultDepartments = [
    ShoppingDepartment(id: 'frutta_verdura', name: 'Frutta e verdura', color: 0xFF34A853, icon: 'eco'),
    ShoppingDepartment(id: 'pane', name: 'Pane', color: 0xFFC98A2E, icon: 'bakery'),
    ShoppingDepartment(id: 'carne_pesce', name: 'Carne e pesce', color: 0xFFE5534B, icon: 'fish'),
    ShoppingDepartment(id: 'frigo', name: 'Frigo', color: 0xFF3D8BD9, icon: 'fridge'),
    ShoppingDepartment(id: 'dispensa', name: 'Dispensa', color: 0xFFE07B39, icon: 'pantry'),
    ShoppingDepartment(id: 'surgelati', name: 'Surgelati', color: 0xFF22A6B3, icon: 'frozen'),
    ShoppingDepartment(id: 'bevande', name: 'Bevande', color: 0xFF7C6FE0, icon: 'drink'),
    ShoppingDepartment(id: 'casa', name: 'Casa e igiene', color: 0xFFD45D9C, icon: 'cleaning'),
    otherDepartment,
  ];

  /// "Altro": per quello che non sta in nessun reparto.
  static const otherDepartment =
      ShoppingDepartment(id: 'altro', name: 'Altro', color: 0xFF8A8F98, icon: 'basket');

  /// I colori tra cui scegliere per un reparto personale.
  static const palette = [
    0xFF34A853, 0xFFC98A2E, 0xFFE5534B, 0xFF3D8BD9, 0xFFE07B39,
    0xFF22A6B3, 0xFF7C6FE0, 0xFFD45D9C, 0xFF8A8F98,
  ];

  /// Le icone tra cui scegliere (i nomi; le icone vere sono nella UI).
  static const icons = [
    'basket', 'eco', 'bakery', 'fish', 'fridge', 'pantry', 'frozen', 'drink',
    'cleaning', 'egg', 'coffee', 'pets', 'baby', 'medication', 'wine', 'label',
  ];
}

/// "#34A853" → 0xFF34A853. null se il testo non è un colore.
int? parseHexColor(String? text) {
  if (text == null) return null;
  final hex = text.replaceFirst('#', '');
  if (hex.length != 6) return null;
  // int.tryParse con radix 16: legge il numero in esadecimale.
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : 0xFF000000 | value;
}

/// 0xFF34A853 → "#34A853".
String formatHexColor(int color) =>
    // & 0xFFFFFF toglie l'opacità (le prime due cifre), padLeft rimette
    // gli zeri davanti: 0x00A0FF → "00A0FF" e non "A0FF".
    '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Tutta la spesa dell'utente: i suoi reparti e le sue liste.
class ShoppingData {
  const ShoppingData({this.departments = const [], required this.lists});

  factory ShoppingData.fromJson(Map<String, dynamic> json) {
    return ShoppingData(
      departments: [
        for (final d in json['departments'] as List? ?? const [])
          ShoppingDepartment.fromJson(d as Map<String, dynamic>),
      ],
      lists: [
        for (final l in json['lists'] as List) ShoppingList.fromJson(l as Map<String, dynamic>),
      ],
    );
  }

  /// Solo i reparti creati dall'utente: quelli dell'app sono nel codice.
  final List<ShoppingDepartment> departments;
  final List<ShoppingList> lists;

  /// Tutti i reparti: prima quelli dell'app, poi quelli dell'utente.
  List<ShoppingDepartment> get allDepartments => [
        ...ShoppingDepartment.defaultDepartments,
        ...departments,
      ];

  /// Il reparto di una sezione: per id, oppure (nelle liste scritte a mano,
  /// senza `department`) per nome. null se non lo troviamo.
  ShoppingDepartment? departmentFor(ShoppingSection section) {
    final all = allDepartments;
    final id = section.departmentId;
    if (id != null) {
      for (final d in all) {
        if (d.id == id) return d;
      }
    }
    final name = section.name.trim().toLowerCase();
    for (final d in all) {
      if (d.name.toLowerCase() == name) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        if (departments.isNotEmpty) 'departments': [for (final d in departments) d.toJson()],
        'lists': [for (final l in lists) l.toJson()],
      };
}

/// Una lista della spesa ("Settimanale", "Mensile"...), divisa in sezioni.
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sections': [for (final s in sections) s.toJson()],
      };
}

/// Una sezione della lista: i prodotti di un reparto.
class ShoppingSection {
  const ShoppingSection({required this.name, this.departmentId, required this.items});

  factory ShoppingSection.fromJson(Map<String, dynamic> json) {
    return ShoppingSection(
      name: json['name'] as String,
      departmentId: json['department'] as String?,
      items: [
        for (final i in json['items'] as List) ShoppingItem.fromJson(i as Map<String, dynamic>),
      ],
    );
  }

  /// Il nome scritto nel file. Se c'è il reparto, la UI usa il nome del
  /// reparto (così rinominarlo cambia tutte le liste).
  final String name;

  /// L'id del reparto. Facoltativo: le liste scritte a mano possono non averlo.
  final String? departmentId;
  final List<ShoppingItem> items;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (departmentId != null) 'department': departmentId,
        'items': [for (final i in items) i.toJson()],
      };
}

/// Un prodotto da comprare. L'`id` serve a ricordare la spunta sul telefono:
/// deve essere unico e non va cambiato, il nome invece sì.
class ShoppingItem {
  const ShoppingItem({required this.id, required this.name, this.quantity, this.note});

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      note: json['note'] as String?,
    );
  }

  final String id;
  final String name;

  /// "500 g", "2 buste"... null se non serve (es. le spezie).
  final String? quantity;

  /// Un consiglio in più ("affettalo e congelalo"), scritto piccolo sotto il nome.
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (quantity != null) 'quantity': quantity,
        if (note != null) 'note': note,
      };
}
