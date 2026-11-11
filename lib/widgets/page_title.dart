import 'package:flutter/material.dart';

/// Il titolo in cima a una tab ("Allenamento", "Dieta", "Pesata") con,
/// accanto, il pulsante per modificarne i dati.
///
/// Il pulsante sta vicino al titolo, non nell'header (che è uguale per
/// tutte le tab): così è chiaro COSA modifica.
class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    this.onEdit,
    this.editTooltip,
    this.editIcon = Icons.edit_outlined,
  });

  final String title;

  /// Cosa fa il pulsante. null = solo il titolo.
  final VoidCallback? onEdit;

  /// Il nome del pulsante, letto dagli screen reader e mostrato tenendolo
  /// premuto ("Modifica la scheda").
  final String? editTooltip;
  final IconData editIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Flexible: se il titolo è lungo va a capo invece di spingere fuori il pulsante.
        Flexible(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
        if (onEdit != null) ...[
          const SizedBox(width: 8),
          // filledTonal: un cerchio colorato tenue attorno all'icona, così
          // si vede che è un pulsante e non una decorazione del titolo.
          IconButton.filledTonal(
            tooltip: editTooltip,
            onPressed: onEdit,
            icon: Icon(editIcon, size: 20),
          ),
        ],
      ],
    );
  }
}
