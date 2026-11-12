import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/models/workout_session.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/empty_state.dart';

/// "Storico allenamenti" (dal profilo): gli allenamenti finiti in Focus,
/// con in cima i totali.
class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = FocusModeScope.of(context);
    final history = focus.history;

    return Scaffold(
      appBar: AppBar(title: const Text('Storico allenamenti')),
      body: history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Nessun allenamento',
              message: 'Tocca "Inizia" nel riquadro della tab Allenamento: '
                  'quando lo termini lo trovi qui, con durata e kcal.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Totals(history: history),
                const SizedBox(height: 16),
                for (final session in history) ...[
                  _SessionCard(session: session, onDelete: () => _delete(context, focus, session)),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Future<void> _delete(BuildContext context, FocusStore focus, WorkoutSession session) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminare l'allenamento?"),
        content: Text('${session.workoutName} del ${formatDayMonth(session.startedAt)} sparirà dallo storico.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Elimina')),
        ],
      ),
    );
    if (sure == true) await focus.deleteSession(session);
  }
}

/// I totali di tutto lo storico.
class _Totals extends StatelessWidget {
  const _Totals({required this.history});

  final List<WorkoutSession> history;

  @override
  Widget build(BuildContext context) {
    // fold: "accumula" un valore passando tutti gli elementi, partendo da zero.
    final time = history.fold(Duration.zero, (sum, s) => sum + s.duration);
    final kcal = history.fold(0.0, (sum, s) => sum + s.kcal);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: FocusMetric(
                icon: Icons.fitness_center,
                value: '${history.length}',
                label: history.length == 1 ? 'allenamento' : 'allenamenti',
              ),
            ),
            Expanded(child: FocusMetric(icon: Icons.timer_outlined, value: formatDurationShort(time), label: 'in totale')),
            Expanded(
              child: FocusMetric(icon: Icons.local_fire_department_outlined, value: formatKcal(kcal), label: 'stimate'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un allenamento: la data a sinistra, scheda e metriche, il menu per eliminarlo.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onDelete});

  final WorkoutSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = session.startedAt;
    final time = '${start.hour}:${start.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        // Il quadratino col colore della scheda: lettera grande, data sotto.
        // Gli allenamenti di prima dei colori restano viola, come la scheda A.
        leading: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: workoutColor(session.colorIndex ?? 0),
            borderRadius: BorderRadius.circular(12),
          ),
          // FittedBox(scaleDown): se lettera e data non ci stanno (caratteri
          // grandi nelle impostazioni del telefono) le rimpicciolisce invece
          // di farle uscire dal quadratino.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  workoutInitial(session.workoutName),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, height: 1),
                ),
                Text(
                  formatShortDate(start),
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        title: Text(session.workoutName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${capitalize(formatWeekday(start.weekday))} alle $time\n'
          '${formatDurationShort(session.duration)} · ${formatKcal(session.kcal)} · '
          '${session.rests} ${session.rests == 1 ? 'recupero' : 'recuperi'}',
        ),
        isThreeLine: true,
        // PopupMenuButton: i tre puntini che aprono un piccolo menu.
        trailing: PopupMenuButton<void>(
          tooltip: 'Altro',
          itemBuilder: (context) => [
            PopupMenuItem(onTap: onDelete, child: const Text('Elimina')),
          ],
        ),
      ),
    );
  }
}

/// Usata dal tutorial: una card finta, con valori d'esempio.
class SampleSessionCard extends StatelessWidget {
  const SampleSessionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: FocusMetricsRow(duration: const Duration(minutes: 58, seconds: 12), kcal: 312, rests: 14),
      ),
    );
  }
}
