import 'package:flutter/material.dart';

import 'package:my_workout/data/remote_data.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';
import 'package:my_workout/utils/formatters.dart';

/// Apre il pannello del profilo dal basso.
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // showDragHandle: la lineetta in alto per trascinarlo giù.
    showDragHandle: true,
    builder: (context) => const ProfileSheet(),
  );
}

/// Il pannello del profilo: quali dati sta usando l'app e il pulsante
/// per scaricare gli ultimi (scheda, dieta, spesa e immagini) da GitHub.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key});

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  // Avanzamento del download: (file fatti, file totali). null = fermo.
  (int, int)? _progress;

  // L'esito dell'ultimo tentativo, da mostrare sotto il pulsante.
  String? _message;
  bool _failed = false;

  Future<void> _update(DataStore store) async {
    setState(() {
      _message = null;
      _progress = (0, 0);
    });
    final result = await store.update(
      onProgress: (done, total) {
        if (mounted) setState(() => _progress = (done, total));
      },
    );
    // Dopo un `await` la pagina potrebbe essere stata chiusa:
    // `mounted` dice se questo State è ancora sullo schermo.
    if (!mounted) return;
    // Il record (testo, errore?) si "spacchetta" in due variabili locali.
    final (message, failed) = switch (result) {
      AlreadyUpToDate() => ('Hai già i dati più recenti.', false),
      Updated(downloaded: 0) => ('Dati aggiornati.', false),
      Updated(:final downloaded) =>
        ('Dati aggiornati: ${downloaded == 1 ? '1 file nuovo' : '$downloaded file nuovi'}.', false),
      UpdateFailed(:final message) => ('Non riesco ad aggiornare: $message', true),
    };
    setState(() {
      _progress = null;
      _message = message;
      _failed = failed;
    });
  }

  Future<void> _reset(DataStore store) async {
    await store.reset();
    if (!mounted) return;
    setState(() {
      _message = 'Ora usi i dati con cui è stata installata l\'app.';
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = DataScope.of(context);
    final info = store.info;
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final progress = _progress;
    final message = _message;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          // min: il pannello è alto solo quanto il suo contenuto.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: ProfileAvatar(size: 72)),
            const SizedBox(height: 20),
            Text('Dati di scheda e dieta', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              info == null
                  ? 'Stai usando i dati con cui è stata installata l\'app.'
                  : 'Scaricati da GitHub, versione di ${formatDayMonth(info.date.toLocal())}'
                      '${info.message.isEmpty ? '' : ':\n“${info.message}”'}',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              // onPressed null = pulsante spento mentre scarica.
              onPressed: store.busy ? null : () => _update(store),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Scarica gli ultimi dati'),
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              // value null = barra "indeterminata" che scorre: all'inizio
              // non sappiamo ancora quanti file ci sono.
              LinearProgressIndicator(
                value: progress.$2 == 0 ? null : progress.$1 / progress.$2,
              ),
              const SizedBox(height: 4),
              Text(
                progress.$2 == 0 ? 'Controllo su GitHub…' : 'File ${progress.$1} di ${progress.$2}',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _failed ? theme.colorScheme.error : secondary,
                ),
              ),
            ],
            if (info != null && !store.busy) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _reset(store),
                child: const Text('Torna ai dati dell\'app'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
