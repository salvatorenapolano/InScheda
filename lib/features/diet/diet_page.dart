import 'package:flutter/material.dart';

import 'package:my_workout/data/diet_repository.dart';
import 'package:my_workout/features/diet/widgets/diet_day_view.dart';
import 'package:my_workout/models/diet.dart';
import 'package:my_workout/widgets/main_app_bar.dart';

/// Tab "Dieta": la settimana tipo, un giorno per scheda (Lun … Dom).
class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  // Il bundle dei dati: prima quelli scaricati da GitHub, poi quelli dell'app.
  late final Future<Diet> _dietFuture = DietRepository(bundle: DefaultAssetBundle.of(context)).load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Diet>(
      future: _dietFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _simplePage(Text('Non riesco a leggere la dieta:\n${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return _simplePage(const CircularProgressIndicator());
        }
        return _buildWeek(snapshot.requireData);
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
          bottom: TabBar(
            tabs: [for (final day in diet.days) Tab(text: day.shortName)],
            labelPadding: EdgeInsets.zero,
            // padding: spazio attorno a tutta la fila di schede.
            // indicatorPadding: rimpicciolisce la "pillola" del giorno scelto
            // rispetto alla sua scheda, così non tocca le vicine.
            padding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          ),
        ),
        body: TabBarView(
          children: [for (final day in diet.days) DietDayView(diet: diet, day: day)],
        ),
      ),
    );
  }
}
