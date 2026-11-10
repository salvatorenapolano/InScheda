import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/models/exercise.dart';

/// L'anteprima colorata di un esercizio (il "badge").
///
/// Gli esercizi della libreria hanno il loro SVG (omino bianco su quadrato
/// colorato). Quelli creati dall'utente no: per loro disegniamo lo stesso
/// quadrato, col colore del gruppo, e l'iniziale del nome al posto dell'omino.
class ExercisePreview extends StatelessWidget {
  const ExercisePreview({super.key, required this.exercise, this.size = 48});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
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
