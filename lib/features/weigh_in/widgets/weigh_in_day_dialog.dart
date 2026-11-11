import 'package:flutter/material.dart';

import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/features/weigh_in/widgets/weigh_in_day_picker.dart';

/// Apre il dialog per cambiare il giorno della pesata e, con "Salva", lo
/// salva nel profilo. Lo usa il pulsante calendario della tab Pesata.
Future<void> editWeighInDay(BuildContext context) async {
  // Lo store lo prendiamo prima dell'await: dopo, il context potrebbe
  // non essere più valido.
  final profile = ProfileScope.of(context);
  final day = await showDialog<int>(
    context: context,
    builder: (context) => _WeighInDayDialog(initialDay: profile.weighInWeekday),
  );
  if (day != null) await profile.setWeighInWeekday(day);
}

/// Il dialog per il giorno della pesata: i 7 giorni, se ne sceglie uno.
class _WeighInDayDialog extends StatefulWidget {
  const _WeighInDayDialog({required this.initialDay});

  final int initialDay;

  @override
  State<_WeighInDayDialog> createState() => _WeighInDayDialogState();
}

class _WeighInDayDialogState extends State<_WeighInDayDialog> {
  late int _day = widget.initialDay;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Giorno della pesata'),
      content: WeighInDayPicker(
        value: _day,
        onChanged: (day) => setState(() => _day = day),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_day),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
