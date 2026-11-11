import 'package:flutter/material.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/features/profile/profile_avatar.dart';
import 'package:my_workout/features/profile/profile_sheet.dart';

/// L'header di tutte le tab: il logo "InScheda" a sinistra, il cerchio del
/// profilo a destra. [bottom] serve alle pagine con le schede (Dieta, Spesa).
///
/// I pulsanti per modificare i dati NON stanno qui (l'header è uguale per
/// tutte le tab): ogni tab li ha accanto al suo titolo (vedi PageTitle).
///
/// Uno Scaffold accetta come appBar solo un PreferredSizeWidget: un widget
/// che sa dire quanto vuole essere alto (preferredSize).
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key, this.bottom});

  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppBar(
      // Text.rich: un testo fatto di pezzi con stili diversi.
      // Tutto in Russo One (il font del logo); "Scheda" col colore principale.
      // ("Stare in scheda" = seguire il programma: da qui il nome.)
      title: Text.rich(
        TextSpan(
          style: const TextStyle(fontFamily: AppTheme.logoFont, fontWeight: FontWeight.w400),
          children: [
            const TextSpan(text: 'In'),
            TextSpan(text: 'Scheda', style: TextStyle(color: primary)),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Profilo',
          onPressed: () => showProfileSheet(context),
          icon: const ProfileAvatar(),
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}
