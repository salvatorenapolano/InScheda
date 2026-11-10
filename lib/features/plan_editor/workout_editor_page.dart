import 'package:flutter/material.dart';

import 'package:my_workout/features/plan_editor/exercise_picker_page.dart';
import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/planned_exercise_dialog.dart';
import 'package:my_workout/features/plan_editor/workouts_editor.dart';
import 'package:my_workout/features/workout/widgets/exercise_preview.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/empty_state.dart';

/// Gli esercizi di una scheda: si aggiungono dalla libreria (chiedendo subito
/// serie e ripetizioni), si modificano con la matita (o toccandoli) per
/// cambiare serie/ripetizioni/recupero, si trascinano per cambiare ordine.
class WorkoutEditorPage extends StatelessWidget {
  const WorkoutEditorPage({super.key, required this.draft, required this.workout, required this.library});

  final PlanDraft draft;
  final WorkoutDraft workout;
  final Map<String, Exercise> library;

  Future<void> _addExercises(BuildContext context) async {
    // push restituisce un Future: si completa con il valore che la pagina
    // passa a Navigator.pop (qui la lista degli id scelti).
    final chosen = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => ExercisePickerPage(
          library: library,
          alreadyChosen: {for (final p in workout.exercises) p.exerciseId},
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;

    // Per ogni esercizio scelto chiediamo subito serie e ripetizioni (o
    // tempo, o minuti e velocità per il cardio), partendo dai valori di
    // default. Solo con "Aggiungi" finisce nella scheda; con "Annulla"
    // quell'esercizio si salta e si passa al successivo.
    for (final (index, id) in chosen.indexed) {
      final planned = await showDialog<PlannedExercise>(
        context: context,
        builder: (context) => PlannedExerciseDialog(
          planned: PlanDraft.defaultsFor(id, library[id]),
          exercise: library[id],
          confirmLabel: 'Aggiungi',
          progress: chosen.length > 1 ? 'Esercizio ${index + 1} di ${chosen.length}' : null,
        ),
      );
      if (planned != null) draft.addPlanned(workout, planned);
      // Dopo un await la pagina potrebbe non esserci più.
      if (!context.mounted) return;
    }
  }

  Future<void> _edit(BuildContext context, int index) async {
    final planned = workout.exercises[index];
    final updated = await showDialog<PlannedExercise>(
      context: context,
      builder: (context) => PlannedExerciseDialog(
        planned: planned,
        exercise: library[planned.exerciseId],
      ),
    );
    if (updated != null) draft.updateExercise(workout, index, updated);
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => WorkoutNameDialog(initialName: workout.name),
    );
    if (name != null && name.trim().isNotEmpty) draft.renameWorkout(workout, name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final exercises = workout.exercises;
        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [
              IconButton(
                tooltip: 'Rinomina la scheda',
                onPressed: () => _rename(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addExercises(context),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi esercizi'),
          ),
          body: exercises.isEmpty
              ? const EmptyState(
                  icon: Icons.playlist_add,
                  title: 'Nessun esercizio',
                  message: 'Tocca "Aggiungi esercizi" e scegli dalla libreria, divisa per gruppo muscolare.',
                )
              // ReorderableListView: una lista in cui le righe si spostano
              // tenendole premute e trascinandole. Ogni riga deve avere una
              // Key, così Flutter sa quale riga è quale mentre si spostano.
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  header: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Con la matita cambi serie, tempi o velocità; tieni premuto un esercizio per spostarlo.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  itemCount: exercises.length,
                  // onReorderItem dà già la posizione finale giusta, anche
                  // quando si trascina una riga verso il basso.
                  onReorderItem: (from, to) => draft.moveExercise(workout, from, to),
                  itemBuilder: (context, index) {
                    final planned = exercises[index];
                    final exercise = library[planned.exerciseId];
                    return Card(
                      key: ValueKey(planned.exerciseId),
                      // Le card del tema non hanno margine: qui lasciamo un
                      // po' d'aria fra un esercizio e l'altro (e spazio per
                      // il cerchietto col numero, che sborda in alto).
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: exercise == null
                            ? const Icon(Icons.help_outline)
                            // Il numero d'ordine, come nella tab Allenamento:
                            // si aggiorna da solo quando sposti un esercizio.
                            : ExercisePreview(exercise: exercise, size: 44, number: index + 1),
                        title: Text(exercise?.name ?? 'Esercizio non più in libreria'),
                        subtitle: Text(formatPlanned(planned)),
                        onTap: () => _edit(context, index),
                        // Due pulsanti espliciti: la matita per modificare
                        // (toccare la riga fa lo stesso) e il cestino.
                        // mainAxisSize.min: la Row occupa solo lo spazio delle icone.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Modifica ${exercise?.name ?? 'l\'esercizio'}',
                              onPressed: () => _edit(context, index),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Togli ${exercise?.name ?? 'l\'esercizio'}',
                              onPressed: () => draft.removeExercise(workout, index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
