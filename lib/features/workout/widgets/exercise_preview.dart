import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/models/exercise.dart';

/// L'anteprima colorata di un esercizio (il "badge").
///
/// Gli esercizi della libreria hanno il loro SVG (omino bianco su quadrato
/// colorato). Quelli creati dall'utente no: per loro disegniamo lo stesso
/// quadrato, col colore del gruppo, e l'iniziale del nome al posto dell'omino.
///
/// Con [number] sull'angolo in alto a sinistra compare il numero d'ordine
/// dell'esercizio nella scheda (lo usano la tab Allenamento e l'editor).
class ExercisePreview extends StatelessWidget {
  const ExercisePreview({super.key, required this.exercise, this.size = 48, this.number});

  final Exercise exercise;
  final double size;

  /// Il numero d'ordine (1, 2, 3...), o null per l'anteprima semplice.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final preview = _preview();
    final number = this.number;
    if (number == null) return preview;

    final colors = Theme.of(context).colorScheme;
    // Il cerchietto cresce con l'anteprima: 22 punti su 48.
    final badge = size * 22 / 48;
    // Stack sovrappone i figli uno sull'altro (il primo sta sotto).
    // clipBehavior: Clip.none lascia "sbordare" il cerchietto fuori
    // dall'anteprima, invece di tagliarlo.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        preview,
        Positioned(
          left: -badge * 0.27,
          top: -badge * 0.27,
          child: Container(
            width: badge,
            height: badge,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              // Il bordo del colore della card "stacca" il cerchio dall'immagine.
              border: Border.all(color: Theme.of(context).cardTheme.color ?? colors.surface, width: 2),
            ),
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    // Semantics: il nome viene letto da TalkBack/VoiceOver al posto dell'immagine.
    return Semantics(
      label: 'Anteprima ${exercise.name}',
      child: exercise.custom
          ? Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(exercise.group.color),
                // Lo stesso raggio degli SVG: 26 su un quadrato di 120.
                borderRadius: BorderRadius.circular(size * 26 / 120),
              ),
              child: Text(
                exercise.name.isEmpty ? '?' : exercise.name.characters.first.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.5,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            )
          : SvgPicture.asset(exercise.previewAsset, width: size, height: size),
    );
  }
}
