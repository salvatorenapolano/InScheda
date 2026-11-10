import 'package:flutter/material.dart';

/// Il tema dell'app: colori, font, forme e componenti, in chiaro e in scuro.
///
/// Tutto lo stile "globale" sta qui. I singoli widget chiedono i valori con
/// Theme.of(context) invece di scriverli a mano: cambiando questo file si
/// aggiorna tutta l'app in un colpo solo.
abstract final class AppTheme {
  // Il colore "seme": Material 3 ne ricava da solo tutta la palette.
  // Verde petrolio: calmo, e non litiga coi badge colorati degli esercizi.
  static const seedColor = Color(0xFF0E7C86);

  /// Il font "da tabellone" per titoli e numeri (dichiarato nel pubspec).
  /// Il testo normale resta nel font di sistema (SF su iPhone, Roboto su Android).
  static const displayFont = 'Barlow';

  // I raggi degli angoli, dal più grande al più piccolo: più un elemento
  // è importante (o contiene altro), più è arrotondato.
  static const radiusHero = 28.0; // banner del giorno
  static const radiusCard = 20.0; // card e gruppi di righe
  static const radiusInner = 12.0; // riquadri dentro le card

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    // DynamicSchemeVariant.fidelity: la palette resta fedele al seme.
    // Quella predefinita (tonalSpot) lo "smorza" e il petrolio esce grigiastro.
    final colors = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    // Due livelli di superficie, come le liste "raggruppate" di iOS:
    // lo sfondo della pagina e, sopra, le card un po' più in risalto.
    final pageColor = isLight ? colors.surfaceContainerLow : colors.surface;
    final cardColor = isLight ? colors.surfaceContainerLowest : colors.surfaceContainerHigh;

    // Partiamo dal tema standard per avere tutti i testi già colorati
    // giusti, poi cambiamo solo quello che ci serve.
    final base = ThemeData(colorScheme: colors, brightness: brightness);
    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: pageColor,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: pageColor,
        foregroundColor: colors.onSurface,
        // Titolo a sinistra, grande, nel font da tabellone.
        centerTitle: false,
        // Niente cambio di colore quando la lista ci scorre sotto.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        // antiAlias "taglia" i figli lungo la curva: l'effetto onda delle
        // righe toccabili non esce dagli angoli arrotondati.
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),

      // ExpansionTile di default disegna una riga sopra e sotto quando è
      // aperto: dentro una card non servono, quindi bordi vuoti.
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
      ),

      // Il selettore Scheda A / Scheda B: pillola alta, scelta piena.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colors.primary,
          selectedForegroundColor: colors.onPrimary,
          foregroundColor: colors.onSurface,
          backgroundColor: cardColor,
          side: BorderSide(color: colors.outlineVariant),
          minimumSize: const Size(0, 48),
          textStyle: textTheme.titleMedium,
        ),
      ),

      // Le schede Lun…Dom: pillola piena invece della linea sotto.
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(100),
        ),
        labelColor: colors.onPrimary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: textTheme.titleMedium,
        unselectedLabelStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(100),
      ),

      // La barra in basso.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isLight ? colors.surfaceContainerLowest : colors.surfaceContainer,
        indicatorColor: colors.primary,
        indicatorShape: const StadiumBorder(),
        // WidgetStateProperty: un valore diverso a seconda dello "stato"
        // del widget (qui: selezionato oppure no).
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w700)
              : textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }

  /// I testi grandi (titoli, numeri) passano a Barlow; il testo
  /// normale resta quello di sistema.
  static TextTheme _textTheme(TextTheme base) {
    // Una piccola funzione dentro la funzione: evita di ripetere
    // copyWith(fontFamily: ...) per ogni stile.
    TextStyle? display(TextStyle? style, FontWeight weight, {double? size}) =>
        style?.copyWith(fontFamily: displayFont, fontWeight: weight, fontSize: size, height: 1.15);

    return base.copyWith(
      displaySmall: display(base.displaySmall, FontWeight.w700),
      headlineMedium: display(base.headlineMedium, FontWeight.w700),
      headlineSmall: display(base.headlineSmall, FontWeight.w700, size: 26),
      titleLarge: display(base.titleLarge, FontWeight.w600),
      titleMedium: display(base.titleMedium, FontWeight.w600, size: 18),
      // Testo lungo un po' più arioso: si legge meglio.
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    );
  }
}
