import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/plan_editor/exercise_picker_page.dart';
import 'package:my_workout/utils/search.dart';

void main() {
  group('matchesSearch', () {
    test('senza maiuscole né accenti, parole in qualsiasi ordine e a metà', () {
      const fields = ['Chest press', 'Pettorali', 'Tricipiti', 'Petto'];
      expect(matchesSearch('chest', fields), isTrue);
      expect(matchesSearch('PRESS chest', fields), isTrue);
      expect(matchesSearch('trici', fields), isTrue);
      expect(matchesSearch('  ', fields), isTrue, reason: 'ricerca vuota = tutto');
      expect(matchesSearch('chest gambe', fields), isFalse, reason: 'ogni parola deve esserci');
      expect(matchesSearch('lunedì', ['Lunedi']), isTrue);
      expect(normalizeForSearch('Glùtei È'), 'glutei e');
    });
  });

  testWidgets('la barra di ricerca filtra la libreria e propone di creare', (tester) async {
    final library = WorkoutRepository.parse(
      planJson: null,
      exercisesJson: File('assets/data/exercises.json').readAsStringSync(),
    ).exercises;
    await tester.pumpWidget(MaterialApp(home: ExercisePickerPage(library: library)));
    await tester.pumpAndSettle();

    // All'inizio c'è tutto, a partire dal petto.
    expect(find.text('Chest press'), findsOneWidget);

    // "alzate": le due alzate laterali, nella sezione Spalle, e nient'altro.
    await tester.enterText(find.byType(TextField), 'alzate');
    await tester.pumpAndSettle();
    expect(find.text('Alzate laterali con manubri'), findsOneWidget);
    expect(find.text('Alzate laterali al cavo'), findsOneWidget);
    // Solo quelle due righe ("Spalle" compare come sezione e come muscolo).
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Chest press'), findsNothing);
    expect(find.text('Petto'), findsNothing);

    // Cercando per muscolo: "femorali" trova i leg curl.
    await tester.enterText(find.byType(TextField), 'femorali');
    await tester.pumpAndSettle();
    expect(find.text('Leg curl seduto'), findsOneWidget);
    expect(find.text('Leg curl sdraiato'), findsOneWidget);

    // Spuntare durante una ricerca funziona come sempre.
    await tester.tap(find.text('Leg curl sdraiato'));
    await tester.pump();
    expect(find.text('Aggiungi (1)'), findsOneWidget);

    // Niente risultati: il messaggio e "Crea" col nome cercato.
    await tester.enterText(find.byType(TextField), 'panca multipower');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessun esercizio trovato'), findsOneWidget);
    expect(find.text('Crea "panca multipower"'), findsOneWidget);

    // La X svuota la ricerca e torna tutto; la spunta di prima resta.
    await tester.tap(find.byTooltip('Cancella la ricerca'));
    await tester.pumpAndSettle();
    expect(find.text('Chest press'), findsOneWidget);
    expect(find.text('Aggiungi (1)'), findsOneWidget);
  });
}
