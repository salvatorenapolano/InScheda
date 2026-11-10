import 'package:flutter_test/flutter_test.dart';

import 'helpers/fixtures.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/models/diet.dart';

void main() {
  final json = fixture('diet.json');
  final diet = DietRepository.parse(json);

  test('7 giorni, palestra lunedì mercoledì venerdì', () {
    expect(diet.days.map((d) => d.shortName), ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']);
    expect(diet.days.where((d) => d.training).map((d) => d.name), ['Lunedì', 'Mercoledì', 'Venerdì']);
  });

  test('pasti e quantità come nel PDF', () {
    final monday = diet.days.first;
    expect(monday.meals.map((m) => m.title), ['Pasta al pomodoro e tonno', 'Pollo e patate']);
    final dinner = monday.meals[1];
    // Lunedì le verdure sono solo l'alternativa, se mancano le patate.
    expect(dinner.items.any((i) => i.foodId == 'verdure'), isFalse);
    expect(dinner.alternative, 'Se mancano le patate: 250–300 g di verdure.');
    // Martedì a cena invece ci sono, con l'intervallo 250–300 g.
    final tuesdayDinner = diet.days[1].meals[1];
    final verdure = tuesdayDinner.items.firstWhere((i) => i.foodId == 'verdure');
    expect(verdure.amountLabel, '250–300 g');
    // Mercoledì a cena niente insalata.
    expect(diet.days[2].meals[1].items.any((i) => i.foodId == 'insalata'), isFalse);
    final passata = monday.meals[0].items.firstWhere((i) => i.foodId == 'passata');
    expect(passata.amountLabel, isNull);
    expect(diet.slotFor(dinner).label, 'Cena · 20:00');
    expect(diet.slotFor(dinner).emoji, '🌙');
    expect(diet.slotFor(monday.meals[0]).emoji, '☀️');
  });

  test('i legumi compaiono solo martedì e giovedì', () {
    expect(diet.days.where((d) => d.usesFood('legumi')).map((d) => d.name), ['Martedì', 'Giovedì']);
  });

  test('un alimento sconosciuto dà un errore chiaro', () {
    final broken = json.replaceFirst('"foodId": "pasta"', '"foodId": "pastaa"');
    expect(() => DietRepository.parse(broken), throwsA(isA<FormatException>()));
  });

  test('quantità senza decimali inutili', () {
    expect(const MealItem(foodId: 'x', quantity: 90, unit: 'g').amountLabel, '90 g');
    expect(const MealItem(foodId: 'x', quantity: 1.5, unit: 'kg').amountLabel, '1,5 kg');
  });
}
