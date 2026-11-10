import 'package:flutter/material.dart';

import 'package:my_workout/features/diet/widgets/meal_card.dart';
import 'package:my_workout/models/diet.dart';

/// Un giorno della dieta: palestra/riposo, i pasti e le note utili.
class DietDayView extends StatelessWidget {
  const DietDayView({super.key, required this.diet, required this.day});

  final Diet diet;
  final DietDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text(day.name, style: theme.textTheme.headlineSmall)),
            _DayTypeChip(training: day.training),
          ],
        ),
        const SizedBox(height: 12),
        if (day.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nessun pasto segnato per questo giorno.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        for (final meal in day.meals)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MealCard(diet: diet, meal: meal),
          ),
        // Il riquadro dei legumi compare solo nei giorni che li usano
        // (e solo nelle diete che ce l'hanno: quelle dell'editor no).
        if (diet.legumes case final legumes? when day.usesFood('legumi')) _LegumesCard(info: legumes),
        // Il riquadro "Da sapere" è stato tolto: le note (diet.notes)
        // restano nel JSON, pronte se un giorno vorrai rimetterle.
      ],
    );
  }
}

/// Il chip in alto a destra: giallo nei giorni di palestra, bianco a riposo.
class _DayTypeChip extends StatelessWidget {
  const _DayTypeChip({required this.training});

  final bool training;

  // Giallo pieno e testo marrone scuro: si legge bene sia in chiaro
  // sia in scuro, quindi basta una sola coppia di colori.
  static const _yellow = Color(0xFFFFD25E);
  static const _onYellow = Color(0xFF4A3200);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (training) {
      return Chip(
        avatar: const Icon(Icons.fitness_center, size: 18, color: _onYellow),
        label: const Text('Palestra', style: TextStyle(color: _onYellow)),
        backgroundColor: _yellow,
        // BorderSide.none: niente bordo, il giallo basta a delimitarlo.
        side: BorderSide.none,
      );
    }
    return Chip(
      avatar: const Icon(Icons.self_improvement, size: 18),
      label: const Text('Riposo'),
      // In chiaro bianco; in scuro lasciamo il colore del tema, perché
      // un chip bianco su sfondo scuro abbaglierebbe.
      backgroundColor: dark ? null : Colors.white,
      // Il bordo sottile stacca il bianco dallo sfondo della pagina.
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _LegumesCard extends StatelessWidget {
  const _LegumesCard({required this.info});

  final LegumesInfo info;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: info.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in info.options)
                Chip(
                  label: Text(option),
                  // Chip "bianchi" (colore delle card) sul fondo grigio del
                  // riquadro: così si staccano bene.
                  backgroundColor: Theme.of(context).cardTheme.color,
                  // shrinkWrap: niente spazio extra per il tocco, questi chip
                  // non si premono; così le righe stanno più vicine.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Riquadro informativo con lo sfondo leggermente colorato.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Senza ombra (elevation 0) e con uno sfondo tenue preso dal tema:
      // si distingue dalle card dei pasti senza rubare l'attenzione.
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
