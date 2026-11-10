import 'package:flutter/material.dart';

import 'package:my_workout/models/body_weight.dart';
import 'package:my_workout/utils/formatters.dart';
import 'package:my_workout/widgets/status_banner.dart';

/// Il riquadro in cima alla tab Pesata: "Oggi ti devi pesare" il venerdì,
/// altrimenti quando tocca la prossima. Solo il titolo, senza descrizione.
///
/// Come TodayBanner riceve `now`, così nei test possiamo fingere che sia
/// venerdì, sabato o un altro giorno.
class WeighInBanner extends StatelessWidget {
  const WeighInBanner({super.key, required this.entries, required this.now});

  /// Le pesate, dalla più recente.
  final List<BodyWeightEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Uno switch su una classe `sealed`: Dart controlla che ci siano tutti
    // e quattro i casi. `WeighInDoneToday(:final kg)` "estrae" il campo kg
    // dall'oggetto e lo mette in una variabile (pattern matching).
    final (IconData icon, String title, bool highlighted) = switch (weighInStatusFor(entries, now)) {
      WeighInDueToday() => (Icons.monitor_weight, 'Oggi ti devi pesare', true),
      WeighInMissed() => (Icons.monitor_weight, 'Pesata di venerdì da fare', true),
      WeighInDoneToday(:final kg) => (Icons.check_circle_outline, 'Pesata fatta: ${formatWeight(kg)}', false),
      WeighInUpcoming(:final date) => (
          Icons.event_outlined,
          'Prossima pesata ${formatRelativeDay(date, now: now)}',
          false,
        ),
    };

    return StatusBanner(
      icon: icon,
      title: title,
      highlighted: highlighted,
      // La bilancia gigante sullo sfondo, solo quando c'è da pesarsi.
      watermark: highlighted ? const Icon(Icons.monitor_weight) : null,
    );
  }
}
