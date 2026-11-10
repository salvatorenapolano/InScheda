import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/workout/widgets/exercise_media.dart';
import 'package:my_workout/features/workout/widgets/muscle_card.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/weight_input_dialog.dart';

/// Il dettaglio di un esercizio: anteprima, cosa dice la scheda,
/// il tuo peso, come si esegue, consigli e alternative.
class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({
    super.key,
    required this.planned,
    required this.exercise,
    required this.sectionTitle,
  });

  final PlannedExercise planned;
  final Exercise exercise;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // In una variabile locale: Dart così "sa" che dopo il controllo
    // `!= null` è una String vera (promozione di tipo).
    final muscleAsset = exercise.muscleAsset;

    return Scaffold(
      // La freccia indietro la aggiunge l'AppBar da sola, perché sa
      // che questa pagina è stata aperta con Navigator.push.
      appBar: AppBar(title: Text(sectionTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Video YouTube se c'è, altrimenti l'anteprima SVG.
          ExerciseMedia(exercise: exercise),
          const SizedBox(height: 16),
          Text(exercise.name, style: textTheme.headlineMedium),
          // I chip sotto il nome solo se manca l'illustrazione:
          // altrimenti i muscoli sono già nella card "Muscoli" più in basso.
          if (exercise.muscles.isNotEmpty && muscleAsset == null) ...[
            const SizedBox(height: 8),
            // Wrap: come una Row, ma va a capo se non c'è spazio.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final m in exercise.muscles) Chip(label: Text(m))],
            ),
          ],
          const SizedBox(height: 16),
          _PlanCard(planned: planned),
          if (exercise.hasWeight) ...[
            const SizedBox(height: 12),
            _WeightCard(exercise: exercise),
          ],
          // Dopo il peso (quello che usi di più in palestra), prima della
          // spiegazione: i muscoli aiutano a capire l'esercizio.
          if (muscleAsset != null) ...[
            const SizedBox(height: 12),
            MuscleCard(exercise: exercise, asset: muscleAsset),
          ],
          _Section(
            title: 'Come si esegue',
            child: Text(exercise.description, style: textTheme.bodyLarge),
          ),
          if (exercise.tips.isNotEmpty)
            _Section(
              title: 'Consigli',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tip in exercise.tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $tip', style: textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
          if (planned.alternatives.isNotEmpty)
            _Section(
              title: 'Se è occupato',
              child: Text(planned.alternatives.join(' · '), style: textTheme.bodyLarge),
            ),
        ],
      ),
    );
  }
}

/// Cosa dice la scheda: serie, ripetizioni, recupero e note.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.planned});

  final PlannedExercise planned;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final sets = planned.sets;
    final rest = planned.restSeconds;
    final notes = planned.notes;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Il dato principale grande, nel font da tabellone.
            Text(
              sets == null ? planned.reps : '$sets serie × ${planned.reps}',
              style: textTheme.headlineSmall,
            ),
            if (rest != null)
              Text('Recupero ${formatRest(rest)}', style: textTheme.bodyMedium?.copyWith(color: secondary)),
            if (notes != null) ...[
              const SizedBox(height: 4),
              Text(notes, style: textTheme.bodySmall?.copyWith(color: secondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Il tuo peso per questo esercizio, con − / + e tocco per scriverlo.
class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.exercise});

  final Exercise exercise;

  static const _step = 1.0;

  @override
  Widget build(BuildContext context) {
    final store = WeightScope.of(context);
    final weight = store.weightFor(exercise.id);
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              // InkWell rende toccabile qualsiasi widget (con l'effetto onda).
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                onTap: () => _editWeight(context, store, weight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Il tuo peso',
                      style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    // Il numero è il protagonista della card.
                    Text(
                      weight == null ? '—' : formatWeight(weight),
                      style: textTheme.displaySmall?.copyWith(
                        color: colors.primary,
                        // Cifre a larghezza fissa: premendo + il testo non "balla".
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Diminuisci',
              icon: const Icon(Icons.remove),
              // onPressed: null disattiva il pulsante.
              onPressed: weight == null ? null : () => store.setWeight(exercise.id, weight - _step),
            ),
            const SizedBox(width: 8),
            // IconButton.filled: pieno col colore primario, è l'azione più usata.
            IconButton.filled(
              tooltip: 'Aumenta',
              icon: const Icon(Icons.add),
              onPressed: () => store.setWeight(exercise.id, (weight ?? 0) + _step),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editWeight(BuildContext context, WeightStore store, double? current) async {
    // showDialog restituisce un Future: si completa quando il dialog
    // viene chiuso, con il valore passato a Navigator.pop (o null).
    final result = await showDialog<double>(
      context: context,
      // Dialog condiviso con la tab Pesata: qui il campo vuoto cancella il peso.
      builder: (context) => WeightInputDialog(
        title: 'Il tuo peso',
        initial: current,
        emptyMeansDelete: true,
      ),
    );
    if (result != null) await store.setWeight(exercise.id, result);
  }
}

/// Una sezione con un titolo sopra ("Come si esegue", "Consigli"...).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Maiuscole normali: il font da tabellone basta a farlo spiccare.
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
