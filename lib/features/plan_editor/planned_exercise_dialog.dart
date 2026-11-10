import 'package:flutter/material.dart';

import 'package:my_workout/models/exercise.dart';
import 'package:my_workout/models/workout_plan.dart';
import 'package:my_workout/utils/formatters.dart';

/// Il dialog per cambiare un esercizio della scheda. I campi dipendono da
/// come si misura l'esercizio ([Exercise.measure]):
/// - ripetizioni: serie (anche nessuna), ripetizioni, recupero;
/// - tempo: serie, secondi (anche "per lato"), recupero;
/// - cardio: minuti e le impostazioni della macchina (velocità, pendenza,
///   livello), niente serie né recupero.
/// Restituisce il PlannedExercise aggiornato, o null se annulli.
class PlannedExerciseDialog extends StatefulWidget {
  const PlannedExerciseDialog({
    super.key,
    required this.planned,
    required this.exercise,
    this.confirmLabel = 'Salva',
    this.progress,
  });

  final PlannedExercise planned;

  /// null se l'esercizio non è più in libreria: lo trattiamo a ripetizioni.
  final Exercise? exercise;

  /// Il testo del pulsante di conferma: "Salva" quando modifichi,
  /// "Aggiungi" quando l'esercizio sta per entrare nella scheda.
  final String confirmLabel;

  /// Una riga sopra al titolo quando si aggiungono più esercizi di fila:
  /// "Esercizio 2 di 3". null = niente riga.
  final String? progress;

  @override
  State<PlannedExerciseDialog> createState() => _PlannedExerciseDialogState();
}

class _PlannedExerciseDialogState extends State<PlannedExerciseDialog> {
  // `widget.` dà accesso ai campi dello StatefulWidget dall'interno dello State.
  late final ExerciseMeasure _measure = widget.exercise?.measure ?? ExerciseMeasure.reps;
  late final List<CardioSetting> _settings = widget.exercise?.cardioSettings ?? const [];

  // Ripetizioni e tempo. 0 serie = "nessuna" (es. la mobilità del
  // riscaldamento: solo "10 per lato"); 0 recupero = nessun recupero.
  late int _sets = widget.planned.sets ?? 0;
  late int _rest = widget.planned.restSeconds ?? 0;
  late final _reps = TextEditingController(text: widget.planned.reps);

  // Tempo: i secondi e "per lato", letti dal testo ("20\" per lato").
  late int _seconds = parseSeconds(widget.planned.reps) ?? 30;
  late bool _perSide = widget.planned.reps.contains('per lato');

  // Cardio.
  late int _minutes = widget.planned.durationMinutes ?? 20;
  late double _speed = widget.planned.speedKmh ?? 5.5;
  late double _incline = widget.planned.inclinePercent ?? 5;
  late int _level = widget.planned.level ?? 5;

  @override
  void dispose() {
    _reps.dispose();
    super.dispose();
  }

  void _save() {
    final planned = widget.planned;
    final result = switch (_measure) {
      ExerciseMeasure.cardio => PlannedExercise(
          exerciseId: planned.exerciseId,
          durationMinutes: _minutes,
          speedKmh: _settings.contains(CardioSetting.speed) ? _speed : null,
          inclinePercent: _settings.contains(CardioSetting.incline) ? _incline : null,
          level: _settings.contains(CardioSetting.level) ? _level : null,
          notes: planned.notes,
        ),
      ExerciseMeasure.time => PlannedExercise(
          exerciseId: planned.exerciseId,
          sets: _sets == 0 ? null : _sets,
          reps: '${formatSeconds(_seconds)}${_perSide ? ' per lato' : ''}',
          restSeconds: _rest == 0 ? null : _rest,
          notes: planned.notes,
          alternatives: planned.alternatives,
        ),
      ExerciseMeasure.reps => PlannedExercise(
          exerciseId: planned.exerciseId,
          sets: _sets == 0 ? null : _sets,
          reps: _reps.text.trim().isEmpty ? '10' : _reps.text.trim(),
          restSeconds: _rest == 0 ? null : _rest,
          // Note e alternative non si modificano qui: le teniamo come sono.
          notes: planned.notes,
          alternatives: planned.alternatives,
        ),
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.progress case final progress?)
            Text(
              progress,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          Text(widget.exercise?.name ?? planned.exerciseId),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_measure) {
            ExerciseMeasure.cardio => _cardioFields(),
            ExerciseMeasure.time => _timeFields(),
            ExerciseMeasure.reps => _repsFields(),
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: Text(widget.confirmLabel)),
      ],
    );
  }

  PlannedExercise get planned => widget.planned;

  _Stepper _setsStepper() => _Stepper(
        label: 'Serie',
        value: _sets == 0 ? 'nessuna' : '$_sets',
        onMinus: _sets > 0 ? () => setState(() => _sets--) : null,
        onPlus: _sets < 10 ? () => setState(() => _sets++) : null,
      );

  _Stepper _restStepper() => _Stepper(
        label: 'Recupero',
        value: _rest == 0 ? 'nessuno' : formatRest(_rest),
        onMinus: _rest > 0 ? () => setState(() => _rest -= 15) : null,
        onPlus: _rest < 300 ? () => setState(() => _rest += 15) : null,
      );

  List<Widget> _repsFields() => [
        _setsStepper(),
        const SizedBox(height: 16),
        TextField(
          controller: _reps,
          decoration: const InputDecoration(
            labelText: 'Ripetizioni',
            helperText: 'Es. 10, 8–12 oppure 12 per lato',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _restStepper(),
      ];

  List<Widget> _timeFields() => [
        _setsStepper(),
        const SizedBox(height: 16),
        _Stepper(
          label: 'Durata',
          value: formatSeconds(_seconds),
          onMinus: _seconds > 5 ? () => setState(() => _seconds -= 5) : null,
          onPlus: _seconds < 300 ? () => setState(() => _seconds += 5) : null,
        ),
        // Il plank laterale: la durata vale per ogni lato.
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Per lato'),
          value: _perSide,
          onChanged: (value) => setState(() => _perSide = value ?? false),
        ),
        const SizedBox(height: 8),
        _restStepper(),
      ];

  List<Widget> _cardioFields() => [
        _Stepper(
          label: 'Durata',
          value: '$_minutes min',
          onMinus: _minutes > 1 ? () => setState(() => _minutes--) : null,
          onPlus: _minutes < 120 ? () => setState(() => _minutes++) : null,
        ),
        if (_settings.contains(CardioSetting.speed)) ...[
          const SizedBox(height: 16),
          _Stepper(
            label: 'Velocità',
            value: '${formatNumber(_speed)} km/h',
            onMinus: _speed > 1 ? () => setState(() => _speed -= 0.5) : null,
            onPlus: _speed < 20 ? () => setState(() => _speed += 0.5) : null,
          ),
        ],
        if (_settings.contains(CardioSetting.incline)) ...[
          const SizedBox(height: 16),
          _Stepper(
            label: 'Pendenza',
            value: '${formatNumber(_incline)}%',
            onMinus: _incline > 0 ? () => setState(() => _incline -= 0.5) : null,
            onPlus: _incline < 15 ? () => setState(() => _incline += 0.5) : null,
          ),
        ],
        if (_settings.contains(CardioSetting.level)) ...[
          const SizedBox(height: 16),
          _Stepper(
            label: 'Livello',
            value: '$_level',
            onMinus: _level > 1 ? () => setState(() => _level--) : null,
            onPlus: _level < 25 ? () => setState(() => _level++) : null,
          ),
        ],
      ];
}

/// "30\"" → 30, "1'30\" per lato" → 90, "dieci" → null.
int? parseSeconds(String text) {
  final match = RegExp(r"^\s*(?:(\d+)')?\s*(?:(\d+)\x22)?").firstMatch(text);
  final minutes = int.tryParse(match?.group(1) ?? '');
  final seconds = int.tryParse(match?.group(2) ?? '');
  if (minutes == null && seconds == null) return null;
  return (minutes ?? 0) * 60 + (seconds ?? 0);
}

/// "Serie   −  3  +": un'etichetta e un valore con i pulsanti meno e più.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
        IconButton.outlined(tooltip: '$label: meno', onPressed: onMinus, icon: const Icon(Icons.remove)),
        SizedBox(
          width: 76,
          child: Text(value, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        ),
        IconButton.outlined(tooltip: '$label: più', onPressed: onPlus, icon: const Icon(Icons.add)),
      ],
    );
  }
}
