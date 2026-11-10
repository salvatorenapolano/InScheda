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

/// Gli esercizi di una scheda: si aggiungono dalla libreria, si toccano per
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
    if (chosen != null) draft.addExercises(workout, chosen, library);
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
                      'Tocca un esercizio per cambiare serie, tempi o velocità; tienilo premuto per spostarlo.',
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
                      child: ListTile(
                        leading: exercise == null
                            ? const Icon(Icons.help_outline)
                            : ExercisePreview(exercise: exercise, size: 44),
                        title: Text(exercise?.name ?? 'Esercizio non più in libreria'),
                        subtitle: Text(formatPlanned(planned)),
                        onTap: () => _edit(context, index),
                        trailing: IconButton(
                          tooltip: 'Togli ${exercise?.name ?? 'l\'esercizio'}',
                          onPressed: () => draft.removeExercise(workout, index),
                          icon: const Icon(Icons.delete_outline),
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
