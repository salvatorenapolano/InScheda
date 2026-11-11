import 'package:flutter/material.dart';

import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';

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

/// Il pannello del profilo: avatar e nome (con la matita per cambiarlo) e
/// il backup dei dati, che arriverà più avanti.
///
/// Scheda, dieta e giorno della pesata NON si cambiano da qui: ognuno ha la
/// sua matita in alto, nella sua tab, vicino ai dati che modifica.
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
            // Il backup su Google Drive arriverà in una prossima versione:
            // il pulsante c'è già, spento, con la spiegazione sotto.
            // onPressed null = pulsante spento.
            FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Backup su Google Drive'),
            ),
            const SizedBox(height: 6),
            Text(
              'In arrivo: salverai scheda, dieta e pesate nel tuo Drive, '
              'per ritrovarle se cambi telefono.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Il dialog per cambiare nome. È uno StatefulWidget perché possiede un
/// TextEditingController, che va creato una volta e liberato in dispose().
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ],
    );
  }
}
