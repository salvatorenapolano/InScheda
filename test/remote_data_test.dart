import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:my_workout/data/remote_data.dart';
import 'package:my_workout/data/workout_repository.dart';

/// Un finto GitHub: ogni "commit" è una mappa percorso → contenuto.
/// MockClient risponde alle richieste http senza andare su internet.
class FakeGitHub {
  final commits = <String, Map<String, List<int>>>{};
  String head = '';
  int rawDownloads = 0;

  void commit(String sha, Map<String, List<int>> files) {
    commits[sha] = files;
    head = sha;
  }

  // L'hash di un file: cambia se cambia anche un solo byte.
  static String hash(List<int> bytes) => '${bytes.length}-${Object.hashAll(bytes)}';

  late final client = MockClient((request) async {
    final url = request.url.toString();
    if (url.endsWith('/commits/main')) {
      return http.Response(
        jsonEncode({
          'sha': head,
          'commit': {
            'message': 'Commit $head\n\nDettagli',
            'committer': {'date': '2026-11-10T12:00:00Z'},
            'tree': {'sha': 'tree-$head'},
          },
        }),
        200,
      );
    }
    if (url.contains('/git/trees/tree-')) {
      final sha = request.url.pathSegments.last.replaceFirst('tree-', '');
      return http.Response(
        jsonEncode({
          'truncated': false,
          'tree': [
            {'path': 'README.md', 'type': 'blob', 'sha': 'x'},
            for (final MapEntry(key: path, value: bytes) in commits[sha]!.entries)
              {'path': path, 'type': 'blob', 'sha': hash(bytes)},
          ],
        }),
        200,
      );
    }
    if (url.startsWith('https://raw.githubusercontent.com/')) {
      // .../<owner>/<repo>/<sha>/assets/...
      final segments = request.url.pathSegments;
      final sha = segments[2];
      final path = segments.skip(3).join('/');
      final bytes = commits[sha]?[path];
      if (bytes == null) return http.Response('not found', 404);
      rawDownloads++;
      return http.Response.bytes(bytes, 200);
    }
    return http.Response('?', 404);
  });
}

/// Tutti i file che l'app scarica, letti dalla cartella assets del progetto.
Map<String, List<int>> projectFiles() {
  final files = <String, List<int>>{};
  for (final folder in RemoteDataConfig.folders) {
    for (final entity in Directory(folder).listSync()) {
      if (entity is File) {
        files['$folder${entity.uri.pathSegments.last}'] = entity.readAsBytesSync();
      }
    }
  }
  return files;
}

void main() {
  // Serve a rootBundle e alla cache delle immagini anche fuori dai testWidgets.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late FakeGitHub github;
  late DataStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('remote_data_test');
    github = FakeGitHub();
    store = DataStore(root: root, client: github.client);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('senza dati scaricati il bundle legge gli asset dell\'app', () async {
    expect(store.info, isNull);
    final data = await WorkoutRepository(bundle: store.bundle).load();
    expect(data.plan.cardio.durationMinutes, 30);
  });

  test('scarica, usa i dati nuovi e poi scarica solo i file cambiati', () async {
    final files = projectFiles();
    github.commit('c1', files);

    final first = await store.update();
    expect(first, isA<Updated>());
    expect((first as Updated).downloaded, files.length);
    expect(store.info!.commit, 'c1');
    expect(store.info!.message, 'Commit c1'); // solo la prima riga
    expect(File('${root.path}/current.json').existsSync(), isTrue);

    // Stesso commit: niente da fare.
    expect(await store.update(), isA<AlreadyUpToDate>());

    // Nuovo commit con il cardio a 25 minuti: si scarica un solo file.
    final plan = utf8.decode(files['assets/data/workout_plan.json']!);
    github.commit('c2', {
      ...files,
      'assets/data/workout_plan.json': utf8.encode(plan.replaceFirst('"durationMinutes": 30', '"durationMinutes": 25')),
    });
    final before = github.rawDownloads;
    final second = await store.update();
    expect((second as Updated).downloaded, 1);
    expect(github.rawDownloads - before, 1);

    final data = await WorkoutRepository(bundle: store.bundle).load();
    expect(data.plan.cardio.durationMinutes, 25);
    // La cartella del commit vecchio è stata cancellata.
    expect(Directory('${root.path}/c1').existsSync(), isFalse);

    // Al riavvio dell'app si riparte dal commit salvato.
    final reloaded = DataStore(root: root, info: store.info, client: github.client);
    expect((await WorkoutRepository(bundle: reloaded.bundle).load()).plan.cardio.durationMinutes, 25);

    // "Torna ai dati dell'app" cancella tutto.
    await store.reset();
    expect(store.info, isNull);
    expect(root.existsSync(), isFalse);
  });

  test('dati rotti: errore chiaro e restano quelli di prima', () async {
    final files = projectFiles();
    github.commit('c1', files);
    await store.update();

    final plan = utf8.decode(files['assets/data/workout_plan.json']!);
    github.commit('c2', {
      ...files,
      // Un esercizio che non esiste in exercises.json.
      'assets/data/workout_plan.json': utf8.encode(plan.replaceFirst('"leg_press"', '"leg_pres"')),
    });
    final result = await store.update();
    expect(result, isA<UpdateFailed>());
    expect((result as UpdateFailed).message, contains('leg_pres'));
    expect(store.info!.commit, 'c1');
    expect(Directory('${root.path}/c2').existsSync(), isFalse);
  });

  test("un'immagine mancante viene segnalata", () async {
    final files = projectFiles();
    final exercises = utf8.decode(files['assets/data/exercises.json']!);
    github.commit('c1', {
      ...files,
      'assets/data/exercises.json': utf8.encode(exercises.replaceFirst('"muscleImage": "petto"', '"muscleImage": "pettorali"')),
    });
    final result = await store.update();
    expect((result as UpdateFailed).message, contains('pettorali.webp'));
    expect(store.info, isNull);
  });

  test('senza internet lo dice in italiano', () async {
    final offline = DataStore(
      root: root,
      client: MockClient((_) => throw const SocketException('offline')),
    );
    final result = await offline.update();
    expect((result as UpdateFailed).message, 'Nessuna connessione a internet');
  });
}
