import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/utils/formatters.dart';

void main() {
  // Usiamo i file JSON veri: se li modifichi e rompi qualcosa, il test lo dice.
  final planJson = fixture('workout_plan.json');
  final exercisesJson = File('assets/data/exercises.json').readAsStringSync();
  final data = WorkoutRepository.parse(planJson: planJson, exercisesJson: exercisesJson);
  // `!`: i dati di prova hanno sempre una scheda.
  final plan = data.plan!;

  group('Lettura JSON', () {
    test('legge i tre giorni e i loro blocchi', () {
      expect(plan.workouts.map((w) => w.id), ['push', 'pull', 'legs']);

      final push = plan.workoutById('push');
      expect(push.name, 'Push');
      expect(push.focus, 'Petto, spalle, tricipiti');
      expect(push.warmup!.exercises, hasLength(6));
      expect(push.exercises, hasLength(7));
      expect(data.exerciseFor(push.exercises.first).name, 'Chest press');

      // Ogni giorno ha il suo riscaldamento: il Legs parte dallo squat lento.
      expect(plan.workoutById('legs').warmup!.exercises[1].exerciseId, 'squat_lento');
      expect(plan.workoutById('legs').exercises, hasLength(8));
    });

    test('serie totali come nella scheda: Push 21, Pull 20, Legs 23', () {
      int totalSets(String id) =>
          plan.workoutById(id).exercises.fold(0, (sum, p) => sum + (p.sets ?? 0));
      expect(totalSets('push'), 21);
      expect(totalSets('pull'), 20);
      expect(totalSets('legs'), 23);
    });

    test('addominali e cardio sono uguali tutti i giorni', () {
      expect(
        plan.abs!.exercises.map((p) => p.exerciseId),
        ['crunch_macchina', 'plank', 'plank_laterale', 'leg_raise', 'heel_touch'],
      );
      expect(plan.cardio!.title, 'Cardio');
      expect(plan.cardio!.durationMinutes, 30);
      expect(plan.cardio!.inclinePercent, 10);
      expect(plan.cardio!.speedKmh, 5.5);
    });

    test('un id sbagliato dà un errore chiaro', () {
      final broken = planJson.replaceFirst('"leg_press"', '"leg_pres"');
      expect(
        () => WorkoutRepository.parse(planJson: broken, exercisesJson: exercisesJson),
        throwsA(isA<FormatException>()),
      );
    });

  });

  group('Calendario', () {
    test('17 sedute, dal 16/11 (Push) al 23/12 (Pull)', () {
      final sessions = plan.sessions;
      expect(sessions, hasLength(17));
      expect(sessions.first.date, DateTime(2026, 11, 16));
      expect(sessions.first.workoutId, 'push');
      expect(sessions.last.date, DateTime(2026, 12, 23));
      expect(sessions.last.workoutId, 'pull');
    });

    test('lunedì Push, mercoledì Pull, venerdì Legs, ogni settimana', () {
      const expected = {DateTime.monday: 'push', DateTime.wednesday: 'pull', DateTime.friday: 'legs'};
      for (final session in plan.sessions) {
        expect(session.workoutId, expected[session.date.weekday], reason: '${session.date}');
      }
    });

    test('martedì 10/11, prima della scheda → lunedì 16/11, Push', () {
      final next = plan.nextSessionFrom(DateTime(2026, 11, 10, 10, 30))!;
      expect(next.date, DateTime(2026, 11, 16));
      expect(next.workoutId, 'push');
    });

    test('nel giorno di allenamento, la seduta è oggi', () {
      final next = plan.nextSessionFrom(DateTime(2026, 11, 20, 18))!;
      expect(next.date, DateTime(2026, 11, 20));
      expect(next.workoutId, 'legs');
    });

    test('dopo il 23/12 la scheda è finita', () {
      expect(plan.nextSessionFrom(DateTime(2026, 12, 24)), isNull);
    });
  });

  group('Formattazione', () {
    test('recupero', () {
      expect(formatRest(120), "2'");
      expect(formatRest(90), '90"');
      expect(formatRest(60), '60"');
    });

    test('giorni', () {
      final now = DateTime(2026, 11, 8);
      expect(formatRelativeDay(DateTime(2026, 11, 8), now: now), 'oggi');
      expect(formatRelativeDay(DateTime(2026, 11, 9), now: now), 'domani');
      expect(formatRelativeDay(DateTime(2026, 11, 11), now: now), 'mercoledì 11 novembre');
    });

    test('pesi', () {
      expect(formatWeight(16), '16 kg');
      expect(formatWeight(22.5), '22,5 kg');
      expect(parseNumber('22,5'), 22.5);
      expect(parseNumber(' 40 '), 40);
      expect(parseNumber('tanti'), isNull);
    });
  });

  test('ogni esercizio ha un video YouTube valido e dei consigli', () {
    for (final e in data.exercises.values) {
      // Le macchine cardio (tapis roulant, cyclette...) non hanno bisogno di video.
      if (e.measure == ExerciseMeasure.cardio) continue;
      expect(e.videoUrl, isNotNull, reason: e.id);
      expect(YoutubePlayerController.convertUrlToId(e.videoUrl!), isNotNull, reason: e.id);
      expect(e.tips, isNotEmpty, reason: e.id);
    }
  });

  test('ogni esercizio ha la sua anteprima SVG', () {
    final missing = data.exercises.values
        .where((e) => !File(e.previewAsset).existsSync())
        .map((e) => e.id)
        .toList();
    expect(missing, isEmpty, reason: 'Rilancia tool/generate_exercise_previews.py');
  });

  test('la libreria ha i 5 esercizi ai macchinari aggiunti, nel loro gruppo', () {
    // La libreria è di tutti: ha anche esercizi che la scheda di prova non usa.
    const added = {
      'croci_cavi': MuscleGroup.petto,
      'alzate_laterali_cavo': MuscleGroup.spalle,
      'trazioni_assistite': MuscleGroup.schiena,
      'squat_multipower': MuscleGroup.gambe,
      'leg_curl_sdraiato': MuscleGroup.gambe,
    };
    expect(data.exercises, hasLength(46));
    for (final MapEntry(key: id, value: group) in added.entries) {
      expect(data.exercises[id]?.group, group, reason: id);
      expect(data.exercises[id]?.hasWeight, isTrue, reason: id);
    }
  });

  test('le illustrazioni dei muscoli esistono, solo sugli esercizi coi pesi', () {
    final withImage = data.exercises.values.where((e) => e.muscleAsset != null).toList();
    // 25 dei 28 esercizi coi pesi: iperestensioni, adductor e calf non hanno
    // ancora un'illustrazione (mancano lombari, adduttori e polpacci).
    expect(withImage, hasLength(25));
    for (final e in withImage) {
      expect(File(e.muscleAsset!).existsSync(), isTrue, reason: e.muscleAsset);
      expect(e.hasWeight, isTrue, reason: e.id);
    }
  });
}
