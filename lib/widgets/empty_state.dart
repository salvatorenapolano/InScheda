import 'package:flutter/material.dart';

/// Cosa mostra una tab quando non ha ancora dati: un'icona in un cerchio,
/// un titolo e una riga che spiega cosa ci sarà qui.
/// Lo usano Allenamento, Dieta e Spesa al primo avvio.
/// Con [actionLabel] e [onAction] sotto compare anche un pulsante.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
