import 'dart:io';

import 'package:flutter/services.dart';

/// Un AssetBundle "a piani": prima cerca il file nella sua cartella,
/// se non c'è lo chiede al piano di sotto ([below], di default i file
/// dentro l'app, cioè rootBundle).
///
/// L'app ne usa due piani:
///   dati dell'utente (scheda, dieta)  →  dati dell'app (libreria, immagini)
/// cioè un DataBundle con la cartella dell'utente sopra rootBundle.
/// Vedi UserDataStore.bundleOver.
///
/// AssetBundle è la classe con cui Flutter legge gli asset: Image.asset,
/// SvgPicture.asset e i nostri repository la usano già. Mettendo questo
/// bundle in DefaultAssetBundle (vedi app.dart) tutta l'app legge i dati
/// dell'utente senza cambiare una riga nelle pagine.
///
/// CachingAssetBundle ci regala loadString con la cache: dobbiamo scrivere
/// solo load(), che restituisce i byte grezzi di un file.
class DataBundle extends CachingAssetBundle {
  DataBundle([this.directory, AssetBundle? below]) : _below = below ?? rootBundle;

  /// La cartella di questo piano, null = si passa subito a quello di sotto.
  final Directory? directory;

  final AssetBundle _below;

  @override
  Future<ByteData> load(String key) async {
    final dir = directory;
    if (dir != null) {
      final file = File('${dir.path}/$key');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        // ByteData è una "vista" sui byte: niente copie.
        return ByteData.sublistView(bytes);
      }
    }
    return _below.load(key);
  }
}
