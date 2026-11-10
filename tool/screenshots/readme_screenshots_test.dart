// Disegna le schermate dell'app per il README, senza emulatore.
//
// Uso:  flutter test tool/screenshots/readme_screenshots_test.dart
//
// È un "test" solo perché usa lo stesso motore dei widget test: monta l'app
// vera con dati di prova, la fa disegnare e salva ogni schermata in
// docs/screenshots/. Sta in tool/ e non in test/, così `flutter test` da
// solo non la lancia (e non riscrive le immagini a ogni giro di test).
//
// Nei test Flutter non ha font: le lettere sarebbero quadratini. Per questo
// carichiamo a mano Roboto e le icone Material (dalla cartella di Flutter) e
// i font dell'app (Barlow e Russo One, dagli asset).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/exercise_picker_page.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';

/// Dimensione del telefono (punti) e quanti pixel per punto nelle immagini.
const _phone = Size(390, 844);
const _pixelRatio = 2.5;
const _outDir = 'docs/screenshots';

final _shotKey = GlobalKey();

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  final material = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  await _loadFont('Roboto', [
    for (final w in ['regular', 'medium', 'bold']) '$material/roboto-$w.ttf',
  ]);
  await _loadFont('MaterialIcons', ['$material/materialicons-regular.otf']);
  await _loadFont('Barlow', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/BarlowSemiCondensed-$w.ttf',
  ]);
  await _loadFont('RussoOne', ['assets/fonts/RussoOne-Regular.ttf']);
}

/// La scheda e la dieta di prova (test/fixtures), con la scheda spostata
/// in modo che OGGI sia un giorno di allenamento: così il banner è pieno.
class _ShowcaseBundle extends CachingAssetBundle {
  _ShowcaseBundle() {
    final now = DateTime.now();
    final plan = jsonDecode(File('test/fixtures/workout_plan.json').readAsStringSync()) as Map<String, dynamic>;
    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    plan['startDate'] = day(now);
    plan['endDate'] = day(now.add(const Duration(days: 60)));
    // Oggi, dopodomani e fra quattro giorni (1 = lunedì … 7 = domenica).
    (plan['schedule'] as Map<String, dynamic>)['weekdays'] =
        ([for (final k in [0, 2, 4]) (now.weekday - 1 + k) % 7 + 1]..sort());
    // Nei test non c'è un font per le emoji (☀️ 🌙): verrebbero quadratini.
    // Sul telefono si vedono; qui togliamo l'emoji dai momenti della dieta.
    final diet = jsonDecode(File('test/fixtures/diet.json').readAsStringSync()) as Map<String, dynamic>;
    for (final slot in diet['slots'] as List) {
      (slot as Map<String, dynamic>).remove('emoji');
    }
    _files = {
      WorkoutRepository.planPath: utf8.encode(jsonEncode(plan)),
      'assets/data/diet.json': utf8.encode(jsonEncode(diet)),
    };
  }

  late final Map<String, List<int>> _files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = _files[key];
    if (bytes != null) return ByteData.sublistView(Uint8List.fromList(bytes));
    return rootBundle.load(key);
  }
}

/// Lascia finire caricamenti e immagini (SVG e webp vogliono tempo vero).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// Precarica le immagini (le illustrazioni dei muscoli) sullo schermo.
Future<void> _precacheImages(WidgetTester tester) async {
  for (final element in find.byType(Image).evaluate()) {
    final image = element.widget as Image;
    await tester.runAsync(() => precacheImage(image.image, element));
  }
  await _settle(tester);
}

/// Salva la schermata in docs/screenshots/<name>.png.
///
/// Nei test le ombre sono spente e al loro posto c'è un bordo nero
/// (debugDisableShadows): le accendiamo solo mentre disegniamo e poi le
/// rimettiamo come prima, perché Flutter controlla alla fine di ogni test
/// che i valori di debug siano tornati a posto.
Future<void> _shot(WidgetTester tester, String name) async {
  debugDisableShadows = false;
  // Le parti già disegnate restano in cache: le segniamo tutte da
  // ridisegnare, così le ombre compaiono davvero.
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(tester.renderObject(find.byKey(_shotKey)));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
  debugDisableShadows = true;
}

Future<MyWorkoutApp> _app({required bool onboardingDone}) async {
  final today = DateTime.now();
  String day(int daysAgo) => today.subtract(Duration(days: daysAgo)).toIso8601String().substring(0, 10);
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'profile_name': 'Mario Rossi',
    // La pesata è oggi (e non c'è ancora): il banner la ricorda.
    'weigh_in_weekday': today.weekday,
    'body_weights': jsonEncode([
      for (final (i, kg) in [(7, 78.4), (14, 79.0), (21, 79.3), (28, 80.1)]) {'date': day(i), 'kg': kg},
    ]),
    'weight_chest_press': 40.0,
    'weight_pec_deck': 30.0,
    'weight_shoulder_press_macchina': 25.0,
    'weight_alzate_laterali_manubri': 8.0,
  });
  return MyWorkoutApp(
    weights: await WeightStore.load(),
    bodyWeights: await BodyWeightStore.load(),
    shopping: await ShoppingStore.load(),
    profile: await ProfileStore.load(),
    userData: UserDataStore(root: Directory.systemTemp.createTempSync('screenshots')),
    assets: _ShowcaseBundle(),
  );
}

void main() {
  setUpAll(() async {
    ExerciseMedia.videoEnabled = false;
    await _loadFonts();
  });

  // Come su un telefono touch: niente anelli di "focus" da tastiera
  // attorno ai pulsanti (nei test sarebbero attivi).
  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch);

  setUp(() => rootBundle.clear());

  void phone(WidgetTester tester) {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('onboarding', (tester) async {
    phone(tester);
    await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: await _app(onboardingDone: false)));
    await _settle(tester);
    await _shot(tester, '1_benvenuto');
  });

  testWidgets('tab e dettaglio', (tester) async {
    phone(tester);
    await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: await _app(onboardingDone: true)));
    await _settle(tester);
    await _shot(tester, '2_allenamento');

    await tester.tap(find.text('Chest press'));
    await _settle(tester);
    await _precacheImages(tester);
    await _shot(tester, '3_esercizio');
    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    await tester.tap(find.text('Dieta'));
    await _settle(tester);
    await _shot(tester, '5_dieta');

    await tester.tap(find.text('Pesata'));
    await _settle(tester);
    await _shot(tester, '6_pesata');
  });

  testWidgets('libreria esercizi', (tester) async {
    phone(tester);
    final library = WorkoutRepository.parse(
      planJson: null,
      exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
    ).exercises;
    await tester.pumpWidget(RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: ExercisePickerPage(library: library, alreadyChosen: const {'chest_press'}),
      ),
    ));
    await _settle(tester);
    // Qualche esercizio spuntato, come mentre si prepara una scheda.
    await tester.tap(find.text('Pec deck (butterfly)'));
    await tester.tap(find.text('Croci ai cavi'));
    await _settle(tester);
    await _shot(tester, '4_libreria');
  });
}
