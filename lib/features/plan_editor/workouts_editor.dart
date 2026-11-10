import 'package:flutter/material.dart';

import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/features/plan_editor/workout_editor_page.dart';
import 'package:my_workout/models/exercise.dart';

/// L'elenco delle schede (A, B, C… o i nomi che preferisci): per ognuna
/// quanti esercizi ha, il menu per rinominarla o toglierla e, toccandola,
/// la pagina dei suoi esercizi.
class WorkoutsEditor extends StatelessWidget {
  const WorkoutsEditor({super.key, required this.draft, required this.library});

  final PlanDraft draft;

  /// La libreria degli esercizi, per id: serve alla pagina degli esercizi.
  final Map<String, Exercise> library;

  void _openWorkout(BuildContext context, WorkoutDraft workout) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => WorkoutEditorPage(draft: draft, workout: workout, library: library),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WorkoutDraft workout) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => WorkoutNameDialog(initialName: workout.name),
    );
    if (name != null && name.trim().isNotEmpty) draft.renameWorkout(workout, name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final workouts = draft.workouts;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final workout in workouts)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    // characters.first: la prima lettera, anche se è un'emoji.
                    child: Text(workout.name.isEmpty ? '?' : workout.name.characters.first.toUpperCase()),
                  ),
                  title: Text(workout.name.isEmpty ? 'Senza nome' : workout.name),
                  subtitle: Text(
                    switch (workout.exercises.length) {
                      0 => 'Nessun esercizio: tocca per aggiungerli',
                      1 => '1 esercizio',
                      final n => '$n esercizi',
                    },
                    style: workout.exercises.isEmpty ? TextStyle(color: theme.colorScheme.error) : null,
                  ),
                  onTap: () => _openWorkout(context, workout),
                  // Il menu coi tre puntini: Rinomina / Elimina.
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Altro per ${workout.name}',
                    onSelected: (action) {
                      if (action == 'rename') _rename(context, workout);
                      if (action == 'delete') draft.removeWorkout(workout);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                      // L'ultima scheda non si toglie: ne serve almeno una.
                      PopupMenuItem(value: 'delete', enabled: workouts.length > 1, child: const Text('Elimina')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: draft.addWorkout,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi scheda'),
            ),
            const SizedBox(height: 8),
            Text(
              'Esempio: tre schede A, B e C che si alternano, oppure Push, Pull e Legs.',
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        );
      },
    );
  }
}

/// Il dialog per dare un nome a una scheda.
class WorkoutNameDialog extends StatefulWidget {
  const WorkoutNameDialog({super.key, required this.initialName});

  final String initialName;

  @override
  State<WorkoutNameDialog> createState() => _WorkoutNameDialogState();
}

class _WorkoutNameDialogState extends State<WorkoutNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nome della scheda'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Es. Push, Gambe, Scheda A'),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
