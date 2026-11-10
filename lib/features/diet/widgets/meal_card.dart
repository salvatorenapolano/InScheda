import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/models/diet.dart';

/// Un pasto: "☀️ Pranzo · 13:00", il titolo e gli ingredienti con le grammature.
class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.diet, required this.meal});

  final Diet diet;
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = meal.description;
    final alternative = meal.alternative;
    final slot = diet.slotFor(meal);
    final tint = _SlotTint.of(context, slot.id);
    final emoji = slot.emoji;
    // Il colore dell'etichetta, usato anche per divisore e pallini.
    final accent = tint?.accent ?? colors.primary;

    return Card(
      margin: EdgeInsets.zero,
      // Sfondo tenue: giallo a pranzo, blu a cena.
      color: tint?.background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione centrata: Center mette il figlio al centro dello
            // spazio orizzontale, anche se la Column esterna allinea a sinistra.
            Center(
              child: Column(
                children: [
                  Text(
                    // `?emoji`: mette l'emoji nella lista solo se non è null.
                    [?emoji, slot.label].join('  '),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // textAlign serve se il titolo va a capo su più righe.
                  Text(
                    meal.title,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Divider: una linea sottile orizzontale. `height` è lo spazio
            // verticale totale che occupa (la linea sta nel mezzo).
            Divider(height: 20, color: accent.withValues(alpha: 0.3)),
            for (final item in meal.items)
              _ItemRow(food: diet.foodFor(item), item: item, bulletColor: accent),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
            // Regole numerate: .indexed dà (posizione, regola).
            for (final (index, rule) in meal.rules.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${index + 1}. $rule', style: theme.textTheme.bodyMedium),
              ),
            if (alternative != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                ),
                child: Text(
                  alternative,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSecondaryContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// I colori di un momento della giornata: sfondo della card e colore
/// dell'etichetta. Ce n'è una versione per il tema chiaro e una per lo scuro.
class _SlotTint {
  const _SlotTint({required this.background, required this.accent});

  final Color background;
  final Color accent;

  /// null = nessuna tinta speciale (es. "Pranzo e cena" della domenica).
  static _SlotTint? of(BuildContext context, String slotId) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (slotId) {
      'pranzo' => dark
          ? const _SlotTint(background: Color(0xFF3A3115), accent: Color(0xFFFFD25E))
          : const _SlotTint(background: Color(0xFFFFF5D6), accent: Color(0xFF8A5A00)),
      'cena' => dark
          ? const _SlotTint(background: Color(0xFF1B2440), accent: Color(0xFFA9C2FF))
          : const _SlotTint(background: Color(0xFFE6EDFF), accent: Color(0xFF2747A8)),
      _ => null,
    };
  }
}

/// "• Tonno al naturale (sgocciolato) ........ 80 g"
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.food, required this.item, required this.bulletColor});

  final Food food;
  final MealItem item;

  /// Il colore del pallino dell'elenco (giallo scuro a pranzo, blu a cena).
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final note = item.note;
    final amount = item.amountLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Il pallino: stesso stile del testo, così resta allineato
          // alla prima riga anche quando il nome va a capo.
          Text('•  ', style: theme.textTheme.bodyLarge?.copyWith(color: bulletColor)),
          Expanded(
            // Text.rich: un solo testo con pezzi in stili diversi.
            child: Text.rich(
              TextSpan(
                text: food.name,
                children: [
                  if (note != null)
                    TextSpan(text: ' · $note', style: TextStyle(color: secondary)),
                ],
              ),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 12),
            Text(amount, style: theme.textTheme.bodyLarge?.copyWith(color: secondary)),
          ],
        ],
      ),
    );
  }
}
