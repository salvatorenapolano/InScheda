import 'package:flutter/material.dart';

import 'package:my_workout/features/shopping/widgets/department_badge.dart';
import 'package:my_workout/models/shopping.dart';

/// Il dialog per un reparto tuo: nome, colore e icona.
/// Restituisce il reparto scritto (l'id lo decide la bozza), o null se annulli.
class DepartmentDialog extends StatefulWidget {
  const DepartmentDialog({super.key, this.department});

  /// null = reparto nuovo.
  final ShoppingDepartment? department;

  @override
  State<DepartmentDialog> createState() => _DepartmentDialogState();
}

class _DepartmentDialogState extends State<DepartmentDialog> {
  late final _name = TextEditingController(text: widget.department?.name);
  late int _color = widget.department?.color ?? ShoppingDepartment.palette.first;
  late String _icon = widget.department?.icon ?? 'basket';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      ShoppingDepartment(id: widget.department?.id ?? '', name: name, color: _color, icon: _icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: Text(widget.department == null ? 'Nuovo reparto' : 'Reparto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.department == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome del reparto', hintText: 'Es. Animali'),
            ),
            const SizedBox(height: 20),
            Text('Colore', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in ShoppingDepartment.palette)
                  // Semantics: lo screen reader legge "Colore 3, selezionato".
                  Semantics(
                    label: 'Colore ${ShoppingDepartment.palette.indexOf(color) + 1}',
                    selected: color == _color,
                    button: true,
                    child: InkResponse(
                      onTap: () => setState(() => _color = color),
                      radius: 22,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(color),
                          shape: BoxShape.circle,
                          // Il colore scelto ha un anello attorno, oltre alla spunta.
                          border: color == _color ? Border.all(color: colors.onSurface, width: 2.5) : null,
                        ),
                        child: color == _color ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icona', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in ShoppingDepartment.icons)
                  Semantics(
                    label: 'Icona $icon',
                    selected: icon == _icon,
                    button: true,
                    child: InkWell(
                      onTap: () => setState(() => _icon = icon),
                      borderRadius: BorderRadius.circular(12),
                      // L'icona scelta si vede già col colore scelto: è
                      // l'anteprima di come apparirà il reparto.
                      child: icon == _icon
                          ? DepartmentBadge(
                              department: ShoppingDepartment(id: '', name: '', color: _color, icon: icon),
                              size: 40,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(departmentIcons[icon], color: colors.onSurfaceVariant, size: 22),
                            ),
                    ),
                  ),
              ],
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
            child: const Text('Salva'),
          ),
        ),
      ],
    );
  }
}
