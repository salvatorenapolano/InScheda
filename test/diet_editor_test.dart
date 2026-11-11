import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/diet_editor/diet_draft.dart';
import 'package:my_workout/features/diet_editor/food_item_dialog.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/diet.dart';

import 'helpers/fixtures.dart';
import 'helpers/real_io.dart';

void main() {
  test('parseQuantity: numeri, virgole e intervalli', () {
    expect(parseQuantity('90'), (90.0, null));
    expect(parseQuantity(' 1,5 '), (1.5, null));
    expect(parseQuantity('250-300'), (250.0, 300.0));
    expect(parseQuantity('250 – 300'), (250.0, 300.0));
    expect(parseQuantity('300-250'), (300.0, null));
    expect(parseQuantity(''), (null, null));
    expect(parseQuantity('un po\''), (null, null));
  });

  group('DietDraft', () {
    test('parte con pranzo e cena accesi e niente da salvare', () {
      final draft = DietDraft();
      expect(draft.activeSlots.map((s) => s.id), ['pranzo', 'cena']);
      expect(draft.hasContent, isFalse);
    });

    test('toDiet: catalogo dagli alimenti scritti, giorni di palestra dalla scheda', () {
      final draft = DietDraft()
        ..addItem(0, 'pranzo', const FoodItemDraft(name: 'Pasta', quantity: 90, unit: 'g'))
        ..addItem(0, 'cena', const FoodItemDraft(name: 'Petto di pollo', quantity: 180, unit: 'g'))
        // Stesso alimento, scritto con un'altra maiuscola: una voce sola.
        ..addItem(2, 'pranzo', const FoodItemDraft(name: 'pasta', quantity: 80, unit: 'g'))
        ..setTitle(0, 'pranzo', 'Pasta al pomodoro');
      expect(draft.hasContent, isTrue);

      final diet = draft.toDiet(trainingWeekdays: {1, 3});
      expect(diet.validate(), isEmpty);
      expect(diet.foods.keys, ['pasta', 'petto_di_pollo']);
      expect(diet.days, hasLength(7));
      expect(diet.days.where((d) => d.training).map((d) => d.name), ['Lunedì', 'Mercoledì']);
      expect(diet.days[0].meals.map((m) => m.title), ['Pasta al pomodoro', '']);
      // Martedì non ha pasti scritti: niente pasti vuoti nella dieta.
      expect(diet.days[1].meals, isEmpty);
      // Solo i momenti accesi finiscono nella dieta.
      expect(diet.slots.keys, ['pranzo', 'cena']);
    });

    test('un momento spento non viene salvato', () {
      final draft = DietDraft()
        ..addItem(0, 'cena', const FoodItemDraft(name: 'Salmone'))
        ..toggleSlot('colazione')
        ..addItem(0, 'colazione', const FoodItemDraft(name: 'Yogurt'))
        ..toggleSlot('cena');
      final diet = draft.toDiet(trainingWeekdays: {});
      expect(diet.days[0].meals.map((m) => m.slotId), ['colazione']);
      expect(diet.foods.keys, ['yogurt']);
    });

    test('copia un giorno su altri, e le copie sono indipendenti', () {
      final draft = DietDraft()..addItem(0, 'pranzo', const FoodItemDraft(name: 'Riso', quantity: 80, unit: 'g'));
      draft.copyDay(0, [1, 2]);
      draft.addItem(1, 'pranzo', const FoodItemDraft(name: 'Zucchine'));
      expect(draft.meal(2, 'pranzo').items.map((i) => i.name), ['Riso']);
      expect(draft.meal(1, 'pranzo').items.map((i) => i.name), ['Riso', 'Zucchine']);
      expect(draft.meal(0, 'pranzo').items.map((i) => i.name), ['Riso']);
    });

    test('uguale tutti i giorni: un solo pasto per 7 giorni', () {
      final draft = DietDraft()
        ..toggleSlot('colazione')
        ..addItem(2, 'colazione', const FoodItemDraft(name: 'Yogurt greco', quantity: 170, unit: 'g'))
        ..setEveryDay(2, 'colazione', true);
      expect(draft.isEveryDay('colazione'), isTrue);
      // Il mercoledì è finito in tutti i giorni…
      for (var day = 0; day < 7; day++) {
        expect(draft.meal(day, 'colazione').items.map((i) => i.name), ['Yogurt greco'], reason: '$day');
      }
      // …e cambiarlo di sabato lo cambia anche di lunedì.
      draft.addItem(5, 'colazione', const FoodItemDraft(name: 'Miele'));
      expect(draft.meal(0, 'colazione').items.map((i) => i.name), ['Yogurt greco', 'Miele']);

      final diet = draft.toDiet(trainingWeekdays: {});
      expect(diet.days.every((d) => d.meals.any((m) => m.slotId == 'colazione')), isTrue);
    });

    test('spegnendo la spunta ogni giorno torna indipendente', () {
      final draft = DietDraft()
        ..addItem(0, 'pranzo', const FoodItemDraft(name: 'Riso'))
        ..setEveryDay(0, 'pranzo', true)
        ..setEveryDay(0, 'pranzo', false)
        ..addItem(1, 'pranzo', const FoodItemDraft(name: 'Zucchine'));
      expect(draft.isEveryDay('pranzo'), isFalse);
      expect(draft.meal(0, 'pranzo').items.map((i) => i.name), ['Riso']);
      expect(draft.meal(1, 'pranzo').items.map((i) => i.name), ['Riso', 'Zucchine']);
    });

    test('othersDiffer: chiede conferma solo se un altro giorno è diverso', () {
      final draft = DietDraft()..addItem(0, 'cena', const FoodItemDraft(name: 'Salmone'));
      expect(draft.othersDiffer(0, 'cena'), isFalse);
      draft.addItem(3, 'cena', const FoodItemDraft(name: 'Pollo'));
      expect(draft.othersDiffer(0, 'cena'), isTrue);
    });

    test('copia giorno non tocca i pasti uguali tutti i giorni', () {
      final draft = DietDraft()
        ..addItem(0, 'pranzo', const FoodItemDraft(name: 'Pasta'))
        ..setEveryDay(0, 'pranzo', true)
        ..addItem(0, 'cena', const FoodItemDraft(name: 'Pollo'))
        ..copyDay(0, [4]);
      // Il pranzo resta condiviso: cambiarlo cambia ancora tutti i giorni.
      draft.addItem(4, 'pranzo', const FoodItemDraft(name: 'Parmigiano'));
      expect(draft.meal(6, 'pranzo').items.map((i) => i.name), ['Pasta', 'Parmigiano']);
      expect(draft.meal(4, 'cena').items.map((i) => i.name), ['Pollo']);
    });

    test('riaprendo la dieta, un pasto identico in 7 giorni ha la spunta accesa', () {
      final saved = (DietDraft()
            ..addItem(0, 'pranzo', const FoodItemDraft(name: 'Pasta', quantity: 80, unit: 'g'))
            ..setEveryDay(0, 'pranzo', true)
            ..addItem(0, 'cena', const FoodItemDraft(name: 'Pollo')))
          .toDiet(trainingWeekdays: {});
      final reopened = DietDraft.fromDiet(saved);
      expect(reopened.isEveryDay('pranzo'), isTrue);
      expect(reopened.isEveryDay('cena'), isFalse);
    });

    test('modificare la dieta completa non perde legumi, regole e intervalli', () {
      final original = DietRepository.parse(fixture('diet.json'));
      final diet = DietDraft.fromDiet(original).toDiet(trainingWeekdays: {1, 3, 5});

      expect(diet.validate(), isEmpty);
      expect(diet.legumes?.title, original.legumes?.title);
      // Gli id restano quelli di prima: il riquadro dei legumi li trova ancora.
      expect(diet.days.where((d) => d.usesFood('legumi')).map((d) => d.name), ['Martedì', 'Giovedì']);
      // La domenica "Pranzo e cena" con le sue regole.
      final sunday = diet.days.last.meals.single;
      expect(diet.slotFor(sunday).name, 'Pranzo e cena');
      expect(sunday.rules, original.days.last.meals.single.rules);
      final verdure = diet.days[1].meals[1].items.firstWhere((i) => i.foodId == 'verdure');
      expect(verdure.amountLabel, '250–300 g');
    });
  });

  test('toJson: la dieta completa fa andata e ritorno', () {
    final diet = DietRepository.parse(fixture('diet.json'));
    final again = Diet.fromJson(jsonDecode(jsonEncode(diet.toJson())) as Map<String, dynamic>);
    expect(again.toJson(), diet.toJson());
  });

  testWidgets('dalla tab Dieta vuota: Crea la dieta, scrivo un pranzo e salvo', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});
    final userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      userData: userData,
    ));
    await tester.pumpAndSettle();

    // Tab Dieta: vuota, col pulsante.
    await tester.tap(find.text('Dieta'));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna dieta'), findsOneWidget);
    await tester.tap(find.text('Crea la dieta'));
    await tester.pumpAndSettle();

    // L'editor si apre sul giorno di oggi, con pranzo e cena.
    expect(find.text('La tua dieta'), findsOneWidget);
    expect(find.text('Scrivi almeno un pasto'), findsOneWidget);

    // Pranzo (il primo "Aggiungi alimento"): pasta 90 g.
    await tester.tap(find.text('Aggiungi alimento').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Alimento'), 'Pasta');
    await tester.enterText(find.widgetWithText(TextField, 'Quantità'), '90');
    await tester.pump();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('90 g'), findsOneWidget);

    // Niente pulsante Salva: torno indietro e la dieta si salva da sola.
    expect(find.text('Scrivi almeno un pasto'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, () => find.text('La tua dieta').evaluate().isEmpty);
    expect(find.text('Dieta salvata'), findsOneWidget);

    // Salvata: si resta sulla tab Dieta, che ora la mostra (si legge da file, tempo vero).
    expect(userData.hasDiet, isTrue);
    await pumpUntil(tester, () => find.text('Pasta').evaluate().isNotEmpty);
    expect(find.text('Nessuna dieta'), findsNothing);
  });
}
