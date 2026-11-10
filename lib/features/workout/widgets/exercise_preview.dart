import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_workout/models/exercise.dart';

/// L'anteprima colorata di un esercizio (il "badge").
class ExercisePreview extends StatelessWidget {
  const ExercisePreview({super.key, required this.exercise, this.size = 48});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Semantics: il nome viene letto da VoiceOver al posto dell'immagine.
    return Semantics(
      label: 'Anteprima ${exercise.name}',
      child: SvgPicture.asset(
        exercise.previewAsset,
        width: size,
        height: size,
      ),
    );
  }
}
