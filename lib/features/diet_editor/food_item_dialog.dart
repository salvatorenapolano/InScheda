import 'package:flutter/material.dart';

import 'package:my_workout/features/diet_editor/diet_draft.dart';
import 'package:my_workout/utils/formatters.dart';

/// Il dialog per un alimento: nome, quantità (anche "250-300"), unità e nota.
/// Restituisce il FoodItemDraft, o null se annulli.
class FoodItemDialog extends StatefulWidget {
  const FoodItemDialog({super.key, this.item});

  /// null = alimento nuovo.
  final FoodItemDraft? item;

  @override
  State<FoodItemDialog> createState() => _FoodItemDialogState();
}

class _FoodItemDialogState extends State<FoodItemDialog> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _quantity = TextEditingController(text: _quantityText(widget.item));
  late final _unit = TextEditingController(text: widget.item == null ? 'g' : widget.item?.unit);
  late final _note = TextEditingController(text: widget.item?.note);

  @override
  void dispose() {
    for (final controller in [_name, _quantity, _unit, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// La quantità come testo da modificare: 250 e 300 → "250–300".
  static String? _quantityText(FoodItemDraft? item) {
    final q = item?.quantity;
    if (q == null) return null;
    final max = item?.quantityMax;
    return max == null ? formatNumber(q) : '${formatNumber(q)}–${formatNumber(max)}';
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final (quantity, max) = parseQuantity(_quantity.text);
    final unit = _unit.text.trim();
    final note = _note.text.trim();
    Navigator.of(context).pop(
      FoodItemDraft(
        name: name,
        quantity: quantity,
        quantityMax: max,
        // Senza quantità l'unità non ha senso ("g" da solo).
        unit: quantity == null || unit.isEmpty ? null : unit,
        note: note.isEmpty ? null : note,
        foodId: widget.item?.foodId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Nuovo alimento' : 'Alimento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.item == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Alimento', hintText: 'Es. Petto di pollo'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantità', hintText: '90 o 250-300'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unità', hintText: 'g, ml, pz'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Nota (facoltativa)', hintText: 'Es. sgocciolato'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        // Il pulsante si accende solo quando c'è un nome: ascolta il controller.
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) => FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _save,
            child: const Text('Salva'),
          ),
        ),
      ],
    );
  }
}

/// "90" → (90, null)   "1,5" → (1.5, null)   "250-300" → (250, 300)
/// Testo vuoto o non valido → (null, null): l'alimento resta senza quantità.
(double?, double?) parseQuantity(String text) {
  // Una RegExp: un numero (con virgola o punto), poi facoltativo un
  // trattino (- o –) e un secondo numero. I gruppi tra parentesi si
  // leggono con match.group(1) e match.group(2).
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(?:[-–]\s*(\d+(?:[.,]\d+)?))?\s*$').firstMatch(text);
  if (match == null) return (null, null);
  double toDouble(String s) => double.parse(s.replaceAll(',', '.'));
  final min = toDouble(match.group(1)!);
  final maxText = match.group(2);
  final max = maxText == null ? null : toDouble(maxText);
  // "300-250" o "90-90" non sono intervalli: teniamo solo il primo numero.
  return (min, max != null && max > min ? max : null);
}
