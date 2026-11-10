import 'package:flutter/material.dart';

/// I 7 giorni (Lun … Dom) come ChoiceChip: se ne sceglie uno solo.
/// Lo usano l'onboarding ("Quando ti pesi?") e il pannello del profilo.
class WeighInDayPicker extends StatelessWidget {
  const WeighInDayPicker({super.key, required this.value, required this.onChanged});

  /// Il giorno scelto: 1 = lunedì … 7 = domenica.
  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 7; i++)
          ChoiceChip(
            label: Text(_labels[i]),
            selected: value == i + 1,
            onSelected: (_) => onChanged(i + 1),
          ),
      ],
    );
  }
}
