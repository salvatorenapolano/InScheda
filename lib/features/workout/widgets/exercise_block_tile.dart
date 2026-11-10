import 'package:flutter/material.dart';

import 'package:my_workout/data/workout_repository.dart';
import 'package:my_workout/features/workout/widgets/planned_exercise_tile.dart';
import 'package:my_workout/features/workout/widgets/step_number.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/widgets/dividers.dart';

/// Riscaldamento e addominali: una card che si apre e si chiude.
class ExerciseBlockTile extends StatelessWidget {
  const ExerciseBlockTile({
    super.key,
    required this.number,
    required this.block,
    required this.data,
  });

  final int number;
  final ExerciseBlock block;
  final WorkoutData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intro = block.intro;
    final minutes = block.durationMinutes;

    // La Card fa da "contenitore" arrotondato; l'ExpansionTile dentro
    // gestisce da solo l'apertura con l'animazione della freccia.
    return Card(
      child: ExpansionTile(
        leading: StepNumber(number),
        title: Text(block.title, style: theme.textTheme.titleLarge),
        subtitle: Text([
          if (minutes != null) '$minutes min',
          '${block.exercises.length} esercizi',
        ].join(' · ')),
        children: [
          if (intro != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                intro,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const Divider(),
          ...withDividers(indent: 80, [
            for (final planned in block.exercises)
              PlannedExerciseTile(
                planned: planned,
                exercise: data.exerciseFor(planned),
                sectionTitle: block.title,
              ),
          ]),
        ],
      ),
    );
  }
}
