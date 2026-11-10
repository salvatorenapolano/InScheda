import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:my_workout/models/shopping.dart';

/// Legge shopping.json dagli asset. Stessa idea di DietRepository.
class ShoppingRepository {
  ShoppingRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _path = 'assets/data/shopping.json';

  Future<List<ShoppingList>> load() async => parse(await _bundle.loadString(_path));

  static List<ShoppingList> parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final lists = [
      for (final l in data['lists'] as List) ShoppingList.fromJson(l as Map<String, dynamic>),
    ];

    // Gli id servono a ricordare le spunte: due prodotti con lo stesso id
    // si spunterebbero insieme. Meglio accorgersene subito.
    final seen = <String>{};
    final duplicates = [
      for (final list in lists)
        for (final item in list.items)
          // Set.add restituisce false se l'elemento c'era già.
          if (!seen.add(item.id)) item.id,
    ];
    if (duplicates.isNotEmpty) {
      throw FormatException('shopping.json: id ripetuti: ${duplicates.join(', ')}');
    }
    return lists;
  }
}
