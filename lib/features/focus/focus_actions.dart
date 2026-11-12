import 'package:flutter/material.dart';

import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/features/focus/calories.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/widgets/weight_input_dialog.dart';

/// I "flussi" della modalità Focus: funzioni che mettono in fila dialog e
/// salvataggi. Non sono widget: le chiamano i pulsanti.

/// "Inizia allenamento": peso corporeo (per le kcal), permessi per gli
/// avvisi, poi parte il cronometro.
///
/// [colorIndex] è la posizione della scheda nel piano: ne decide il colore,
/// che resta quello anche nello storico.
Future<void> startFocus(
  BuildContext context, {
  required Workout workout,
  CardioBlock? planCardio,
  int colorIndex = 0,
}) async {
  // Gli store PRIMA degli await: dopo, il context potrebbe non esserci più.
  final focus = FocusModeScope.of(context);
  final bodyWeights = BodyWeightScope.of(context);

  // Il peso dell'ultima pesata; se non ce ne sono, lo chiediamo e lo
  // salviamo come pesata di oggi (così la prossima volta c'è già).
  var kg = bodyWeights.entries.firstOrNull?.kg;
  if (kg == null) {
    kg = await showDialog<double>(
      context: context,
      builder: (context) => const WeightInputDialog(title: 'Quanto pesi?', example: '72,5'),
    );
    if (kg == null || kg <= 0) return;
    await bodyWeights.save(DateTime.now(), kg);
  }

  await focus.alerts.requestPermission();

  // Android 14+: senza "Sveglie e promemoria" la notifica del recupero può
  // arrivare in ritardo. Lo spieghiamo una volta sola, senza insistere.
  if (!focus.exactAlarmAsked && !await focus.alerts.canScheduleExact()) {
    await focus.markExactAlarmAsked();
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm),
        title: const Text('Avvisi a fine recupero'),
        content: const Text(
          'Per avvisarti al secondo giusto anche col telefono in tasca, InScheda '
          'ha bisogno del permesso "Sveglie e promemoria". Senza, la notifica può '
          'arrivare in ritardo (con l\'app aperta il telefono vibra comunque).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Più tardi')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apri impostazioni')),
        ],
      ),
    );
    if (open == true) await focus.alerts.openExactAlarmSettings();
  }

  await focus.start(
    workoutId: workout.id,
    workoutName: workout.name,
    bodyKg: kg,
    colorIndex: colorIndex,
    cardio: cardioPartsFor(workout, planCardio: planCardio),
  );
}

/// Le tre scelte del dialog "Terminare l'allenamento?".
enum _FinishChoice { save, discard }

/// "Termina allenamento": conferma, salva nello storico e mostra il riepilogo.
Future<void> finishFocus(BuildContext context) async {
  final focus = FocusModeScope.of(context);
  final choice = await showDialog<_FinishChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Terminare l'allenamento?"),
      // Le metriche continuano a scorrere anche col dialog aperto.
      content: FocusTicker(
        builder: (context) => FocusMetricsRow(
          duration: focus.elapsed,
          kcal: focus.kcal,
          rests: focus.active?.rests ?? 0,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(_FinishChoice.discard), child: const Text('Scarta')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continua')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_FinishChoice.save), child: const Text('Termina')),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  if (choice == _FinishChoice.discard) {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scartare l'allenamento?"),
        content: const Text('Non finirà nello storico.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Scarta')),
        ],
      ),
    );
    if (sure == true) await focus.finish(save: false);
    return;
  }

  final session = await focus.finish(save: true);
  if (session == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.emoji_events_outlined, color: FocusColors.glow, size: 40),
      title: Text('${session.workoutName}: fatto!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusMetricsRow(duration: session.duration, kcal: session.kcal, rests: session.rests),
          const SizedBox(height: 16),
          const Text(
            'Lo ritrovi in Storico allenamenti, toccando il cerchio del profilo.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ok'))],
    ),
  );
}

/// Il pannello che si apre toccando il cronometro nell'header.
Future<void> showFocusSheet(BuildContext context) async {
  final focus = FocusModeScope.of(context);
  final finish = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Focus: ${focus.active?.workoutName ?? ''}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FocusTicker(
              builder: (context) => FocusMetricsRow(
                duration: focus.elapsed,
                kcal: focus.kcal,
                rests: focus.active?.rests ?? 0,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Termina allenamento'),
            ),
          ],
        ),
      ),
    ),
  );
  if (finish == true && context.mounted) await finishFocus(context);
}
