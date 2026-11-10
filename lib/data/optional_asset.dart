import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Un "extension method": aggiunge un metodo a una classe che non è nostra
/// (AssetBundle è di Flutter), senza toccarla né crearne una sottoclasse.
/// Dopo l'import, qualunque bundle ha anche `loadStringOrNull`.
extension OptionalAsset on AssetBundle {
  /// Come loadString, ma se il file non c'è restituisce null invece di
  /// un errore. Serve per i dati che l'utente può non avere ancora
  /// (la scheda, la dieta, la spesa): "non c'è" non è un problema.
  Future<String?> loadStringOrNull(String key) async {
    try {
      return await loadString(key);
    } on FlutterError {
      // rootBundle segnala un asset mancante con un FlutterError
      // ("Unable to load asset"). Un JSON rotto invece arriva più avanti,
      // come FormatException, e resta un errore vero.
      return null;
    }
  }
}
