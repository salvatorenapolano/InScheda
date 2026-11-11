import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/profile_store.dart';

/// Il cerchio del profilo: le iniziali bianche su un gradiente grigio.
/// Senza nome mostra l'icona di una persona.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 36, this.initials});

  /// Diametro del cerchio in punti.
  final double size;

  /// Le iniziali da mostrare. null = quelle del profilo salvato.
  /// L'onboarding le passa a mano, mentre l'utente sta ancora scrivendo.
  final String? initials;

  @override
  Widget build(BuildContext context) {
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
