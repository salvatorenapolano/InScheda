import 'package:flutter/material.dart';

import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/focus/calories.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';

/// Il timer del dettaglio esercizio in modalità Focus (al posto del video).
///
/// Per gli esercizi coi pesi è il recupero fra le serie; per il cardio
/// sono i minuti della macchina. Se l'esercizio non ha né l'uno né l'altro
/// non c'è niente da cronometrare: [secondsFor] dà null e la card non si mette.
class RestTimerCard extends StatelessWidget {
  const RestTimerCard({super.key, required this.planned, required this.exercise});

  final PlannedExercise planned;
  final Exercise exercise;

  /// I secondi del timer di questo esercizio, o null.
  static int? secondsFor(PlannedExercise planned) =>
      planned.durationMinutes != null ? planned.durationMinutes! * 60 : planned.restSeconds;

  @override
  Widget build(BuildContext context) {
    final focus = FocusModeScope.of(context);
    final seconds = secondsFor(planned);
    if (seconds == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isCardio = planned.isCardio;
    final label = isCardio ? 'Cardio' : 'Recupero';
    final rest = focus.rest;
    // Il timer che scorre è di questo esercizio?
    final mine = rest != null && rest.key == exercise.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: mine
            ? FocusTicker(builder: (context) => _running(context, rest, focus.restLeft, label))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const _Dial(progress: 1, icon: Icons.timer_outlined),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            Text(
                              isCardio ? '${planned.durationMinutes} min' : formatClock(Duration(seconds: seconds)),
                              style: theme.textTheme.displaySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => focus.startTimer(
                      key: exercise.id,
                      label: exercise.name,
                      seconds: seconds,
                      countsAsRest: !isCardio,
                      // "Avvia recupero" = ho finito una serie: col peso di
                      // adesso, per la stima delle kcal di questo esercizio.
                      strength: isCardio
                          ? null
                          : strengthLogFor(
                              exercise,
                              planned,
                              savedKg: WeightScope.of(context).weightFor(exercise.id),
                              bodyKg: focus.active?.bodyKg ?? 0,
                            ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(isCardio ? 'Avvia timer' : 'Avvia recupero'),
                  ),
                  // Un timer di un altro esercizio sta già scorrendo.
                  if (rest != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'È in corso il timer di ${rest.label}: avviando questo lo sostituisci.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  /// Il timer che scorre: il cerchio si "svuota" e i secondi calano.
  Widget _running(BuildContext context, RestTimer rest, Duration left, String label) {
    final theme = Theme.of(context);
    final focus = FocusModeScope.of(context);
    final progress = rest.total.inMilliseconds == 0 ? 0.0 : left.inMilliseconds / rest.total.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Dial(progress: progress, icon: Icons.hourglass_bottom, active: true),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label in corso',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    formatClock(left),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: FocusColors.glow,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: focus.stopTimer,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Ferma'),
        ),
      ],
    );
  }
}

/// Il cerchio del timer: pieno da fermo, si svuota mentre scorre.
class _Dial extends StatelessWidget {
  const _Dial({required this.progress, required this.icon, this.active = false});

  final double progress;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? FocusColors.glow : colors.primary;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Icon(icon, color: color),
        ],
      ),
    );
  }
}
