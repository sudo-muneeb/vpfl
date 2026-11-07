import 'package:flutter/material.dart';

import 'vpfl_theme_extension.dart';
import 'vpfl_typography.dart';

/// Shared Obsidian, Porcelain, and brand colors.
abstract final class VpflColors {
  static const brandRed = Color(0xFFF2384D);
  static const actionRed = Color(0xFFCF2440);
  static const subtleRed = Color(0xFFFCE8EC);
  static const darkBackground = Color(0xFF0B0D10);
  static const darkSidebar = Color(0xFF080A0D);
  static const darkSurface = Color(0xFF1C2027);
  static const darkHover = Color(0xFF292E36);
  static const darkArtwork = Color(0xFF24282E);
  static const darkBorder = Color(0xFF383E48);
  static const darkText = Color(0xFFF7F8FA);
  static const darkSecondaryText = Color(0xFFA9B0BA);
  static const darkMutedText = Color(0xFF77818E);
  static const lightBackground = Color(0xFFF8F9FB);
  static const lightSidebar = Color(0xFFF0F2F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightHover = Color(0xFFE9EDF2);
  static const lightArtwork = Color(0xFFE5E8EC);
  static const lightBorder = Color(0xFFDCE1E7);
  static const lightText = Color(0xFF181B20);
  static const lightSecondaryText = Color(0xFF626C79);
  static const lightMutedText = Color(0xFF818A96);
  static const popupBlack = Color(0xFF080A0D);
}

/// Builds the default light and dark VPFL themes.
abstract final class VpflTheme {
  static const _lightTokens = VpflThemeExtension(
    topBarBackground: VpflColors.lightSurface,
    sidebarBackground: VpflColors.lightSidebar,
    sidebarSelected: VpflColors.lightHover,
    sidebarHover: VpflColors.lightHover,
    sidebarFocus: VpflColors.actionRed,
    cardSurface: VpflColors.lightSurface,
    cardBorder: VpflColors.lightBorder,
    cardBorderActive: VpflColors.lightSecondaryText,
    cardArtworkTop: VpflColors.lightArtwork,
    cardArtworkBottom: VpflColors.lightArtwork,
    playbackProgress: VpflColors.actionRed,
    playerControlSurface: VpflColors.lightSurface,
    playerControlForeground: VpflColors.lightText,
    playerBackground: VpflColors.darkBackground,
    playerOverlayForeground: VpflColors.darkText,
    playerOverlayTop: VpflColors.popupBlack,
    playerEdgeBackground: VpflColors.popupBlack,
    playerMenuBackground: VpflColors.popupBlack,
  );

  static const _darkTokens = VpflThemeExtension(
    topBarBackground: VpflColors.darkSidebar,
    sidebarBackground: VpflColors.darkSidebar,
    sidebarSelected: VpflColors.darkHover,
    sidebarHover: VpflColors.darkHover,
    sidebarFocus: VpflColors.brandRed,
    cardSurface: VpflColors.darkSurface,
    cardBorder: VpflColors.darkBorder,
    cardBorderActive: VpflColors.darkSecondaryText,
    cardArtworkTop: VpflColors.darkArtwork,
    cardArtworkBottom: VpflColors.darkArtwork,
    playbackProgress: VpflColors.brandRed,
    playerControlSurface: VpflColors.darkSurface,
    playerControlForeground: VpflColors.darkText,
    playerBackground: VpflColors.darkBackground,
    playerOverlayForeground: VpflColors.darkText,
    playerOverlayTop: VpflColors.popupBlack,
    playerEdgeBackground: VpflColors.popupBlack,
    playerMenuBackground: VpflColors.popupBlack,
  );

  /// The default light appearance.
  static ThemeData get light => _create(Brightness.light, _lightTokens);

  /// The default dark appearance.
  static ThemeData get dark => _create(Brightness.dark, _darkTokens);

  static ThemeData _create(Brightness brightness, VpflThemeExtension tokens) {
    final dark = brightness == Brightness.dark;
    final surface = dark
        ? VpflColors.darkBackground
        : VpflColors.lightBackground;
    final onSurface = dark ? VpflColors.darkText : VpflColors.lightText;
    final onSurfaceVariant = dark
        ? VpflColors.darkSecondaryText
        : VpflColors.lightSecondaryText;
    final hover = dark ? VpflColors.darkHover : VpflColors.lightHover;
    final accent = dark ? VpflColors.brandRed : VpflColors.actionRed;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: VpflColors.brandRed,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: const Color(0xFFFFFFFF),
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          surfaceContainerLow: tokens.cardSurface,
          surfaceContainer: tokens.cardSurface,
          surfaceContainerHigh: hover,
          surfaceContainerHighest: hover,
          secondaryContainer: tokens.sidebarSelected,
          onSecondaryContainer: onSurface,
          outline: tokens.cardBorder,
          outlineVariant: tokens.cardBorder,
        );
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: tokens.cardBorder),
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: VpflTypography.family,
      textTheme: VpflTypography.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: tokens.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.playerMenuBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 12,
        shape: menuShape,
        textStyle: VpflTypography.textTheme.bodyMedium?.copyWith(
          color: VpflColors.darkText,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          VpflTypography.textTheme.bodyMedium?.copyWith(
            color: VpflColors.darkText,
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.playerMenuBackground),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(12),
          shape: WidgetStatePropertyAll(menuShape),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.cardBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.playerMenuBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.cardBorder),
        ),
        textStyle: VpflTypography.textTheme.bodySmall?.copyWith(
          color: VpflColors.darkText,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? onSurface
                : onSurfaceVariant,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return hover;
            }
            if (states.contains(WidgetState.hovered)) {
              return hover.withValues(alpha: 0.65);
            }
            return tokens.cardSurface;
          }),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? accent
                  : tokens.cardBorder,
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : hover,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: tokens.cardBorder,
        thumbColor: accent,
        trackHeight: 3,
      ),
      extensions: [tokens],
      useMaterial3: true,
    );
  }
}
