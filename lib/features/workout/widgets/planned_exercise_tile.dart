import 'package:flutter/material.dart';

import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/workout/exercise_detail_page.dart';
import 'package:my_workout/features/workout/widgets/exercise_preview.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';

/// Una riga della scheda: anteprima, nome, "3 × 10–12 · rec. 90"" e peso.
/// Toccandola si apre il dettaglio dell'esercizio.
class PlannedExerciseTile extends StatelessWidget {
  const PlannedExerciseTile({
    super.key,
    required this.planned,
    required this.exercise,
    required this.sectionTitle,
    this.number,
  });

  /// Posizione nella scheda (1, 2, 3…), mostrata sull'angolo dell'anteprima.
  /// null = nessun numero (riscaldamento e addominali).
  final int? number;

  final PlannedExercise planned;
  final Exercise exercise;

  /// Da dove arrivi ("Scheda B", "Riscaldamento"...): diventa il titolo
  /// della barra in alto nel dettaglio.
  final String sectionTitle;

  /// Un "getter": si usa come un campo (_details) ma viene calcolato.
  String get _details => formatPlanned(planned);

  @override
  Widget build(BuildContext context) {
    final notes = planned.notes;
    // Leggere lo store con of(context) "iscrive" questa riga ai cambiamenti:
    // quando salvi un peso nel dettaglio, la riga si aggiorna da sola.
    final weight = exercise.hasWeight ? WeightScope.of(context).weightFor(exercise.id) : null;

    final number = this.number;
    final theme = Theme.of(context);

    return ListTile(
      leading: ExercisePreview(exercise: exercise, number: number),
      // Il nome nel font da tabellone, i dettagli nel font di sistema.
      title: Text(exercise.name, style: theme.textTheme.titleMedium),
      subtitle: Text(notes == null ? _details : '$_details\n$notes'),
      trailing: Row(
        // min: la Row occupa solo lo spazio che le serve.
        mainAxisSize: MainAxisSize.min,
        children: [
          if (weight != null)
            Text(
              formatWeight(weight),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                // Cifre tutte larghe uguali: "18 kg" e "22 kg" occupano
                // lo stesso spazio e la colonna dei pesi resta in fila.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
      onTap: () {
        // Navigator.push mette una nuova pagina "sopra" quella attuale;
        // la freccia indietro la toglie (Navigator.pop).
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ExerciseDetailPage(
              planned: planned,
              exercise: exercise,
              sectionTitle: sectionTitle,
            ),
          ),
        );
      },
    );
  }
}
