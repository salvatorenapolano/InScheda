import 'package:flutter/material.dart';

import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/workout/widgets/exercise_block_tile.dart';
import 'package:my_workout/features/workout/widgets/planned_exercise_tile.dart';
import 'package:my_workout/features/workout/widgets/step_number.dart';
import 'package:my_workout/features/workout/widgets/today_banner.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/widgets/dividers.dart';
import 'package:my_workout/widgets/empty_state.dart';
import 'package:my_workout/widgets/main_app_bar.dart';

/// Tab "Allenamento": cosa tocca oggi, scelta del giorno (Push/Pull/Legs)
/// e i blocchi della seduta.
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  // Il caricamento parte UNA volta, quando la pagina nasce.
  // Se lo scrivessimo dentro build() ripartirebbe a ogni ridisegno!
  // `late` = "inizializzalo la prima volta che lo uso" (cioè nel primo build,
  // dove `context` c'è già). DefaultAssetBundle.of(context) è il bundle dei
  // dati: legge prima quelli dell'utente, poi quelli dell'app.
  late final Future<WorkoutData> _dataFuture =
      WorkoutRepository(bundle: DefaultAssetBundle.of(context)).load();

  // Il giorno scelto col selettore Push/Pull/Legs.
  // null = mostra quella del prossimo allenamento.
  String? _selectedWorkoutId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // L'header comune a tutte le tab: "myWorkout" e il cerchio del profilo.
      appBar: const MainAppBar(),
      // FutureBuilder ridisegna la pagina quando il Future cambia stato:
      // in attesa → completato con i dati, oppure → errore.
      body: FutureBuilder<WorkoutData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Non riesco a leggere la scheda:\n${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.requireData;
          // La libreria c'è sempre, la scheda no (primo avvio).
          final plan = data.plan;
          if (plan == null) {
            return const EmptyState(
              icon: Icons.fitness_center,
              title: 'Nessuna scheda',
              message: 'Qui vedrai i tuoi allenamenti, giorno per giorno, con gli esercizi e i pesi che usi.',
            );
          }
          return _buildContent(data, plan);
        },
      ),
    );
  }

  Widget _buildContent(WorkoutData data, WorkoutPlan plan) {
    final now = DateTime.now();
    // La seduta di oggi (o la prossima, se oggi è riposo): all'apertura
    // il selettore parte proprio su quella scheda.
    final next = plan.nextSessionFrom(now);

    // L'operatore ?? sceglie il primo valore non null, da sinistra a destra.
    final workout = plan.workoutById(
      _selectedWorkoutId ?? next?.workoutId ?? plan.workouts.first.id,
    );

    // Riscaldamento, addominali e cardio sono facoltativi: i numeri delle
    // parti (1, 2, 3...) si contano mentre le aggiungiamo, così restano
    // in fila anche quando una parte manca.
    final warmup = workout.warmup;
    final abs = plan.abs;
    final cardio = plan.cardio;
    var step = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        TodayBanner(plan: plan, now: now),
        const SizedBox(height: 16),

        SegmentedButton<String>(
          // Niente spunta sul segmento scelto: al suo posto mostriamo
          // l'icona del calendario sulla scheda di turno.
          showSelectedIcon: false,
          // expandedInsets: il selettore si allarga a tutta la larghezza
          // disponibile (qui con zero margini extra).
          expandedInsets: EdgeInsets.zero,
          segments: [
            for (final w in plan.workouts)
              ButtonSegment(
                value: w.id,
                label: Text(w.name),
                icon: w.id == next?.workoutId ? const Icon(Icons.today) : null,
              ),
          ],
          selected: {workout.id},
          onSelectionChanged: (selection) {
            setState(() => _selectedWorkoutId = selection.first);
          },
        ),
        const SizedBox(height: 24),

        // Riscaldamento: ogni giorno ha la sua mobilità.
        // `++step` aumenta il contatore e ne usa il nuovo valore.
        if (warmup != null) ...[
          ExerciseBlockTile(number: ++step, block: warmup, data: data),
          const SizedBox(height: 24),
        ],

        // Pesi: sempre visibile, è la parte principale.
        // Il titolo sta fuori dalla card, le righe dentro.
        _SectionTitle(number: ++step, text: 'Pesi · ${workout.name}'),
        if (workout.intro case final intro?)
          // `case final intro?`: se intro non è null lo "estrae" in una
          // variabile già di tipo String. Se è null, la riga non c'è.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              intro,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            // withDividers mette una linea sottile tra una riga e l'altra.
            children: withDividers(indent: 80, [
              // .indexed dà coppie (posizione, esercizio): la posizione parte da 0.
              for (final (index, planned) in workout.exercises.indexed)
                PlannedExerciseTile(
                  number: index + 1,
                  planned: planned,
                  exercise: data.exerciseFor(planned),
                  sectionTitle: workout.name,
                ),
            ]),
          ),
        ),

        // Addominali
        if (abs != null) ...[
          const SizedBox(height: 24),
          ExerciseBlockTile(number: ++step, block: abs, data: data),
        ],

        // Cardio: ⏱️ 30 min  ⛰️ 10%  💨 5,5 km/h
        if (cardio != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: StepNumber(++step),
              title: Text(cardio.title, style: Theme.of(context).textTheme.titleLarge),
              // Wrap: i tre dati stanno su una riga e vanno a capo
              // da soli se lo schermo è stretto.
              subtitle: Wrap(
                spacing: 16,
                children: [
                  Text('⏱️ ${cardio.durationMinutes} min'),
                  Text('⛰️ ${formatNumber(cardio.inclinePercent)}%'),
                  Text('💨 ${formatNumber(cardio.speedKmh)} km/h'),
                ],
              ),
              trailing: const Icon(Icons.directions_walk),
            ),
          ),
        ],
      ],
    );
  }
}

/// Titolo di sezione col numero della parte di seduta, allineato
/// ai numeri che stanno dentro le card (stesso rientro del ListTile).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          StepNumber(number),
          const SizedBox(width: 16),
          Text(text, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
