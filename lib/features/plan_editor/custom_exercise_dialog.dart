import 'package:flutter/material.dart';

import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/utils/slug.dart';

/// "Nuovo esercizio": per un esercizio che nella libreria non c'è.
/// Chiede nome, gruppo muscolare e (facoltativi) muscoli e spiegazione.
/// Restituisce l'Exercise creato, o null se annulli.
class CustomExerciseDialog extends StatefulWidget {
  const CustomExerciseDialog({
    super.key,
    required this.takenIds,
    this.initialGroup = MuscleGroup.petto,
    this.initialName = '',
  });

  /// Gli id già usati nella libreria: quello nuovo dev'essere diverso.
  final Set<String> takenIds;
  final MuscleGroup initialGroup;

  /// Il nome di partenza: quello che stavi cercando nella libreria.
  final String initialName;

  @override
  State<CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends State<CustomExerciseDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  final _muscles = TextEditingController();
  final _description = TextEditingController();
  late MuscleGroup _group = widget.initialGroup;

  // true = si misura a tempo ("3 × 30\""), false = a ripetizioni.
  // Per il gruppo Cardio non serve: si misura sempre in minuti.
  bool _timed = false;

  @override
  void dispose() {
    _name.dispose();
    _muscles.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    // "personale_" davanti: un id così non si scontra mai con quelli della
    // libreria, anche se un giorno ne aggiungeremo uno con lo stesso nome.
    final id = uniqueId('personale_${slugify(name, fallback: 'esercizio')}', widget.takenIds.contains);
    Navigator.of(context).pop(
      Exercise(
        id: id,
        name: name,
        category: _group.category,
        group: _group,
        // "Petto, tricipiti" → ["Petto", "tricipiti"], senza pezzi vuoti.
        muscles: [
          for (final m in _muscles.text.split(','))
            if (m.trim().isNotEmpty) m.trim(),
        ],
        description: _description.text.trim(),
        tips: const [],
        images: const [],
        custom: true,
        // Il gruppo Cardio si misura in minuti e livello (ellittica, vogatore...);
        // gli altri a ripetizioni o a tempo, come scelto qui sotto.
        measure: _group == MuscleGroup.cardio
            ? ExerciseMeasure.cardio
            : (_timed ? ExerciseMeasure.time : ExerciseMeasure.reps),
        cardioSettings: _group == MuscleGroup.cardio ? const [CardioSetting.level] : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Nuovo esercizio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Es. Panca inclinata al multipower'),
            ),
            const SizedBox(height: 16),
            Text('Gruppo muscolare', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            // ChoiceChip: come FilterChip, ma se ne sceglie uno solo.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in MuscleGroup.values)
                  ChoiceChip(
                    label: Text(group.label),
                    selected: group == _group,
                    onSelected: (_) => setState(() => _group = group),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Si misura in', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_group == MuscleGroup.cardio)
              Text('Minuti e livello della macchina', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Ripetizioni'),
                    selected: !_timed,
                    onSelected: (_) => setState(() => _timed = false),
                  ),
                  ChoiceChip(
                    label: const Text('Tempo'),
                    selected: _timed,
                    onSelected: (_) => setState(() => _timed = true),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _muscles,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Muscoli (facoltativo)',
                hintText: 'Es. Pettorali, tricipiti',
                helperText: 'Separali con una virgola',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Come si esegue (facoltativo)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: const Text('Crea'),
          ),
        ),
      ],
    );
  }
}
