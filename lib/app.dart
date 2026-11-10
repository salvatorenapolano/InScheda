import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:my_workout/app_theme.dart';
import 'package:my_workout/data/body_weight_store.dart';
import 'package:my_workout/data/profile_store.dart';
import 'package:my_workout/data/shopping_store.dart';
import 'package:my_workout/data/user_data_store.dart';
import 'package:my_workout/data/weight_store.dart';
import 'package:my_workout/features/onboarding/onboarding_page.dart';
import 'package:my_workout/home_shell.dart';

/// Il widget radice: configura tema, titolo e la prima schermata.
///
/// È uno StatelessWidget perché non ha dati che cambiano nel tempo:
/// si limita a "descrivere" l'app.
class MyWorkoutApp extends StatelessWidget {
  const MyWorkoutApp({
    super.key,
    required this.weights,
    required this.bodyWeights,
    required this.shopping,
    required this.profile,
    required this.userData,
    this.assets,
  });

  /// I pesi salvati: li mettiamo "sopra" tutta l'app con WeightScope,
  /// così ogni schermata li può leggere con WeightScope.of(context).
  final WeightStore weights;

  /// Lo storico delle pesate settimanali (tab Pesata).
  final BodyWeightStore bodyWeights;

  /// Le spunte della lista della spesa (tab Spesa).
  final ShoppingStore shopping;

  /// Nome dell'utente e se ha già fatto l'onboarding.
  final ProfileStore profile;

  /// La scheda e la dieta create dall'utente: vincono sugli asset.
  final UserDataStore userData;

  /// Il piano più basso dei dati: i file dentro l'app (rootBundle).
  /// I test ci mettono un bundle coi loro dati di prova.
  final AssetBundle? assets;

  @override
  Widget build(BuildContext context) {
    // Gli "scope" uno dentro l'altro: ognuno rende disponibile il suo store.
    return ProfileScope(
      store: profile,
      child: UserDataScope(
        store: userData,
        child: WeightScope(
          store: weights,
          child: BodyWeightScope(
            store: bodyWeights,
            child: ShoppingScope(
              store: shopping,
              // ListenableBuilder ridisegna l'app quando il ProfileStore
              // (onboarding finito) o lo UserDataStore (scheda o dieta
              // salvate) chiamano notifyListeners(). Listenable.merge li
              // ascolta tutti e due insieme.
              child: ListenableBuilder(
                listenable: Listenable.merge([profile, userData]),
                builder: (context, _) => _buildApp(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'InScheda',
      debugShowCheckedModeBanner: false,
      // L'app è in italiano: anche i pezzi di Flutter (il calendario per
      // scegliere una data, i tooltip, "OK"/"Annulla") devono esserlo.
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Colori, font e forme stanno tutti in app_theme.dart.
      // Per provare un altro colore seme cambia AppTheme.seedColor.
      theme: AppTheme.light(),
      // Tema scuro: l'app lo usa da sola se il telefono è in modalità scura.
      darkTheme: AppTheme.dark(),
      // DefaultAssetBundle: da qui in giù Image.asset, SvgPicture.asset e i
      // repository leggono i file dal bundle dei dati: prima quelli
      // dell'utente, poi quelli dell'app.
      builder: (context, child) => DefaultAssetBundle(
        bundle: userData.bundleOver(assets ?? rootBundle),
        child: child!,
      ),
      // La Key cambia quando cambiano i dati: Flutter butta via le pagine
      // vecchie e ne crea di nuove, che rileggono scheda, dieta e spesa.
      // Al primo avvio l'onboarding, poi sempre le tab.
      home: profile.onboardingDone
          ? HomeShell(key: ValueKey(userData.revision))
          : const OnboardingPage(),
    );
  }
}
