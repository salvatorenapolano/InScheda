import 'package:flutter/material.dart';

/// Il numero della parte di seduta (1 Riscaldamento → 4 Tapis Roulant),
/// grande e nel font da tabellone: la seduta si legge come una sequenza.
///
/// Ha una larghezza fissa così i titoli accanto restano allineati
/// in colonna, sia dentro le card sia fuori.
class StepNumber extends StatelessWidget {
  const StepNumber(this.number, {super.key});

  final int number;

  static const width = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        '$number',
        style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
