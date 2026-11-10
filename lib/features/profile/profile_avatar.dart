import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';

/// Il cerchio del profilo: iniziali "SN" bianche su un gradiente grigio.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 36});

  /// Diametro del cerchio in punti.
  final double size;

  static const initials = 'SN';

  @override
  Widget build(BuildContext context) {
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
      child: Text(
        initials,
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
