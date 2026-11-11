import 'package:flutter/material.dart';

import 'package:my_workout/features/diet/diet_page.dart';
import 'package:my_workout/features/shopping/shopping_page.dart';
import 'package:my_workout/features/weigh_in/weigh_in_page.dart';
import 'package:my_workout/features/workout/workout_page.dart';

/// Il "guscio" dell'app: la barra in basso con le 4 tab
/// e l'area sopra che mostra la pagina selezionata.
///
/// È uno StatefulWidget perché deve ricordarsi un dato che cambia:
/// quale tab è selezionata.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Lo "stato": l'indice della tab attiva (0 = Allenamento).
  // Il trattino basso iniziale lo rende privato a questo file.
  //
  // Quando salvi scheda, dieta o spesa l'app ricrea questo widget (Key
  // nuova) e lo stato ripartirebbe da 0: finiresti su Allenamento. Per
  // questo la tab scelta si "appunta" anche nel PageStorage della pagina,
  // che resta lo stesso, e da lì si rilegge.
  static const _storageId = 'home_tab';
  late int _selectedIndex = PageStorage.maybeOf(context)?.readState(context, identifier: _storageId) as int? ?? 0;

  static const _pages = <Widget>[
    WorkoutPage(),
    DietPage(),
    WeighInPage(),
    ShoppingPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack tiene in vita tutte e 4 le pagine e ne mostra una:
      // cambiando tab non perdi lo scroll o quello che stavi facendo.
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        // setState() aggiorna lo stato e dice a Flutter di rieseguire build().
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          PageStorage.maybeOf(context)?.writeState(context, index, identifier: _storageId);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Allenamento',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Dieta',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: 'Pesata',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Spesa',
          ),
        ],
      ),
    );
  }
}
