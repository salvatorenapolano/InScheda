import 'package:flutter/material.dart';

import 'package:my_workout/features/shopping/widgets/department_badge.dart';
import 'package:my_workout/features/shopping_editor/department_dialog.dart';
import 'package:my_workout/features/shopping_editor/shopping_draft.dart';
import 'package:my_workout/models/shopping.dart';
import 'package:my_workout/utils/search.dart';

/// Il dialog per un prodotto: nome (con i suggerimenti), quantità, reparto
/// e, solo se serve, una nota.
///
/// Invece di restituire il prodotto con pop(), chiama [onSave]: così
/// "Aggiungi e continua" può aggiungerne uno dopo l'altro senza chiudersi.
class ShoppingItemDialog extends StatefulWidget {
  const ShoppingItemDialog({
    super.key,
    required this.draft,
    required this.departmentId,
    required this.suggestions,
    required this.onSave,
    this.item,
  });

  /// Serve per l'elenco dei reparti e per crearne uno nuovo.
  final ShoppingDraft draft;

  /// Il reparto già scelto quando si apre.
  final String departmentId;

  /// I nomi da suggerire mentre scrivi (alimenti della dieta, prodotti già scritti).
  final List<String> suggestions;

  final void Function(ShoppingItemDraft item, String departmentId) onSave;

  /// null = prodotto nuovo.
  final ShoppingItemDraft? item;

  @override
  State<ShoppingItemDialog> createState() => _ShoppingItemDialogState();
}

class _ShoppingItemDialogState extends State<ShoppingItemDialog> {
  /// Il valore finto della voce "Nuovo reparto…" nel menu dei reparti.
  static const _newDepartment = '__nuovo__';

  late final _name = TextEditingController(text: widget.item?.name);
  late final _quantity = TextEditingController(text: widget.item?.quantity);
  late final _note = TextEditingController(text: widget.item?.note);
  final _nameFocus = FocusNode();

  late String _department = widget.departmentId;

  /// La nota è nascosta finché non la chiedi (o finché non ce n'è già una):
  /// un campo in meno da guardare.
  late bool _showNote = widget.item?.note != null;

  /// L'ultimo prodotto aggiunto con "Aggiungi e continua", per dirtelo.
  String? _lastAdded;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    for (final controller in [_name, _quantity, _note]) {
      controller.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  /// Il prodotto scritto, o null se manca il nome.
  ShoppingItemDraft? _read() {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return ShoppingItemDraft(name: name, quantity: orNull(_quantity), note: orNull(_note), id: widget.item?.id);
  }

  void _save() {
    final item = _read();
    if (item == null) return;
    widget.onSave(item, _department);
    Navigator.of(context).pop();
  }

  /// Aggiunge e svuota i campi per il prossimo: il reparto resta quello.
  void _saveAndContinue() {
    final item = _read();
    if (item == null) return;
    widget.onSave(item, _department);
    setState(() {
      _lastAdded = item.name;
      _showNote = false;
    });
    for (final controller in [_name, _quantity, _note]) {
      controller.clear();
    }
    _nameFocus.requestFocus();
  }

  Future<void> _createDepartment() async {
    final written = await showDialog<ShoppingDepartment>(
      context: context,
      builder: (context) => const DepartmentDialog(),
    );
    if (written == null) return;
    final created = widget.draft.addDepartment(name: written.name, color: written.color, icon: written.icon);
    setState(() => _department = created.id);
  }

  /// I suggerimenti per quello che hai scritto finora (al massimo 5).
  Iterable<String> _options(TextEditingValue value) {
    final query = value.text.trim();
    if (query.isEmpty) return const [];
    final typed = normalizeForSearch(query);
    return widget.suggestions
        .where((s) => normalizeForSearch(s) != typed && matchesSearch(query, [s]))
        .take(5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return AlertDialog(
      title: Text(_isNew ? 'Nuovo prodotto' : 'Prodotto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RawAutocomplete: un campo di testo con, sotto, un elenco di
            // suggerimenti che si aggiorna mentre scrivi. Gli passiamo il
            // NOSTRO controller, così possiamo leggerlo e svuotarlo.
            RawAutocomplete<String>(
              textEditingController: _name,
              focusNode: _nameFocus,
              optionsBuilder: _options,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: _isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Prodotto', hintText: 'Es. Latte'),
                onSubmitted: (_) => onSubmitted(),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(dense: true, title: Text(option), onTap: () => onSelected(option)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Quantità (facoltativa)', hintText: 'Es. 500 g, 2 buste'),
            ),
            const SizedBox(height: 12),
            // InputDecorator dà al menu la stessa cornice ed etichetta dei
            // campi di testo sopra.
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Reparto', contentPadding: EdgeInsets.fromLTRB(12, 4, 8, 4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _department,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final department in widget.draft.departments)
                      DropdownMenuItem(
                        value: department.id,
                        child: Row(
                          children: [
                            DepartmentBadge(department: department, size: 26),
                            const SizedBox(width: 12),
                            Flexible(child: Text(department.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    const DropdownMenuItem(
                      value: _newDepartment,
                      child: Row(
                        children: [
                          SizedBox(width: 26, child: Icon(Icons.add)),
                          SizedBox(width: 12),
                          Text('Nuovo reparto…'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == _newDepartment) {
                      _createDepartment();
                    } else if (value != null) {
                      setState(() => _department = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_showNote)
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nota', hintText: 'Es. quello senza lattosio'),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() => _showNote = true),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi una nota'),
              ),
            if (_lastAdded case final name?) ...[
              const SizedBox(height: 8),
              Text('Aggiunto: $name', style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(_lastAdded == null ? 'Annulla' : 'Fine')),
        // I pulsanti si accendono solo quando c'è un nome: ascoltano il controller.
        ListenableBuilder(
          listenable: _name,
          builder: (context, _) {
            final ready = _name.text.trim().isNotEmpty;
            return Wrap(
              spacing: 8,
              children: [
                if (_isNew)
                  TextButton(onPressed: ready ? _saveAndContinue : null, child: const Text('Aggiungi e continua')),
                FilledButton(onPressed: ready ? _save : null, child: Text(_isNew ? 'Aggiungi' : 'Salva')),
              ],
            );
          },
        ),
      ],
    );
  }
}
