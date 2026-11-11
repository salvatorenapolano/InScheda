import 'package:flutter/material.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/features/diet_editor/diet_editor_page.dart';
import 'package:my_workout/features/diet/widgets/diet_day_view.dart';
import 'package:my_workout/models/diet.dart';
import 'package:my_workout/widgets/empty_state.dart';
import 'package:my_workout/widgets/main_app_bar.dart';
import 'package:my_workout/widgets/page_title.dart';

/// Tab "Dieta": la settimana tipo, un giorno per scheda (Lun … Dom).
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  // Il bundle dei dati: prima quelli dell'utente, poi quelli dell'app.
  // Diet? perché l'utente può non avere ancora una dieta.
  late final Future<Diet?> _dietFuture = DietRepository(bundle: DefaultAssetBundle.of(context)).load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Diet?>(
      future: _dietFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _simplePage(Text('Non riesco a leggere la dieta:\n${snapshot.error}'));
        }
        // hasData è false anche quando il risultato è null: per sapere se
        // il caricamento è finito guardiamo connectionState.
        if (snapshot.connectionState != ConnectionState.done) {
          return _simplePage(const CircularProgressIndicator());
        }
        final diet = snapshot.data;
        if (diet == null) {
          return _simplePage(EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Nessuna dieta',
            message: 'Qui vedrai la settimana dei pasti, giorno per giorno.',
            actionLabel: 'Crea la dieta',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DietEditorPage()),
            ),
          ));
        }
        return _buildWeek(diet);
      },
    );
  }

  Widget _simplePage(Widget child) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
    );
  }

  Widget _buildWeek(Diet diet) {
    // weekday: 1 = lunedì ... 7 = domenica. Le liste partono da 0.
    // clamp evita errori se un giorno la dieta avesse meno di 7 giorni.
    final today = (DateTime.now().weekday - 1).clamp(0, diet.days.length - 1);

    // DefaultTabController collega la TabBar (le schede in alto) e la
    // TabBarView (le pagine sotto): tocchi una scheda o scorri col dito,
    // e le due restano sincronizzate da sole.
    return DefaultTabController(
      length: diet.days.length,
      initialIndex: today,
      child: Scaffold(
        appBar: MainAppBar(
          // Sotto il logo: il titolo "Dieta" con la matita e, sotto ancora,
          // la fila dei giorni. PreferredSize perché l'AppBar vuole sapere
          // quanto è alto quello che le mettiamo sotto.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56 + kTextTabBarHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: PageTitle(
                    title: 'Dieta',
                    editTooltip: 'Modifica la dieta',
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DietEditorPage()),
                    ),
                  ),
                ),
                TabBar(
                  tabs: [for (final day in diet.days) Tab(text: day.shortName)],
                  labelPadding: EdgeInsets.zero,
                  // padding: spazio attorno a tutta la fila di schede.
                  // indicatorPadding: rimpicciolisce la "pillola" del giorno scelto
                  // rispetto alla sua scheda, così non tocca le vicine.
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [for (final day in diet.days) DietDayView(diet: diet, day: day)],
        ),
      ),
    );
  }
}
