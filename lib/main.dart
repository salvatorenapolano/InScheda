import 'package:flutter/material.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/focus_alerts.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';

// Punto di ingresso: Dart esegue sempre main() per primo.
// È `async` perché, prima di disegnare l'app, apriamo la memoria del
// telefono dove sono salvati il profilo, i pesi (esercizi e pesate), le spunte della spesa
// e i dati creati dall'utente (scheda e dieta).
Future<void> main() async {
  // Serve prima di usare plugin nativi (come shared_preferences) in main().
  WidgetsFlutterBinding.ensureInitialized();
  final weights = await WeightStore.load();
  final bodyWeights = await BodyWeightStore.load();
  final shopping = await ShoppingStore.load();
  final profile = await ProfileStore.load();
  final userData = await UserDataStore.load();
  // Gli avvisi del Focus (vibrazione e notifica a fine recupero).
  final alerts = DeviceFocusAlerts();
  await alerts.init();
  final focus = await FocusStore.load(alerts: alerts);
  runApp(
    MyWorkoutApp(
      weights: weights,
      bodyWeights: bodyWeights,
      shopping: shopping,
      profile: profile,
      userData: userData,
      focus: focus,
    ),
  );
}
