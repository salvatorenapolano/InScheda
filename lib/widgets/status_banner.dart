import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';

/// Il riquadro grande in cima alle pagine ("Oggi: Scheda A",
/// "Oggi ti devi pesare"...).
///
/// Quando [highlighted] è true è petrolio pieno (c'è qualcosa da fare oggi),
/// altrimenti è neutro, col colore delle card e un bordo sottile.
/// Lo usano sia la tab Allenamento sia la tab Pesata: stesso aspetto,
/// contenuti diversi.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.highlighted = false,
    this.watermark,
  });

  final IconData icon;
  final String title;

  /// Riga piccola sotto il titolo. null = nessuna riga.
  final String? subtitle;

  final bool highlighted;

  /// Elemento decorativo gigante e semitrasparente in basso a destra
  /// (la lettera della scheda, l'icona della bilancia...). Prende da solo
  /// il colore giusto: qui lo "avvolgiamo" con IconTheme e DefaultTextStyle.
  final Widget? watermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    // In tema scuro il "primary" è un azzurro chiaro: per restare sul
    // petrolio scuro usiamo primaryContainer (e il suo colore di testo).
    final dark = theme.brightness == Brightness.dark;
    final highlightBackground = dark ? colors.primaryContainer : colors.primary;
    final onHighlight = dark ? colors.onPrimaryContainer : colors.onPrimary;

    final background = highlighted ? highlightBackground : theme.cardTheme.color ?? colors.surface;
    final foreground = highlighted ? onHighlight : colors.onSurface;
    final secondary = highlighted ? onHighlight.withValues(alpha: 0.85) : colors.onSurfaceVariant;
    final watermarkColor = foreground.withValues(alpha: highlighted ? 0.2 : 0.08);

    final watermark = this.watermark;
    final subtitle = this.subtitle;

    return Container(
      // clipBehavior: taglia tutto ciò che esce dagli angoli arrotondati
      // (qui il watermark, che "sborda" apposta in basso a destra).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: highlighted ? null : Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: [
          if (watermark != null)
            Positioned(
              right: 12,
              bottom: -34,
              // ExcludeSemantics: è solo decorazione, VoiceOver la salta.
              child: ExcludeSemantics(
                child: IconTheme.merge(
                  data: IconThemeData(color: watermarkColor, size: 150),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: watermarkColor),
                    child: watermark,
                  ),
                ),
              ),
            ),
          Padding(
            // A destra lasciamo spazio al watermark, così il testo non ci finisce sopra.
            padding: EdgeInsets.fromLTRB(20, 20, watermark != null ? 96 : 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: highlighted ? foreground : colors.primary),
                const SizedBox(height: 12),
                Text(title, style: textTheme.headlineSmall?.copyWith(color: foreground)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
