import 'package:flutter_test/flutter_test.dart';

/// Aspetta che [done] diventi vero quando l'app legge o scrive file veri.
///
/// Nei widget test il tempo è "finto": l'I/O sul disco però è vero e non
/// avanza da solo. runAsync concede un po' di tempo vero, pump() fa
/// proseguire il codice che aspettava quel file. Si alternano finché
/// [done] è vero (o passa [timeout] di tempo VERO), poi pumpAndSettle.
///
/// Il limite è in tempo reale e non in numero di tentativi: quando tutti
/// i test girano insieme il computer è più lento, e 100 giri da 10 ms
/// a volte non bastavano (il test falliva "a caso").
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final clock = Stopwatch()..start();
  while (!done() && clock.elapsed < timeout) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    // Con una durata, pump() fa avanzare anche il tempo finto: servono
    // alle animazioni (es. una pagina che si chiude) per arrivare in fondo.
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'La condizione non si è avverata in ${timeout.inSeconds} secondi');
  await tester.pumpAndSettle();
}
