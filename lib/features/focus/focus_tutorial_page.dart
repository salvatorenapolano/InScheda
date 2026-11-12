import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/features/focus/widgets/focus_widgets.dart';
import 'package:my_workout/features/focus/workout_history_page.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';
import 'package:my_workout/widgets/status_banner.dart';

/// Il piccolo tutorial della modalità Focus: compare una volta, subito dopo
/// l'onboarding, e si riapre dal profilo ("Come funziona il Focus").
///
/// Ogni pagina disegna un pezzetto VERO dell'app (il pulsante verde, il
/// cronometro arancione...), così poi lo riconosci al primo colpo.
class FocusTutorialPage extends StatefulWidget {
  const FocusTutorialPage({super.key, required this.onDone});

  /// Chiamato da "Ho capito" e da "Salta".
  final VoidCallback onDone;

  @override
  State<FocusTutorialPage> createState() => _FocusTutorialPageState();
}

class _FocusTutorialPageState extends State<FocusTutorialPage> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _steps = [
    _Step(
      title: 'Modalità Focus',
      text: 'Il giorno dell\'allenamento tocca "Inizia" nel riquadro '
          'in alto della tab Allenamento.',
      picture: const IgnorePointer(
        child: StatusBanner(
          icon: Icons.fitness_center,
          title: 'Oggi: Push',
          subtitle: 'Petto e spalle',
          highlighted: true,
          action: StartWorkoutButton(onPressed: _noop),
        ),
      ),
    ),
    _Step(
      title: 'Il cronometro',
      text: 'Parte il cronometro: lo vedi in alto, fra il logo e il tuo profilo. '
          'I bordi arancioni ti ricordano che sei in Focus.',
      picture: const _HeaderPreview(),
    ),
    _Step(
      title: 'Il recupero',
      text: 'Nel dettaglio di un esercizio, al posto del video, c\'è il timer del '
          'recupero. Quando finisce il telefono vibra; se è in tasca ti arriva una notifica.',
      picture: const _RestPreview(),
    ),
    _Step(
      title: 'Lo storico',
      text: 'Con "Termina" salvi durata e kcal stimate. '
          'Le ritrovi in Storico allenamenti, toccando il cerchio del profilo.',
      picture: const SampleSessionCard(),
    ),
  ];

  static void _noop() {}

  bool get _last => _page == _steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: widget.onDone, child: const Text('Salta')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: [for (final step in _steps) _StepView(step: step)],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? FocusColors.glow : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _last
                      ? widget.onDone
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          ),
                  child: Text(_last ? 'Ho capito' : 'Avanti'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I dati di una pagina del tutorial.
class _Step {
  const _Step({required this.title, required this.text, required this.picture});

  final String title;
  final String text;
  final Widget picture;
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Il "disegno" in un riquadro bordato d'arancione, come lo schermo in Focus.
          Container(
            height: 180,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusHero),
              border: Border.all(color: FocusColors.glow.withValues(alpha: 0.5), width: 2),
              boxShadow: [BoxShadow(color: FocusColors.glow.withValues(alpha: 0.25), blurRadius: 24)],
            ),
            child: step.picture,
          ),
          const SizedBox(height: 32),
          Text(step.title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            step.text,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Un header finto: logo, cronometro e cerchio del profilo.
class _HeaderPreview extends StatelessWidget {
  const _HeaderPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text.rich(
          TextSpan(
            style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppTheme.logoFont, fontWeight: FontWeight.w400),
            children: [
              const TextSpan(text: 'In'),
              TextSpan(text: 'Scheda', style: TextStyle(color: theme.colorScheme.primary)),
            ],
          ),
        ),
        const Expanded(child: Center(child: FocusClockPill(elapsed: '24:18'))),
        const ProfileAvatar(size: 36, initials: 'IO'),
      ],
    );
  }
}

/// Un timer di recupero finto, a metà.
class _RestPreview extends StatelessWidget {
  const _RestPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 0.6,
                strokeWidth: 6,
                color: FocusColors.glow,
                backgroundColor: FocusColors.glow.withValues(alpha: 0.15),
              ),
              const Icon(Icons.hourglass_bottom, color: FocusColors.glow),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recupero in corso', style: theme.textTheme.bodyMedium),
            Text('0:54', style: theme.textTheme.displaySmall?.copyWith(color: FocusColors.glow)),
          ],
        ),
      ],
    );
  }
}
