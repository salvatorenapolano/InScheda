import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/models/body_weight.dart';

void main() {
  // Novembre 2026: venerdì 6 e venerdì 13.
  final thursday = DateTime(2026, 11, 5);
  final friday = DateTime(2026, 11, 6, 8, 30);
  final monday = DateTime(2026, 11, 9);
  final nextFriday = DateTime(2026, 11, 13);

  BodyWeightEntry entry(DateTime date, double kg) => BodyWeightEntry(date: date, kg: kg);

  group('stato della pesata', () {
    test('venerdì senza pesata: oggi ti devi pesare', () {
      expect(weighInStatusFor([], friday), isA<WeighInDueToday>());
      expect(weighInStatusFor([entry(DateTime(2026, 10, 30), 79)], friday), isA<WeighInDueToday>());
    });

    test('venerdì con la pesata di oggi: fatta, col peso', () {
      final status = weighInStatusFor([entry(DateTime(2026, 11, 6), 78.4)], friday);
      expect(status, isA<WeighInDoneToday>().having((s) => s.kg, 'kg', 78.4));
    });

    test('lunedì dopo un venerdì saltato: pesata da fare', () {
      expect(weighInStatusFor([entry(DateTime(2026, 10, 30), 79)], monday), isA<WeighInMissed>());
    });

    test('lunedì dopo la pesata di venerdì: prossima venerdì 13', () {
      final status = weighInStatusFor([entry(DateTime(2026, 11, 6), 78.4)], monday);
      expect(status, isA<WeighInUpcoming>().having((s) => s.date, 'date', nextFriday));
    });

    test('col giorno della pesata di lunedì cambia tutto il calendario', () {
      // Lunedì 2 novembre: pesata fatta. Venerdì 6: prossima lunedì 9.
      final done = [entry(DateTime(2026, 11, 2), 78)];
      expect(
        weighInStatusFor(done, friday, weekday: DateTime.monday),
        isA<WeighInUpcoming>().having((s) => s.date, 'date', DateTime(2026, 11, 9)),
      );
      // Lunedì 9 senza pesata: oggi ti devi pesare.
      expect(weighInStatusFor(done, DateTime(2026, 11, 9), weekday: DateTime.monday), isA<WeighInDueToday>());
      // Martedì 10, lunedì saltato: pesata da fare.
      expect(weighInStatusFor(done, DateTime(2026, 11, 10), weekday: DateTime.monday), isA<WeighInMissed>());
    });

    test('nessuna pesata e non è venerdì: si parte dal prossimo venerdì', () {
      final status = weighInStatusFor([], thursday);
      expect(status, isA<WeighInUpcoming>().having((s) => s.date, 'date', DateTime(2026, 11, 6)));
    });
  });

  test('lo store salva, sostituisce lo stesso giorno, ordina e ricorda', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await BodyWeightStore.load();

    await store.save(DateTime(2026, 10, 30), 79);
    await store.save(DateTime(2026, 11, 6, 9), 78.6);
    await store.save(DateTime(2026, 11, 6, 18), 78.4); // stesso giorno: sostituisce
    expect(store.entries.map((e) => e.kg), [78.4, 79]); // dalla più recente

    await store.remove(DateTime(2026, 10, 30));
    expect(store.entries, hasLength(1));

    // Riaprendo lo store (come al riavvio dell'app) la pesata c'è ancora.
    final reopened = await BodyWeightStore.load();
    expect(reopened.entries.single.date, DateTime(2026, 11, 6));
    expect(reopened.entries.single.kg, 78.4);
  });
}
