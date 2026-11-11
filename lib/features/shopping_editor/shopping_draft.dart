import 'package:flutter/foundation.dart';

import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/utils/slug.dart';

/// Un prodotto mentre lo scrivi: "Latte · 2 L".
class ShoppingItemDraft {
  const ShoppingItemDraft({required this.name, this.quantity, this.note, this.id});

  final String name;
  final String? quantity;
  final String? note;

  /// L'id del prodotto già salvato. Resta lo stesso anche rinominandolo,
  /// così la sua spunta non si perde. null = prodotto nuovo.
  final String? id;

  /// "2 L · scremato", o null se non c'è niente da scrivere sotto il nome.
  String? get details {
    final parts = [quantity, note].nonNulls;
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// I prodotti di un reparto, dentro una lista.
class ShoppingSectionDraft {
  ShoppingSectionDraft(this.departmentId);

  final String departmentId;
  final List<ShoppingItemDraft> items = [];
}

/// Una lista ("Settimanale") mentre la scrivi.
class ShoppingListDraft {
  ShoppingListDraft({required this.id, required this.name});

  /// Non cambia rinominando la lista.
  final String id;
  String name;
  final List<ShoppingSectionDraft> sections = [];

  int get itemCount => sections.fold(0, (sum, s) => sum + s.items.length);

  /// La sezione di quel reparto, se la lista ce l'ha.
  ShoppingSectionDraft? section(String departmentId) {
    for (final s in sections) {
      if (s.departmentId == departmentId) return s;
    }
    return null;
  }

  /// Come [section], ma se manca la crea (in fondo).
  ShoppingSectionDraft _sectionOrNew(String departmentId) {
    final existing = section(departmentId);
    if (existing != null) return existing;
    final created = ShoppingSectionDraft(departmentId);
    sections.add(created);
    return created;
  }
}

/// La spesa in preparazione, nell'editor della spesa.
///
/// Stessa idea di DietDraft: un ChangeNotifier che vive finché l'editor è
/// aperto e diventa [ShoppingData] solo con [toData], al salvataggio.
class ShoppingDraft extends ChangeNotifier {
  /// Una spesa nuova: una lista "Settimanale", vuota.
  ShoppingDraft() {
    _lists.add(ShoppingListDraft(id: 'settimanale', name: 'Settimanale'));
  }

  /// Per modificare una spesa già salvata.
  ShoppingDraft.fromData(ShoppingData data) {
    _custom.addAll(data.departments);
    for (final list in data.lists) {
      final draft = ShoppingListDraft(id: list.id, name: list.name);
      for (final section in list.sections) {
        final department = _departmentForSection(data, section);
        draft._sectionOrNew(department.id).items.addAll([
          for (final item in section.items)
            ShoppingItemDraft(name: item.name, quantity: item.quantity, note: item.note, id: item.id),
        ]);
      }
      _lists.add(draft);
    }
    if (_lists.isEmpty) _lists.add(ShoppingListDraft(id: 'settimanale', name: 'Settimanale'));
  }

  final List<ShoppingListDraft> _lists = [];

  /// I reparti creati dall'utente.
  final List<ShoppingDepartment> _custom = [];

  /// Le liste, da leggere: per cambiarle si usano i metodi qui sotto,
  /// che avvisano chi ascolta (notifyListeners).
  List<ShoppingListDraft> get lists => List.unmodifiable(_lists);

  /// Tutti i reparti che si possono scegliere: prima quelli dell'app, poi i tuoi.
  List<ShoppingDepartment> get departments => [...ShoppingDepartment.defaultDepartments, ..._custom];

  ShoppingDepartment department(String id) =>
      departments.firstWhere((d) => d.id == id, orElse: () => ShoppingDepartment.otherDepartment);

  /// C'è almeno un prodotto? Senza, non c'è niente da salvare.
  bool get hasContent => _lists.any((l) => l.itemCount > 0);

  /// I nomi di tutti i prodotti scritti: servono ai suggerimenti.
  Iterable<String> get itemNames => [
        for (final list in _lists)
          for (final section in list.sections)
            for (final item in section.items) item.name,
      ];

  // ---------- Liste ----------

  /// Aggiunge una lista e restituisce la sua posizione (per aprirne la scheda).
  int addList(String name) {
    final id = uniqueId(slugify(name, fallback: 'lista'), (id) => _lists.any((l) => l.id == id));
    _lists.add(ShoppingListDraft(id: id, name: name.trim()));
    notifyListeners();
    return _lists.length - 1;
  }

  void renameList(int list, String name) {
    _lists[list].name = name.trim();
    notifyListeners();
  }

  /// Toglie una lista. L'ultima rimasta non si toglie: senza liste non
  /// ci sarebbe nemmeno una scheda da mostrare.
  void removeList(int list) {
    if (_lists.length <= 1) return;
    _lists.removeAt(list);
    notifyListeners();
  }

  // ---------- Prodotti ----------

  void addItem(int list, String departmentId, ShoppingItemDraft item) {
    _lists[list]._sectionOrNew(departmentId).items.add(item);
    notifyListeners();
  }

  /// Sostituisce un prodotto. Se gli hai cambiato reparto, lo sposta.
  void updateItem(int list, String fromDepartment, int index, String toDepartment, ShoppingItemDraft item) {
    final from = _lists[list].section(fromDepartment)!;
    if (fromDepartment == toDepartment) {
      from.items[index] = item;
    } else {
      from.items.removeAt(index);
      if (from.items.isEmpty) _lists[list].sections.remove(from);
      _lists[list]._sectionOrNew(toDepartment).items.add(item);
    }
    notifyListeners();
  }

  void removeItem(int list, String departmentId, int index) {
    _lists[list].section(departmentId)!.items.removeAt(index);
    notifyListeners();
  }

  // ---------- Reparti dentro una lista ----------

  /// Toglie il reparto dalla lista, con tutti i suoi prodotti.
  void removeSection(int list, String departmentId) {
    _lists[list].sections.removeWhere((s) => s.departmentId == departmentId);
    notifyListeners();
  }

  /// Sposta il reparto su (-1) o giù (+1): l'ordine è quello del tuo giro
  /// al supermercato.
  void moveSection(int list, String departmentId, int delta) {
    final sections = _lists[list].sections;
    final from = sections.indexWhere((s) => s.departmentId == departmentId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= sections.length) return;
    sections.insert(to, sections.removeAt(from));
    notifyListeners();
  }

  // ---------- Reparti personali ----------

  /// Crea un reparto tuo e lo restituisce (per sceglierlo subito).
  ShoppingDepartment addDepartment({required String name, required int color, required String icon}) {
    final department = ShoppingDepartment(
      id: uniqueId('reparto_${slugify(name, fallback: 'nuovo')}', (id) => departments.any((d) => d.id == id)),
      name: name.trim(),
      color: color,
      icon: icon,
    );
    _custom.add(department);
    notifyListeners();
    return department;
  }

  /// Cambia nome, colore o icona di un reparto tuo (l'id resta).
  void updateDepartment(ShoppingDepartment department) {
    final index = _custom.indexWhere((d) => d.id == department.id);
    if (index < 0) return;
    _custom[index] = department;
    notifyListeners();
  }

  /// Il reparto di una sezione letta dal file. Le liste scritte a mano
  /// possono avere sezioni senza reparto ("Pane e patate"): diventano un
  /// reparto personale con quel nome, così non si perde niente.
  ShoppingDepartment _departmentForSection(ShoppingData data, ShoppingSection section) {
    final known = data.departmentFor(section);
    if (known != null) return known;
    final name = section.name.trim();
    for (final d in _custom) {
      if (d.name.toLowerCase() == name.toLowerCase()) return d;
    }
    const palette = ShoppingDepartment.palette;
    final department = ShoppingDepartment(
      id: uniqueId('reparto_${slugify(name, fallback: 'nuovo')}', (id) => departments.any((d) => d.id == id)),
      name: name,
      color: palette[_custom.length % palette.length],
      icon: 'label',
    );
    _custom.add(department);
    return department;
  }

  // ---------- Salvataggio ----------

  /// La spesa finita: i reparti vuoti non si salvano, i prodotti nuovi
  /// ricevono un id ricavato dal nome ("Latte" → "latte", "latte_2"...).
  ShoppingData toData() {
    final taken = <String>{
      for (final list in _lists)
        for (final section in list.sections)
          for (final item in section.items) ?item.id,
    };
    String idFor(ShoppingItemDraft item) {
      final existing = item.id;
      if (existing != null) return existing;
      final id = uniqueId(slugify(item.name, fallback: 'prodotto'), taken.contains);
      taken.add(id);
      return id;
    }

    return ShoppingData(
      departments: List.of(_custom),
      lists: [
        for (final list in _lists)
          ShoppingList(
            id: list.id,
            name: list.name,
            sections: [
              for (final section in list.sections)
                if (section.items.isNotEmpty)
                  ShoppingSection(
                    name: department(section.departmentId).name,
                    departmentId: section.departmentId,
                    items: [
                      for (final item in section.items)
                        ShoppingItem(id: idFor(item), name: item.name, quantity: item.quantity, note: item.note),
                    ],
                  ),
            ],
          ),
      ],
    );
  }
}
