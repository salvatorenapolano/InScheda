import 'package:flutter/material.dart';

import 'package:my_workout/models/exercise.dart';

/// La card "Muscoli" del dettaglio: illustrazione a sinistra (col muscolo
/// evidenziato), nomi a destra. Toccandola si apre a schermo intero.
class MuscleCard extends StatelessWidget {
  const MuscleCard({super.key, required this.exercise, required this.asset});

  final Exercise exercise;

  /// Il file dell'illustrazione (exercise.muscleAsset, già controllato non null).
  final String asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => _MuscleFullScreen(exercise: exercise, asset: asset),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Hero: lo stesso "tag" su due pagine fa "volare" l'immagine
              // dalla card allo schermo intero durante il passaggio.
              Hero(
                tag: _heroTag(exercise),
                child: _Illustration(asset: asset, exercise: exercise, height: 240),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Muscoli', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    for (final muscle in exercise.muscles)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('•  $muscle', style: theme.textTheme.bodyLarge),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.zoom_in, size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Tocca per ingrandire',
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un tag unico per esercizio: Hero abbina le immagini con lo stesso tag.
String _heroTag(Exercise exercise) => 'muscoli-${exercise.id}';

/// L'illustrazione: un .webp con lo sfondo trasparente (scontornato da
/// tool/prepare_muscle_images.py), quindi si appoggia direttamente sulla
/// card, in chiaro come in scuro.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.asset, required this.exercise, this.height});

  final String asset;
  final Exercise exercise;

  /// null = prende tutto lo spazio che ha (schermo intero).
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      // contain: l'immagine entra tutta nello spazio, senza tagli
      // né deformazioni.
      fit: BoxFit.contain,
      // Letto da VoiceOver al posto dell'immagine.
      semanticLabel: 'Muscoli coinvolti: ${exercise.muscles.join(', ')}',
    );
  }
}

/// L'illustrazione a schermo intero, con lo zoom a due dita.
class _MuscleFullScreen extends StatelessWidget {
  const _MuscleFullScreen({required this.exercise, required this.asset});

  final Exercise exercise;
  final String asset;

  @override
  Widget build(BuildContext context) {
    // Sfondo e barra in alto vengono dal tema, come nelle altre pagine.
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: SafeArea(
        // InteractiveViewer: pizzica per ingrandire, trascina per spostarti.
        // maxScale 4 = fino a 4 volte la grandezza iniziale.
        child: InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Hero(
              tag: _heroTag(exercise),
              child: _Illustration(asset: asset, exercise: exercise),
            ),
          ),
        ),
      ),
    );
  }
}
