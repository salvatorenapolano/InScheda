import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_workout/app.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/focus_alerts.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_repository.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/shopping_editor/shopping_draft.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/models/shopping.dart';

import 'helpers/fixtures.dart';
import 'helpers/real_io.dart';

void main() {
  final json = fixture('shopping.json');

  test('due liste, con sezioni e prodotti come nel PDF', () {
    final lists = ShoppingRepository.parse(json).lists;
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

  test('colori: "#RRGGBB" avanti e indietro', () {
    expect(parseHexColor('#34A853'), 0xFF34A853);
    expect(parseHexColor('00a0ff'), 0xFF00A0FF);
    expect(parseHexColor('rosso'), isNull);
    expect(formatHexColor(0xFF00A0FF), '#00A0FF');
  });

  test('il reparto di una sezione: per id, per nome, oppure nessuno', () {
    final data = ShoppingData.fromJson({
      'departments': [
        {'id': 'reparto_animali', 'name': 'Animali', 'color': '#D45D9C', 'icon': 'pets'},
      ],
      'lists': <Object>[],
    });
    ShoppingDepartment? of(Map<String, dynamic> section) =>
        data.departmentFor(ShoppingSection.fromJson({...section, 'items': <Object>[]}));

    expect(of({'name': 'Qualsiasi', 'department': 'frigo'})?.name, 'Frigo');
    expect(of({'name': 'Cibo gatto', 'department': 'reparto_animali'})?.icon, 'pets');
    // Senza `department`: si cerca per nome, maiuscole a parte.
    expect(of({'name': 'surgelati'})?.id, 'surgelati');
    expect(of({'name': 'Pane e patate'}), isNull);
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

    // Dopo aver salvato una lista senza la whey, la sua spunta sparisce.
    await reopened.retainOnly({'uova', 'latte'});
    expect(reopened.isChecked('whey'), isFalse);
    expect(reopened.isChecked('uova'), isTrue);
  });

  group('ShoppingDraft', () {
    test('una spesa nuova: liste, reparti, prodotti e id dal nome', () {
      final draft = ShoppingDraft();
      expect(draft.lists.single.name, 'Settimanale');
      expect(draft.hasContent, isFalse);

      draft.addItem(0, 'frigo', const ShoppingItemDraft(name: 'Latte', quantity: '2 L'));
      draft.addItem(0, 'frutta_verdura', const ShoppingItemDraft(name: 'Mele', note: 'quelle rosse'));
      final monthly = draft.addList('Mensile');
      draft.addItem(monthly, 'frigo', const ShoppingItemDraft(name: 'Latte'));
      final animals = draft.addDepartment(name: 'Animali', color: 0xFFD45D9C, icon: 'pets');
      draft.addItem(monthly, animals.id, const ShoppingItemDraft(name: 'Croccantini'));
      expect(draft.hasContent, isTrue);

      final data = draft.toData();
      expect(data.lists.map((l) => l.name), ['Settimanale', 'Mensile']);
      expect(data.lists[0].sections.map((s) => s.name), ['Frigo', 'Frutta e verdura']);
      expect(data.lists[0].sections.first.departmentId, 'frigo');
      // Due "Latte" in liste diverse: id diversi, se no si spunterebbero insieme.
      expect([for (final l in data.lists) ...l.items.map((i) => i.id)], ['latte', 'mele', 'latte_2', 'croccantini']);
      expect(data.departments.single.id, 'reparto_animali');
      expect(data.lists[0].items.last.note, 'quelle rosse');
    });

    test('cambiare reparto sposta il prodotto; i reparti vuoti non si salvano', () {
      final draft = ShoppingDraft()
        ..addItem(0, 'altro', const ShoppingItemDraft(name: 'Piselli'))
        ..addItem(0, 'frigo', const ShoppingItemDraft(name: 'Burro'));
      draft.updateItem(0, 'altro', 0, 'surgelati', const ShoppingItemDraft(name: 'Piselli surgelati'));
      expect(draft.lists[0].sections.map((s) => s.departmentId), ['frigo', 'surgelati']);

      draft.moveSection(0, 'surgelati', -1);
      expect(draft.lists[0].sections.map((s) => s.departmentId), ['surgelati', 'frigo']);

      draft.removeItem(0, 'frigo', 0);
      expect(draft.toData().lists[0].sections.map((s) => s.name), ['Surgelati']);
    });

    test('l\'ultima lista non si può togliere', () {
      final draft = ShoppingDraft()..removeList(0);
      expect(draft.lists, hasLength(1));
    });

    test('modificare la lista scritta a mano non perde niente', () {
      final original = ShoppingRepository.parse(json);
      final draft = ShoppingDraft.fromData(original);
      final data = draft.toData();

      // Stessi prodotti, con gli stessi id (le spunte restano).
      List<String> ids(ShoppingData d) => [for (final l in d.lists) ...l.items.map((i) => i.id)];
      expect(ids(data), ids(original));
      // "Dispensa" e "Surgelati" sono reparti dell'app; gli altri diventano reparti tuoi.
      expect(data.lists[1].sections.map((s) => s.departmentId), ['dispensa', 'surgelati', 'reparto_varie']);
      expect(data.departments.map((d) => d.name), ['Proteine e latticini', 'Pane e patate', 'Frutta', 'Verdure · circa 3 kg', 'Varie']);

      // E il JSON salvato si rilegge uguale.
      final again = ShoppingRepository.parse(jsonEncode(data.toJson()));
      expect(again.toJson(), data.toJson());
    });
  });

  testWidgets('dalla tab Spesa vuota: Crea la lista, aggiungo due prodotti e salvo', (tester) async {
    ExerciseMedia.videoEnabled = false;
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'profile_name': 'Mario Rossi'});
    final userData = UserDataStore(root: Directory.systemTemp.createTempSync('my_workout_utente'));

    await tester.pumpWidget(MyWorkoutApp(
      weights: await WeightStore.load(),
      bodyWeights: await BodyWeightStore.load(),
      shopping: await ShoppingStore.load(),
      profile: await ProfileStore.load(),
      focus: await FocusStore.load(alerts: SilentFocusAlerts()),
      userData: userData,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna lista della spesa'), findsOneWidget);
    await tester.tap(find.text('Crea la lista'));
    await tester.pumpAndSettle();

    expect(find.text('La tua spesa'), findsOneWidget);
    expect(find.text('Aggiungi almeno un prodotto'), findsOneWidget);

    // "Prodotto": parte da Frutta e verdura. Aggiungo e continuo.
    await tester.tap(find.text('Prodotto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Prodotto'), 'Mele');
    await tester.enterText(find.widgetWithText(TextField, 'Quantità (facoltativa)'), '5');
    await tester.pump();
    await tester.tap(find.text('Aggiungi e continua'));
    await tester.pumpAndSettle();
    expect(find.text('Aggiunto: Mele'), findsOneWidget);

    // Il secondo: banane, poi chiudo con "Aggiungi".
    await tester.enterText(find.widgetWithText(TextField, 'Prodotto'), 'Banane');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Aggiungi'));
    await tester.pumpAndSettle();

    expect(find.text('Frutta e verdura'), findsOneWidget);
    expect(find.text('Mele'), findsOneWidget);
    expect(find.text('Banane'), findsOneWidget);

    // Torno indietro: la spesa si salva da sola.
    expect(find.text('Aggiungi almeno un prodotto'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await pumpUntil(tester, () => find.text('La tua spesa').evaluate().isEmpty);
    expect(find.text('Spesa salvata'), findsOneWidget);
    expect(userData.hasShopping, isTrue);

    // La tab Spesa ora la mostra (si legge da file, tempo vero).
    await pumpUntil(tester, () => find.text('Banane').evaluate().isNotEmpty);
    expect(find.text('0/2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // la quantità, a destra

    // Tocco l'intestazione del reparto: si chiude e i prodotti spariscono.
    await tester.tap(find.text('Frutta e verdura'));
    await tester.pumpAndSettle();
    expect(find.text('Banane'), findsNothing);
  });
}
