import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/features/workout/widgets/exercise_preview.dart';
import 'package:my_workout/models/exercise.dart';

/// In cima al dettaglio: il video YouTube se l'esercizio ne ha uno,
/// altrimenti l'anteprima SVG.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.exercise});

  final Exercise exercise;

  /// `static`: un valore unico condiviso da tutta l'app, non uno per widget.
  /// Nei test non esiste una WebView vera, quindi il player YouTube non può
  /// partire: i test lo mettono a false e vedono l'anteprima SVG.
  static bool videoEnabled = true;

  @override
  Widget build(BuildContext context) {
    final url = videoEnabled ? exercise.videoUrl : null;
    // Dal link completo ("https://www.youtube.com/watch?v=GB2Jgp5FyNE")
    // ricava solo l'id del video ("GB2Jgp5FyNE"). null se il link non è valido.
    final videoId = url == null ? null : YoutubePlayerController.convertUrlToId(url);

    if (videoId == null) {
      return Center(child: ExercisePreview(exercise: exercise, size: 160));
    }
    return ExerciseVideo(videoId: videoId);
  }
}

/// Il player YouTube, con gli angoli arrotondati come le card.
///
/// È Stateful perché possiede un controller: va creato una volta sola
/// (initState) e chiuso quando la pagina se ne va (dispose), altrimenti
/// il video continuerebbe a vivere in memoria.
class ExerciseVideo extends StatefulWidget {
  const ExerciseVideo({super.key, required this.videoId});

  final String videoId;

  @override
  State<ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<ExerciseVideo> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      // autoPlay false: il video è pronto ma parte solo quando tocchi play.
      params: const YoutubePlayerParams(
        interfaceLanguage: 'it',
        captionLanguage: 'it',
        // A fine video suggerisce solo altri video dello stesso canale.
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
    );
  }
}
