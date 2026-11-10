import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:my_workout/data/optional_asset.dart';
import 'package:my_workout/models/diet.dart';

/// Legge diet.json dagli asset. Stessa idea di WorkoutRepository.
class DietRepository {
  DietRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Dove sta la dieta: negli asset e, allo stesso percorso, nei dati dell'utente.
  static const dietPath = 'assets/data/diet.json';

  /// null = l'utente non ha (ancora) una dieta.
  Future<Diet?> load() async {
    final json = await _bundle.loadStringOrNull(dietPath);
    return json == null ? null : parse(json);
  }

  static Diet parse(String json) {
    final diet = Diet.fromJson(jsonDecode(json) as Map<String, dynamic>);
    final problems = diet.validate();
    if (problems.isNotEmpty) {
      throw FormatException('diet.json non è coerente:\n${problems.join('\n')}');
    }
    return diet;
  }
}
