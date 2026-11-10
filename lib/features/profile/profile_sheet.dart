import 'package:flutter/material.dart';

import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/features/diet_editor/diet_editor_page.dart';
import 'package:my_workout/features/plan_editor/plan_editor_page.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';
import 'package:my_workout/features/weigh_in/widgets/weigh_in_day_picker.dart';
import 'package:my_workout/utils/formatters.dart';

/// Apre il pannello del profilo dal basso.
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // showDragHandle: la lineetta in alto per trascinarlo giù.
    showDragHandle: true,
    // Di default il pannello si ferma a 9/16 dello schermo; così invece
    // può crescere quanto il suo contenuto (e scorre se serve).
    isScrollControlled: true,
    builder: (context) => const ProfileSheet(),
  );
}

/// Il pannello del profilo: avatar e nome (con la matita per cambiarlo)
/// e i pulsanti per modificare la scheda, la dieta e il giorno della pesata.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({super.key});

  Future<void> _editName(BuildContext context, ProfileStore profile) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initialName: profile.name),
    );
    // null = l'utente ha premuto Annulla.
    if (name != null) await profile.setName(name);
  }

  Future<void> _editWeighInDay(BuildContext context, ProfileStore profile) async {
    final day = await showDialog<int>(
      context: context,
      builder: (context) => _WeighInDayDialog(initialDay: profile.weighInWeekday),
    );
    if (day != null) await profile.setWeighInWeekday(day);
  }

  /// Chiude il pannello e apre [page] (un editor) sopra le tab. Il
  /// navigator lo prendiamo prima: dopo pop() il pannello (e il suo
  /// context) non c'è più.
  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      // Scorre se il contenuto non ci sta (telefono piccolo o in orizzontale).
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          // min: il pannello è alto solo quanto il suo contenuto.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ProfileAvatar(size: 72)),
            const SizedBox(height: 8),
            // Il nome, con la matita per cambiarlo.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile.name.isEmpty ? 'Senza nome' : profile.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Cambia nome',
                  onPressed: () => _editName(context, profile),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _open(context, const PlanEditorPage()),
              icon: const Icon(Icons.fitness_center),
              label: const Text('Modifica la scheda'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _open(context, const DietEditorPage()),
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Modifica la dieta'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => _editWeighInDay(context, profile),
              icon: const Icon(Icons.monitor_weight_outlined),
              label: Text('Pesata: ogni ${formatWeekday(profile.weighInWeekday)}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il dialog per cambiare nome. È uno StatefulWidget perché possiede un
/// TextEditingController, che va creato una volta e liberato in dispose().
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
      content: WeighInDayPicker(value: _day, onChanged: (day) => setState(() => _day = day)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_day), child: const Text('Salva')),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initialName});

  final String initialName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Il tuo nome'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Es. Mario Rossi'),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
