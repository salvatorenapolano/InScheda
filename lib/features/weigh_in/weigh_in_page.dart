import 'package:flutter/material.dart';

import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/features/weigh_in/widgets/weigh_in_banner.dart';
import 'package:my_workout/features/weigh_in/widgets/weigh_in_day_dialog.dart';
import 'package:my_workout/models/body_weight.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/dividers.dart';
import 'package:my_workout/widgets/weight_input_dialog.dart';
import 'package:my_workout/widgets/main_app_bar.dart';
import 'package:my_workout/widgets/page_title.dart';

/// Tab "Pesata": il promemoria del giorno della pesata, lo storico delle pesate
/// e il pulsante + per aggiungere quella di oggi.
class WeighInPage extends StatelessWidget {
  const WeighInPage({super.key});

  @override
  Widget build(BuildContext context) {
    // of(context) "iscrive" la pagina: quando salvi o cancelli una
    // pesata, build() riparte da solo e la lista si aggiorna.
    final store = BodyWeightScope.of(context);
    final entries = store.entries;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const MainAppBar(),
      // FloatingActionButton: il pulsante rotondo che "galleggia" in basso
      // a destra, sopra la lista. È l'azione principale della pagina.
      floatingActionButton: FloatingActionButton(
        // heroTag null: anche la Spesa ha un pulsante tondo; con lo stesso
        // "tag" Hero, aprendo una pagina nuova si scontrerebbero.
        heroTag: null,
        tooltip: 'Aggiungi pesata',
        onPressed: () => _addToday(context, store),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        // In fondo più spazio: l'ultima riga non finisce sotto il pulsante +.
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          // Il titolo col calendario: cambia il giorno della pesata.
          PageTitle(
            title: 'Pesata',
            editTooltip: 'Giorno della pesata',
            editIcon: Icons.edit_calendar_outlined,
            onEdit: () => editWeighInDay(context),
          ),
          const SizedBox(height: 12),
          WeighInBanner(
            entries: entries,
            now: DateTime.now(),
            // Il giorno scelto nell'onboarding (o col calendario accanto al titolo).
            weekday: ProfileScope.of(context).weighInWeekday,
          ),
          const SizedBox(height: 24),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                'Nessuna pesata salvata. Tocca + per aggiungere quella di oggi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            Card(
              child: Column(
                children: withDividers([
                  for (final (index, entry) in entries.indexed)
                    _WeighInRow(
                      entry: entry,
                      // La pesata precedente (più vecchia) serve per la differenza.
                      // elementAtOrNull: null se siamo all'ultima della lista.
                      previous: entries.elementAtOrNull(index + 1),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /// Il + : chiede il peso e lo salva con la data di oggi.
  /// Se oggi ti eri già pesato, il campo parte dal valore di oggi
  /// e Salva lo sostituisce.
  Future<void> _addToday(BuildContext context, BodyWeightStore store) async {
    final today = dateOnly(DateTime.now());
    final todayEntry = store.entries.where((e) => e.date == today).firstOrNull;
    final kg = await showDialog<double>(
      context: context,
      builder: (context) => WeightInputDialog(
        title: 'Pesata di oggi',
        initial: todayEntry?.kg,
        example: '78,4',
      ),
    );
    if (kg != null) await store.save(today, kg);
  }
}

/// Una riga dello storico: data a sinistra, differenza e peso a destra.
/// Tocchi per correggerla, scorri verso sinistra per cancellarla.
class _WeighInRow extends StatelessWidget {
  const _WeighInRow({required this.entry, required this.previous});

  final BodyWeightEntry entry;
  final BodyWeightEntry? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final store = BodyWeightScope.of(context);
    final previous = this.previous;

    // Dismissible: la riga si può trascinare via col dito.
    // La `key` deve essere unica e stabile: usiamo la data.
    return Dismissible(
      key: ValueKey(entry.date),
      direction: DismissDirection.endToStart, // solo verso sinistra
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: colors.errorContainer,
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      onDismissed: (_) => _delete(context, store),
      child: ListTile(
        title: Text(capitalize(formatDayMonth(entry.date))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previous != null) ...[
              Text(
                formatWeightChange(entry.kg - previous.kg),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              formatWeight(entry.kg),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        onTap: () => _edit(context, store),
      ),
    );
  }

  Future<void> _edit(BuildContext context, BodyWeightStore store) async {
    final kg = await showDialog<double>(
      context: context,
      builder: (context) => WeightInputDialog(
        title: capitalize(formatDayMonth(entry.date)),
        initial: entry.kg,
        example: '78,4',
      ),
    );
    if (kg != null) await store.save(entry.date, kg);
  }

  void _delete(BuildContext context, BodyWeightStore store) {
    // Ci teniamo la pesata cancellata per poterla rimettere con "Annulla".
    final removed = entry;
    store.remove(removed.date);
    // SnackBar: il messaggio che compare per qualche secondo in basso.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Pesata eliminata'),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () => store.save(removed.date, removed.kg),
          ),
        ),
      );
  }
}
