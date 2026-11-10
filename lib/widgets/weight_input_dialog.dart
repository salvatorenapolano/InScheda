import 'package:flutter/material.dart';

import 'package:my_workout/utils/formatters.dart';

/// Il dialog per scrivere un peso in kg (accetta "22,5" e "22.5").
///
/// Si apre con `showDialog<double>`: restituisce il numero scritto,
/// oppure null se premi Annulla.
///
/// È Stateful perché possiede un TextEditingController, che va creato
/// una volta sola e "smaltito" (dispose) quando il dialog si chiude.
class WeightInputDialog extends StatefulWidget {
  const WeightInputDialog({
    super.key,
    required this.title,
    this.initial,
    this.example = '22,5',
    this.emptyMeansDelete = false,
  });

  final String title;

  /// Il valore già scritto nel campo all'apertura (null = campo vuoto).
  final double? initial;

  /// L'esempio mostrato nel messaggio d'errore ("ad esempio 22,5").
  final String example;

  /// true = campo vuoto e Salva restituisce 0, cioè "cancella il peso"
  /// (serve nel dettaglio esercizio). false = il campo vuoto è un errore.
  final bool emptyMeansDelete;

  @override
  State<WeightInputDialog> createState() => _WeightInputDialogState();
}

class _WeightInputDialogState extends State<WeightInputDialog> {
  // `widget` dà accesso ai campi dello StatefulWidget (title, initial...).
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : formatNumber(widget.initial!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.emptyMeansDelete) {
      Navigator.of(context).pop(0.0); // vuoto = cancella il peso
      return;
    }
    final value = parseNumber(text);
    // Lo zero vale solo quando significa "cancella".
    final valid = value != null && (widget.emptyMeansDelete ? value >= 0 : value > 0);
    if (!valid) {
      setState(() => _error = 'Scrivi un numero, ad esempio ${widget.example}');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: 'kg', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
