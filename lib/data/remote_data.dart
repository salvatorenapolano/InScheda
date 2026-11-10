import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/workout_repository.dart';

/// Dove stanno i dati online: un repo GitHub pubblico con la stessa
/// cartella `assets/` dell'app (data/*.json, images/exercises, images/muscles).
abstract final class RemoteDataConfig {
  static const owner = 'salvatorenapolano';
  static const repo = 'myWorkout-data';
  static const branch = 'main';

  /// Le cartelle del repo che l'app scarica. Tutto il resto (README...) no.
  static const folders = [
    'assets/data/',
    'assets/images/exercises/',
    'assets/images/muscles/',
  ];
}

/// Un AssetBundle "a due piani": prima cerca il file tra i dati scaricati,
/// se non c'è usa quello dentro l'app (rootBundle).
///
/// AssetBundle è la classe con cui Flutter legge gli asset: Image.asset,
/// SvgPicture.asset e i nostri repository la usano già. Mettendo questo
/// bundle in DefaultAssetBundle (vedi app.dart) tutta l'app legge i dati
/// nuovi senza cambiare una riga nelle pagine.
///
/// CachingAssetBundle ci regala loadString con la cache: dobbiamo scrivere
/// solo load(), che restituisce i byte grezzi di un file.
class DataBundle extends CachingAssetBundle {
  DataBundle([this.directory]);

  /// La cartella dei dati scaricati, null = solo i dati dell'app.
  final Directory? directory;

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
    return rootBundle.load(key);
  }
}

/// Cosa abbiamo scaricato l'ultima volta: il commit di GitHub e, per ogni
/// file, il suo hash (cambia solo se cambia il contenuto del file).
class RemoteDataInfo {
  const RemoteDataInfo({
    required this.commit,
    required this.date,
    required this.message,
    required this.files,
  });

  factory RemoteDataInfo.fromJson(Map<String, dynamic> json) {
    return RemoteDataInfo(
      commit: json['commit'] as String,
      date: DateTime.parse(json['date'] as String),
      message: json['message'] as String,
      files: Map<String, String>.from(json['files'] as Map),
    );
  }

  final String commit;
  final DateTime date;

  /// La prima riga del messaggio del commit ("Scheda: +5 kg leg press").
  final String message;

  /// Percorso del file → hash del contenuto.
  final Map<String, String> files;

  Map<String, dynamic> toJson() => {
        'commit': commit,
        'date': date.toIso8601String(),
        'message': message,
        'files': files,
      };
}

/// Com'è andato un aggiornamento. `sealed`: i casi possibili sono solo
/// questi tre, e lo `switch` ci obbliga a gestirli tutti.
sealed class UpdateResult {
  const UpdateResult();
}

class AlreadyUpToDate extends UpdateResult {
  const AlreadyUpToDate();
}

class Updated extends UpdateResult {
  const Updated({required this.downloaded});

  /// Quanti file sono stati davvero scaricati (gli altri non erano cambiati).
  final int downloaded;
}

class UpdateFailed extends UpdateResult {
  const UpdateFailed(this.message);
  final String message;
}

/// Tiene i dati scaricati da GitHub e sa aggiornarli.
///
/// Sul telefono: `<cartella dell'app>/remote_data/current.json` dice quale
/// commit è in uso, i file stanno in `remote_data/<commit>/assets/...`.
class DataStore extends ChangeNotifier {
  DataStore({required this.root, http.Client? client, RemoteDataInfo? info})
      : _client = client ?? http.Client(),
        _info = info,
        _bundle = DataBundle(info == null ? null : Directory('${root.path}/${info.commit}'));

  /// Legge da disco quale versione dei dati è in uso (se ce n'è una).
  static Future<DataStore> load() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/remote_data');
    return DataStore(root: root, info: await _readInfo(root));
  }

  static Future<RemoteDataInfo?> _readInfo(Directory root) async {
    final file = File('${root.path}/current.json');
    if (!await file.exists()) return null;
    try {
      return RemoteDataInfo.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } on FormatException {
      return null; // file rovinato: si torna ai dati dell'app
    }
  }

  final Directory root;
  final http.Client _client;

  RemoteDataInfo? _info;
  DataBundle _bundle;
  int _revision = 0;
  bool _busy = false;

  /// null = l'app usa i dati con cui è stata installata.
  RemoteDataInfo? get info => _info;

  /// Il bundle da mettere in DefaultAssetBundle.
  AssetBundle get bundle => _bundle;

  /// Cresce a ogni cambio di dati: l'app lo usa come Key per ricaricare le pagine.
  int get revision => _revision;

  bool get busy => _busy;

  static const _headers = {
    // GitHub rifiuta le richieste senza User-Agent.
    'User-Agent': 'myWorkout-app',
    'Accept': 'application/vnd.github+json',
  };

  /// Scarica gli ultimi dati da GitHub. [onProgress] riceve (fatti, totale).
  Future<UpdateResult> update({void Function(int done, int total)? onProgress}) async {
    if (_busy) return const UpdateFailed('Aggiornamento già in corso');
    _busy = true;
    notifyListeners();
    Directory? newDir;
    try {
      const api = 'https://api.github.com/repos/${RemoteDataConfig.owner}/${RemoteDataConfig.repo}';

      // 1. L'ultimo commit del branch: se è quello che abbiamo, finito.
      final commitJson = await _getJson('$api/commits/${RemoteDataConfig.branch}');
      final sha = commitJson['sha'] as String;
      if (sha == _info?.commit) return const AlreadyUpToDate();
      final commit = commitJson['commit'] as Map<String, dynamic>;
      final treeSha = (commit['tree'] as Map<String, dynamic>)['sha'] as String;

      // 2. L'elenco di tutti i file del commit, ognuno col suo hash.
      final treeJson = await _getJson('$api/git/trees/$treeSha?recursive=1');
      if (treeJson['truncated'] == true) {
        return const UpdateFailed('Il repo ha troppi file per scaricarli in una volta');
      }
      final files = <String, String>{
        for (final entry in (treeJson['tree'] as List).cast<Map<String, dynamic>>())
          if (entry['type'] == 'blob' &&
              RemoteDataConfig.folders.any((f) => (entry['path'] as String).startsWith(f)))
            entry['path'] as String: entry['sha'] as String,
      };
      if (files.isEmpty) return const UpdateFailed('Nel repo non ci sono file in assets/');

      // 3. Una cartella nuova per questo commit. I file con lo stesso hash
      //    li copiamo da quella vecchia, gli altri li scarichiamo.
      newDir = Directory('${root.path}/$sha');
      if (await newDir.exists()) await newDir.delete(recursive: true);
      final oldDir = _bundle.directory;
      var done = 0;
      var downloaded = 0;
      for (final MapEntry(key: path, value: hash) in files.entries) {
        final target = File('${newDir.path}/$path');
        await target.parent.create(recursive: true);
        final oldFile = oldDir == null ? null : File('${oldDir.path}/$path');
        if (_info?.files[path] == hash && oldFile != null && await oldFile.exists()) {
          await oldFile.copy(target.path);
        } else {
          // Il link col commit (non col branch) non cambia mai: niente cache vecchie.
          final url = 'https://raw.githubusercontent.com/${RemoteDataConfig.owner}/'
              '${RemoteDataConfig.repo}/$sha/$path';
          final response = await _client.get(Uri.parse(url), headers: _headers);
          if (response.statusCode != 200) {
            throw HttpException('$path: errore ${response.statusCode}');
          }
          await target.writeAsBytes(response.bodyBytes);
          downloaded++;
        }
        onProgress?.call(++done, files.length);
      }

      // 4. Prima di usarli, controlliamo che i dati si leggano davvero.
      final newBundle = DataBundle(newDir);
      final problem = await validate(newBundle);
      if (problem != null) {
        await newDir.delete(recursive: true);
        return UpdateFailed(problem);
      }

      // 5. Tutto ok: segniamo il nuovo commit come quello in uso.
      final info = RemoteDataInfo(
        commit: sha,
        date: DateTime.parse((commit['committer'] as Map<String, dynamic>)['date'] as String),
        message: (commit['message'] as String).split('\n').first,
        files: files,
      );
      await _writeInfo(info);
      if (oldDir != null && await oldDir.exists()) await oldDir.delete(recursive: true);
      _use(info, newBundle);
      return Updated(downloaded: downloaded);
    } on SocketException {
      await _cleanUp(newDir);
      return const UpdateFailed('Nessuna connessione a internet');
    } catch (e) {
      await _cleanUp(newDir);
      return UpdateFailed(e is HttpException ? e.message : '$e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Torna ai dati con cui è stata installata l'app e cancella quelli scaricati.
  Future<void> reset() async {
    if (await root.exists()) await root.delete(recursive: true);
    _use(null, DataBundle());
  }

  /// Prova a leggere scheda, dieta e spesa con [bundle], e controlla che
  /// ogni esercizio abbia anteprima e (se indicata) illustrazione dei muscoli.
  /// Restituisce il problema trovato, o null se è tutto a posto.
  static Future<String?> validate(AssetBundle bundle) async {
    try {
      final workout = await WorkoutRepository(bundle: bundle).load();
      await DietRepository(bundle: bundle).load();
      await ShoppingRepository(bundle: bundle).load();
      for (final exercise in workout.exercises.values) {
        for (final asset in [exercise.previewAsset, ?exercise.muscleAsset]) {
          try {
            await bundle.load(asset);
          } catch (_) {
            // rootBundle segnala un asset mancante con un FlutterError,
            // che non è un'Exception: per questo `catch` senza `on`.
            return 'Manca l\'immagine $asset';
          }
        }
      }
      return null;
    } catch (e) {
      // FormatException (id sbagliato, JSON rotto) ma anche TypeError
      // (un campo col tipo sbagliato, es. un numero tra virgolette).
      return 'I dati scaricati non sono validi: $e';
    }
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const HttpException('GitHub ha detto "troppe richieste": riprova tra un\'ora');
    }
    if (response.statusCode != 200) {
      throw HttpException('GitHub ha risposto ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _writeInfo(RemoteDataInfo info) async {
    await root.create(recursive: true);
    // Prima scriviamo un file temporaneo, poi lo rinominiamo: se l'app si
    // chiude a metà, current.json non resta mai scritto per metà.
    final tmp = File('${root.path}/current.json.tmp');
    await tmp.writeAsString(jsonEncode(info.toJson()));
    await tmp.rename('${root.path}/current.json');
  }

  Future<void> _cleanUp(Directory? dir) async {
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }

  void _use(RemoteDataInfo? info, DataBundle bundle) {
    _info = info;
    _bundle = bundle;
    _revision++;
    // Le immagini già disegnate restano in memoria: le buttiamo via,
    // così le anteprime e i muscoli nuovi si vedono subito.
    PaintingBinding.instance.imageCache.clear();
    svg.cache.clear();
    notifyListeners();
  }
}

/// Rende disponibile il DataStore a tutta l'app, come WeightScope.
class DataScope extends InheritedNotifier<DataStore> {
  const DataScope({super.key, required DataStore store, required super.child})
      : super(notifier: store);

  static DataStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DataScope>()!.notifier!;
  }
}
