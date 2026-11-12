import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_workout/data/focus_store.dart';
import 'package:my_workout/features/focus/focus_actions.dart';
import 'package:my_workout/utils/formatters.dart';

/// I colori della modalità Focus: il verde del pulsante "Inizia" e
/// l'arancione del bagliore ai bordi e del cronometro.
abstract final class FocusColors {
  static const start = Color(0xFF2E9E4F);
  static const glow = Color(0xFFFF8A3D);
}

/// Ridisegna [builder] ogni secondo: serve a tutto ciò che mostra il
/// cronometro o il recupero che scorrono.
///
/// Il Timer.periodic è la "sveglia" che suona ogni secondo; va spenta in
/// dispose(), altrimenti continuerebbe a suonare anche a pagina chiusa.
class FocusTicker extends StatefulWidget {
  const FocusTicker({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<FocusTicker> createState() => _FocusTickerState();
}

class _FocusTickerState extends State<FocusTicker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // setState(() {}) senza cambiare niente: basta a far rieseguire build(),
    // che rilegge l'ora e mostra il secondo nuovo.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// La "pillola" colorata dei banner: icona e una parola ("Inizia",
/// "Termina"), accanto al testo del banner.
///
/// La scritta è corta perché accanto al titolo non c'è posto per una frase:
/// quella intera ("Inizia allenamento") la mettiamo nel [tooltip], che
/// compare tenendo premuto e che TalkBack/VoiceOver leggono ad alta voce.
class BannerActionButton extends StatelessWidget {
  const BannerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  /// Il colore di sfondo (la scritta è bianca).
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // StadiumBorder: i lati corti sono mezzi cerchi, cioè una pillola.
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

/// La pillola verde "Inizia" (banner e tutorial).
class StartWorkoutButton extends StatelessWidget {
  const StartWorkoutButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BannerActionButton(
      icon: Icons.play_arrow_rounded,
      label: 'Inizia',
      tooltip: 'Inizia allenamento',
      color: FocusColors.start,
      onPressed: onPressed,
    );
  }
}

/// La "pillola" arancione col cronometro. Solo l'aspetto: i valori glieli
/// passa chi la usa ([FocusClockChip] o il tutorial).
class FocusClockPill extends StatelessWidget {
  const FocusClockPill({super.key, required this.elapsed, this.restLeft});

  final String elapsed;

  /// Il recupero che scorre, se c'è: compare accanto, con la clessidra.
  final String? restLeft;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: FocusColors.glow,
          fontWeight: FontWeight.w700,
          // Cifre a larghezza fissa: il cronometro non "balla".
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final restLeft = this.restLeft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FocusColors.glow.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FocusColors.glow.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: FocusColors.glow),
          const SizedBox(width: 4),
          Text(elapsed, style: style),
          if (restLeft != null) ...[
            const SizedBox(width: 10),
            const Icon(Icons.hourglass_bottom, size: 16, color: FocusColors.glow),
            Text(restLeft, style: style),
          ],
        ],
      ),
    );
  }
}

/// Il cronometro dell'header: compare solo durante il Focus.
/// Toccandolo si apre il pannello con le metriche e "Termina".
class FocusClockChip extends StatelessWidget {
  const FocusClockChip({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = FocusModeScope.of(context);
    if (!focus.isActive) return const SizedBox.shrink();

    return Tooltip(
      message: 'Allenamento in corso',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showFocusSheet(context),
        child: FocusTicker(
          builder: (context) => FocusClockPill(
            elapsed: formatClock(focus.elapsed),
            restLeft: focus.rest == null ? null : formatClock(focus.restLeft),
          ),
        ),
      ),
    );
  }
}

/// Una metrica: icona, valore grande, etichetta piccola.
class FocusMetric extends StatelessWidget {
  const FocusMetric({super.key, required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      // Alta solo quanto il contenuto. Senza, una Column prende TUTTA
      // l'altezza che le danno: in un dialog arriva quasi a tutto lo schermo
      // (è il dialog "lunghissimo" di fine allenamento).
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FocusColors.glow),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          textAlign: TextAlign.center,
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Tre metriche in fila: durata, kcal, recuperi.
class FocusMetricsRow extends StatelessWidget {
  const FocusMetricsRow({super.key, required this.duration, required this.kcal, required this.rests});

  final Duration duration;
  final double kcal;
  final int rests;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: FocusMetric(icon: Icons.timer_outlined, value: formatClock(duration), label: 'durata')),
        Expanded(
          child: FocusMetric(icon: Icons.local_fire_department_outlined, value: formatKcal(kcal), label: 'stimate'),
        ),
        Expanded(child: FocusMetric(icon: Icons.hourglass_bottom, value: '$rests', label: rests == 1 ? 'recupero' : 'recuperi')),
      ],
    );
  }
}

/// Il bagliore arancione ai bordi dello schermo durante il Focus.
///
/// Sta "sopra" tutta l'app (nel builder di MaterialApp), dentro un
/// IgnorePointer: si vede ma non blocca i tocchi.
class FocusGlow extends StatelessWidget {
  const FocusGlow({super.key, required this.child});

  final Widget child;

  /// I test lo spengono: un'animazione infinita non "si assesta" mai.
  static bool animate = true;

  @override
  Widget build(BuildContext context) {
    final active = FocusModeScope.of(context).isActive;
    return Stack(
      children: [
        child,
        if (active) const Positioned.fill(child: IgnorePointer(child: _GlowEdges())),
      ],
    );
  }
}

/// Il bagliore vero e proprio: "respira" piano, più forte e più debole.
/// Esiste solo durante il Focus, quindi l'animazione gira solo allora.
class _GlowEdges extends StatefulWidget {
  const _GlowEdges();

  @override
  State<_GlowEdges> createState() => _GlowEdgesState();
}

// SingleTickerProviderStateMixin: dà all'AnimationController il "battito"
// dello schermo (un tick per frame).
class _GlowEdgesState extends State<_GlowEdges> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
    value: 0.5,
  );

  @override
  void initState() {
    super.initState();
    // reverse: true → va da 0 a 1 e torna indietro, all'infinito.
    if (FocusGlow.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Curva morbida e intensità fra 0,25 e 0,45: si nota, non disturba.
        final t = Curves.easeInOut.transform(_controller.value);
        return CustomPaint(painter: _GlowPainter(FocusColors.glow.withValues(alpha: 0.25 + 0.2 * t)));
      },
    );
  }
}

/// Disegna una linea lungo il bordo e la sfoca: metà del bagliore cade
/// fuori dallo schermo, l'altra metà sfuma verso l'interno.
class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      // MaskFilter.blur: sfoca quello che disegniamo (sigma = quanto).
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final radius = math.min(size.shortestSide / 10, 40.0);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)), paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.color != color;
}
