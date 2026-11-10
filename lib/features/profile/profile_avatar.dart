import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/profile_store.dart';

/// Il cerchio del profilo: le iniziali bianche su un gradiente grigio.
/// Senza nome mostra l'icona di una persona.
///
/// Con [settingsBadge] in basso a destra compare un piccolo ingranaggio:
/// dice che toccandolo si aprono le impostazioni (scheda, dieta, pesata).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 36, this.initials, this.settingsBadge = false});

  /// Diametro del cerchio in punti.
  final double size;

  /// Le iniziali da mostrare. null = quelle del profilo salvato.
  /// L'onboarding le passa a mano, mentre l'utente sta ancora scrivendo.
  final String? initials;

  /// true = con l'ingranaggio (nell'header e dove spieghiamo dove toccare).
  final bool settingsBadge;

  @override
  Widget build(BuildContext context) {
    final circle = _circle(context);
    if (!settingsBadge) return circle;

    final colors = Theme.of(context).colorScheme;
    final badge = size * 0.46;
    // Stack: il badge sta sopra al cerchio, spostato in basso a destra.
    // Clip.none lo lascia uscire un po' dal bordo, come i badge delle notifiche.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -badge * 0.45,
            bottom: -badge * 0.35,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                // Un bordo del colore dello sfondo lo stacca dal cerchio grigio.
                border: Border.all(color: colors.surface, width: badge * 0.12),
              ),
              child: Icon(Icons.settings, size: badge * 0.62, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(BuildContext context) {
    // `??`: se initials è null, chiediamo allo store del profilo.
    final text = initials ?? ProfileScope.of(context).initials;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Un gradiente va da un colore all'altro: qui da grigio chiaro
        // (in alto a sinistra) a grigio scuro (in basso a destra).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAEB4BC), Color(0xFF4B525B)],
        ),
      ),
      child: text.isEmpty
          ? Icon(Icons.person, size: size * 0.55, color: Colors.white)
          : Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                // Le lettere crescono insieme al cerchio.
                fontSize: size * 0.4,
                color: Colors.white,
                height: 1,
              ),
            ),
    );
  }
}
