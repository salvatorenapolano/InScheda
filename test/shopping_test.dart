import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/shopping_store.dart';

void main() {
  final json = File('assets/data/shopping.json').readAsStringSync();

  test('due liste, con sezioni e prodotti come nel PDF', () {
    final lists = ShoppingRepository.parse(json);
    expect(lists.map((l) => l.name), ['Settimanale', 'Mensile']);

    final weekly = lists[0];
    expect(weekly.sections.map((s) => s.items.length), [7, 2, 5, 8]);
    expect(weekly.items.firstWhere((i) => i.id == 'zucca').quantity, '1 spicchio (~400 g)');

    final monthly = lists[1];
    expect(monthly.sections.map((s) => s.name), ['Dispensa', 'Surgelati', 'Varie']);
    expect(monthly.sections.map((s) => s.items.length), [14, 4, 2]);
    expect(monthly.items.firstWhere((i) => i.id == 'tonno').quantity, '16 scatolette da 80 g');
    // Spezie e tisane non hanno una quantità.
    expect(monthly.items.firstWhere((i) => i.id == 'spezie').quantity, isNull);
  });

  test('un id ripetuto dà un errore chiaro', () {
    final broken = json.replaceFirst('"id": "pere"', '"id": "mele"');
    expect(() => ShoppingRepository.parse(broken), throwsA(isA<FormatException>()));
  });

  test('le spunte si salvano, si azzerano e si ripristinano', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ShoppingStore.load();

    await store.setChecked('uova', true);
    await store.setChecked('whey', true);
    // Reset della sola settimanale: la whey (mensile) resta spuntata.
    final removed = await store.uncheckAll(['uova', 'latte']);
    expect(removed, {'uova'});
    expect(store.isChecked('uova'), isFalse);
    expect(store.isChecked('whey'), isTrue);

    await store.checkAll(removed); // Annulla
    final reopened = await ShoppingStore.load(); // come al riavvio dell'app
    expect(reopened.isChecked('uova'), isTrue);
    expect(reopened.isChecked('whey'), isTrue);
  });
}
