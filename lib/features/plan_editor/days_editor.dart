import 'package:flutter/material.dart';

import 'package:my_workout/features/plan_editor/plan_draft.dart';
import 'package:my_workout/utils/formatters.dart';

/// I giorni in cui ti alleni (Lun … Dom) e, se vuoi, quando finisce la scheda.
///
/// Non ha uno stato suo: legge e cambia [draft], e si ridisegna quando
/// il draft avvisa (ListenableBuilder). Lo usano l'onboarding e la pagina
/// "Modifica la scheda".
class DaysEditor extends StatelessWidget {
  const DaysEditor({super.key, required this.draft});

  final PlanDraft draft;

  static const _labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  Future<void> _pickEndDate(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    // showDatePicker apre il calendario e restituisce la data scelta,
    // oppure null se l'utente annulla.
    final date = await showDatePicker(
      context: context,
      initialDate: draft.endDate ?? today.add(const Duration(days: 56)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Fine della scheda',
    );
    if (date != null) draft.setEndDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final end = draft.endDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Giorni di allenamento', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Le schede si alternano in questi giorni, nell\'ordine in cui le scrivi.',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: 12),
            // Wrap: i chip stanno su una riga e vanno a capo se non ci stanno.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 7; i++)
                  // FilterChip: un "bottoncino" acceso/spento.
                  FilterChip(
                    label: Text(_labels[i]),
                    selected: draft.weekdays.contains(i + 1),
                    onSelected: (_) => draft.toggleWeekday(i + 1),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Fine della scheda', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Facoltativa: serve a ricordarti quando cambiare scheda.',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(end == null ? 'Nessuna scadenza' : '${formatDayMonth(end)} ${end.year}'),
                subtitle: Text(end == null ? 'Tocca per scegliere una data' : 'Tocca per cambiarla'),
                onTap: () => _pickEndDate(context),
                trailing: end == null
                    ? null
                    : IconButton(
                        tooltip: 'Togli la data di fine',
                        onPressed: () => draft.setEndDate(null),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
