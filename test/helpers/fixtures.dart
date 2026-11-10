import 'dart:io';

import 'package:flutter/services.dart';

/// La scheda, la dieta e la spesa di prova dei test (in test/fixtures/).
///
/// Nell'app non ci sono più: ogni utente parte senza dati. I test però
/// hanno bisogno di qualcosa da mostrare, e usano questi file.
const fixtureNames = ['workout_plan.json', 'diet.json', 'shopping.json'];

/// Il contenuto di un file di prova: fixture('diet.json').
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Un AssetBundle con i dati di prova "come se fossero negli asset", sopra
/// a rootBundle (che dà la libreria esercizi e le immagini vere).
///
/// I file si leggono subito, nel costruttore: così load() non fa I/O e
/// funziona anche col "tempo finto" dei widget test.
class FixtureBundle extends CachingAssetBundle {
  FixtureBundle()
      : _files = {
          for (final name in fixtureNames)
            'assets/data/$name': File('test/fixtures/$name').readAsBytesSync(),
        };

  final Map<String, Uint8List> _files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _files[key];
    if (bytes != null) return ByteData.sublistView(bytes);
    return rootBundle.load(key);
  }
}
