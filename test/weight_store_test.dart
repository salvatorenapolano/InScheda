import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/data/weight_store.dart';

void main() {
  test('salva, avvisa e cancella i pesi', () async {
    // Nei test non c'è un telefono: shared_preferences usa una memoria finta.
    SharedPreferences.setMockInitialValues({});
    final store = await WeightStore.load();

    var notifications = 0;
    store.addListener(() => notifications++);

    expect(store.weightFor('leg_press'), isNull);

    await store.setWeight('leg_press', 80);
    expect(store.weightFor('leg_press'), 80);

    await store.setWeight('leg_press', 0); // 0 = cancella
    expect(store.weightFor('leg_press'), isNull);

    expect(notifications, 2);
  });
}
