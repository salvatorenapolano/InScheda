import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/workout/widgets/today_banner.dart';
import 'package:my_workout/widgets/status_banner.dart';

void main() {
  final plan = WorkoutRepository.parse(
    planJson: fixture('workout_plan.json'),
    exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
  ).plan!;

  // Disegna solo il banner, fingendo che oggi sia `now`.
  Future<void> pumpBanner(WidgetTester tester, DateTime now) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TodayBanner(plan: plan, now: now))),
    );
  }

  testWidgets('giorno di allenamento: mostra il giorno e i muscoli', (tester) async {
    await pumpBanner(tester, DateTime(2026, 11, 16, 8)); // lunedì
    expect(find.text('Oggi: Push'), findsOneWidget);
    expect(find.text('Petto, spalle, tricipiti'), findsOneWidget);
  });

  testWidgets('la rotazione segue i giorni: mercoledì Pull, venerdì Legs', (tester) async {
    await pumpBanner(tester, DateTime(2026, 11, 18));
    expect(find.text('Oggi: Pull'), findsOneWidget);
    await pumpBanner(tester, DateTime(2026, 12, 4));
    expect(find.text('Oggi: Legs'), findsOneWidget);
  });

  testWidgets('il banner prende il colore della scheda di oggi', (tester) async {
    StatusBanner banner() => tester.widget<StatusBanner>(find.byType(StatusBanner));
    await pumpBanner(tester, DateTime(2026, 11, 16)); // Push, la prima
    expect(banner().color, workoutColor(0));
    await pumpBanner(tester, DateTime(2026, 11, 18)); // Pull, la seconda
    expect(banner().color, workoutColor(1));
    // Nei giorni di riposo il banner resta neutro.
    await pumpBanner(tester, DateTime(2026, 11, 15));
    expect(banner().color, isNull);
  });

  testWidgets('giorno di riposo: dice quando è il prossimo', (tester) async {
    await pumpBanner(tester, DateTime(2026, 11, 15)); // domenica
    expect(find.text('Oggi riposo'), findsOneWidget);
    expect(find.textContaining('domani: Push'), findsOneWidget);
  });

  testWidgets("prima dell'inizio: il prossimo allenamento è lunedì 16", (tester) async {
    await pumpBanner(tester, DateTime(2026, 11, 10));
    expect(find.textContaining('lunedì 16 novembre: Push'), findsOneWidget);
  });

  testWidgets('dopo il 23/12 la scheda è terminata', (tester) async {
    await pumpBanner(tester, DateTime(2026, 12, 24));
    expect(find.text('Scheda terminata'), findsOneWidget);
  });
}
