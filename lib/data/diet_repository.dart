import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:my_workout/models/diet.dart';

/// Legge diet.json dagli asset. Stessa idea di WorkoutRepository.
class DietRepository {
  DietRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  static const _path = 'assets/data/diet.json';

  Future<Diet> load() async => parse(await _bundle.loadString(_path));

  static Diet parse(String json) {
    final diet = Diet.fromJson(jsonDecode(json) as Map<String, dynamic>);
    final problems = diet.validate();
    if (problems.isNotEmpty) {
      throw FormatException('diet.json non è coerente:\n${problems.join('\n')}');
    }
    return diet;
  }
}
