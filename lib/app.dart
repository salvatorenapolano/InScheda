import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/remote_data.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/home_shell.dart';

/// Il widget radice: configura tema, titolo e la prima schermata.
///
/// È uno StatelessWidget perché non ha dati che cambiano nel tempo:
/// si limita a "descrivere" l'app.
class MyWorkoutApp extends StatelessWidget {
  const MyWorkoutApp({
    super.key,
    required this.weights,
    required this.bodyWeights,
    required this.shopping,
    required this.data,
  });

  /// I pesi salvati: li mettiamo "sopra" tutta l'app con WeightScope,
  /// così ogni schermata li può leggere con WeightScope.of(context).
  final WeightStore weights;

  /// Lo storico delle pesate settimanali (tab Pesata).
  final BodyWeightStore bodyWeights;

  /// Le spunte della lista della spesa (tab Spesa).
  final ShoppingStore shopping;

  /// Scheda, dieta e immagini: quelle dell'app o quelle scaricate da GitHub.
  final DataStore data;

  @override
  Widget build(BuildContext context) {
    // Quattro "scope" uno dentro l'altro: ognuno rende disponibile il suo store.
    return DataScope(
      store: data,
      child: WeightScope(
        store: weights,
        child: BodyWeightScope(
          store: bodyWeights,
          child: ShoppingScope(
            store: shopping,
            // ListenableBuilder ridisegna l'app ogni volta che il DataStore
            // chiama notifyListeners(), cioè quando arrivano dati nuovi.
            child: ListenableBuilder(listenable: data, builder: (context, _) => _buildApp()),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'myWorkout',
      debugShowCheckedModeBanner: false,
      // Colori, font e forme stanno tutti in app_theme.dart.
      // Per provare un altro colore seme cambia AppTheme.seedColor.
      theme: AppTheme.light(),
      // Tema scuro: l'app lo usa da sola se l'iPhone è in modalità scura.
      darkTheme: AppTheme.dark(),
      // DefaultAssetBundle: da qui in giù Image.asset, SvgPicture.asset e i
      // repository leggono i file dal bundle dei dati (prima GitHub, poi l'app).
      builder: (context, child) => DefaultAssetBundle(bundle: data.bundle, child: child!),
      // La Key cambia quando cambiano i dati: Flutter butta via le pagine
      // vecchie e ne crea di nuove, che rileggono scheda, dieta e spesa.
      home: HomeShell(key: ValueKey(data.revision)),
    );
  }
}
