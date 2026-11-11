import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_workout/widgets/save_on_exit.dart';

void main() {
  // Una "bozza" finta: un numero che cambia. 0 = non si può salvare.
  late ValueNotifier<int> draft;
  late List<int> saved;

  /// Apre un editor finto sopra una pagina "Home".
  Future<void> openEditor(WidgetTester tester) async {
    draft = ValueNotifier(1);
    saved = [];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SaveOnExit(
                draft: draft,
                problem: () => draft.value == 0 ? 'Serve almeno un numero' : null,
                onSave: () async => saved.add(draft.value),
                savedMessage: 'Salvato',
                child: Scaffold(appBar: AppBar(title: const Text('Editor'))),
              ),
            )),
            child: const Text('Home'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);
  }

  testWidgets('senza modifiche si esce e non si salva niente', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
    expect(saved, isEmpty);
    expect(find.text('Salvato'), findsNothing);
  });

  testWidgets('con una modifica, tornando indietro salva e lo dice', (tester) async {
    await openEditor(tester);
    draft.value = 5;
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
    expect(saved, [5]);
    expect(find.text('Salvato'), findsOneWidget);
  });

  testWidgets('se non si può salvare chiede: resto, oppure esco senza salvare', (tester) async {
    await openEditor(tester);
    draft.value = 0;

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Non posso salvare'), findsOneWidget);
    expect(find.textContaining('Serve almeno un numero'), findsOneWidget);

    // "Continua a modificare": resto nell'editor.
    await tester.tap(find.text('Continua a modificare'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsOneWidget);

    // Di nuovo indietro, "Esci senza salvare": esco e non si scrive niente.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esci senza salvare'));
    await tester.pumpAndSettle();
    expect(find.text('Editor'), findsNothing);
    expect(saved, isEmpty);
  });
}
