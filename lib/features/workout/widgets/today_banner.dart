import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/features/focus/focus_actions.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/status_banner.dart';

/// Il riquadro in alto che ti dice cosa tocca oggi, in base al calendario.
///
/// Riceve `now` invece di chiamare DateTime.now() da sola: così nei test
/// possiamo fingere che sia lunedì, domenica o dopo la fine della scheda.
///
/// Con [onStart] compare la pillola verde "Inizia", che avvia
/// la modalità Focus sulla scheda di oggi (o sulla prossima, se oggi è riposo).
/// Durante il Focus al suo posto c'è [FocusBanner].
class TodayBanner extends StatelessWidget {
  const TodayBanner({super.key, required this.plan, required this.now, this.onStart});

  final WorkoutPlan plan;
  final DateTime now;

  /// Riceve la scheda da avviare. null = niente pulsante (es. nei test).
  final ValueChanged<Workout>? onStart;

  @override
  Widget build(BuildContext context) {
    final next = plan.nextSessionFrom(now);

    // I record (a, b, c) permettono di restituire più valori insieme.
    // Lo `switch` sceglie il caso giusto e li assegna in un colpo solo.
    final (IconData icon, String title, String subtitle, bool isToday) = switch (next) {
      // Nessuna seduta: la scheda è finita, oppure non ha giorni.
      null => switch (plan.endDate) {
          final end? => (
              Icons.flag_outlined,
              'Scheda terminata',
              "L'ultima seduta era ${formatDayMonth(end)}: è ora della prossima scheda.",
              false,
            ),
          null => (
              Icons.event_busy_outlined,
              'Nessun allenamento in calendario',
              'Scegli i giorni in cui ti alleni.',
              false,
            ),
        },
      _ when DateUtils.isSameDay(next.date, now) => (
          Icons.fitness_center,
          'Oggi: ${plan.workoutById(next.workoutId).name}',
          // Sotto, i muscoli del giorno. Niente orario: l'ora
          // (plan.schedule.time) resta nel JSON ma non la mostriamo.
          plan.workoutById(next.workoutId).focus ?? plan.name,
          true,
        ),
      _ => (
          Icons.self_improvement,
          'Oggi riposo',
          'Prossimo allenamento ${formatRelativeDay(next.date, now: now)}: '
              '${plan.workoutById(next.workoutId).name}',
          false,
        ),
    };

    // Il nome gigante del giorno ("PUSH"), solo nei giorni di palestra.
    final letter = isToday && next != null
        ? plan.workoutById(next.workoutId).name.toUpperCase()
        : null;

    // L'aspetto (colori, forma, watermark) lo decide StatusBanner:
    // qui scegliamo solo cosa scriverci.
    final onStart = this.onStart;
    // Il colore della scheda di oggi (solo nei giorni di palestra il
    // banner è colorato; nei giorni di riposo resta neutro).
    final color = isToday && next != null ? workoutColor(plan.indexOfWorkout(next.workoutId)) : null;

    return StatusBanner(
      icon: icon,
      title: title,
      subtitle: subtitle,
      highlighted: isToday,
      color: color,
      // Il pulsante c'è sempre quando c'è una prossima seduta: anche nei
      // giorni di riposo, se vuoi anticipare l'allenamento.
      action: next == null || onStart == null
          ? null
          : StartWorkoutButton(onPressed: () => onStart(plan.workoutById(next.workoutId))),
      watermark: letter == null
          ? null
          : Text(
              letter,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                // Una lettera sola ("A") può essere enorme, una parola
                // ("PUSH") deve stare nel riquadro.
                fontSize: letter.length <= 2 ? 150 : 96,
                height: 1,
              ),
            ),
    );
  }
}

/// Il banner durante il Focus: la scheda, il cronometro, le kcal e
/// "Termina allenamento".
class FocusBanner extends StatelessWidget {
  const FocusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = FocusModeScope.of(context);
    final active = focus.active;
    if (active == null) return const SizedBox.shrink();

    // Il sottotitolo cambia ogni secondo: FocusTicker ridisegna il banner.
    return FocusTicker(
      builder: (context) => StatusBanner(
        icon: Icons.local_fire_department,
        title: 'Focus: ${active.workoutName}',
        subtitle: '${formatClock(focus.elapsed)} · ${formatKcal(focus.kcal)} · '
            '${active.rests} ${active.rests == 1 ? 'recupero' : 'recuperi'}',
        highlighted: true,
        // Il colore della scheda in corso, fissato quando l'hai iniziata.
        color: workoutColor(active.colorIndex),
        // Accanto al testo come "Inizia", ma arancione come il Focus.
        action: BannerActionButton(
          icon: Icons.stop_rounded,
          label: 'Termina',
          tooltip: 'Termina allenamento',
          color: FocusColors.glow,
          onPressed: () => finishFocus(context),
        ),
      ),
    );
  }
}
