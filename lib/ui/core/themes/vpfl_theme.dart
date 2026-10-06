import 'package:flutter/material.dart';

import 'vpfl_theme_extension.dart';
import 'vpfl_typography.dart';

/// Builds the default light and dark VPFL themes.
abstract final class VpflTheme {
  static const _lightTokens = VpflThemeExtension(
    topBarBackground: Color(0xFFFCFCFD),
    sidebarBackground: Color(0xFFF0F2F4),
    sidebarSelected: Color(0xFFE1E6EA),
    sidebarHover: Color(0xFFE8ECEF),
    sidebarFocus: Color(0xFFC73139),
    cardSurface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE0E4E8),
    cardBorderActive: Color(0xFFAAB4BD),
    cardArtworkTop: Color(0xFFDCE2E6),
    cardArtworkBottom: Color(0xFFC8D1D7),
    cardOverlay: Color(0xA610141A),
    playbackProgress: Color(0xFFD32832),
    playerControlSurface: Color(0xFFF8F9FA),
    playerControlForeground: Color(0xFF15171B),
    playerBackground: Color(0xFF080A0E),
    playerOverlayForeground: Color(0xFFFFFFFF),
    playerOverlayTop: Color(0xC9000000),
    playerOverlayMiddle: Color(0x52000000),
    playerOverlayBottom: Color(0xD9000000),
    playerEdgeBackground: Color(0x83000000),
  );

  static const _darkTokens = VpflThemeExtension(
    topBarBackground: Color(0xFF1A1D22),
    sidebarBackground: Color(0xFF191C21),
    sidebarSelected: Color(0xFF30353D),
    sidebarHover: Color(0xFF272C33),
    sidebarFocus: Color(0xFFF06369),
    cardSurface: Color(0xFF20242A),
    cardBorder: Color(0xFF353A42),
    cardBorderActive: Color(0xFF65717D),
    cardArtworkTop: Color(0xFF38414A),
    cardArtworkBottom: Color(0xFF292F37),
    cardOverlay: Color(0xA610141A),
    playbackProgress: Color(0xFFF04A53),
    playerControlSurface: Color(0xFFF8F9FA),
    playerControlForeground: Color(0xFF15171B),
    playerBackground: Color(0xFF080A0E),
    playerOverlayForeground: Color(0xFFFFFFFF),
    playerOverlayTop: Color(0xC9000000),
    playerOverlayMiddle: Color(0x52000000),
    playerOverlayBottom: Color(0xD9000000),
    playerEdgeBackground: Color(0x83000000),
  );

  /// The default light appearance.
  static ThemeData get light => _create(Brightness.light, _lightTokens);

  /// The default dark appearance.
  static ThemeData get dark => _create(Brightness.dark, _darkTokens);

  static ThemeData _create(Brightness brightness, VpflThemeExtension tokens) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF15171B) : const Color(0xFFF7F8F9);
    final onSurface = dark ? const Color(0xFFF3F4F5) : const Color(0xFF20242A);
    final onSurfaceVariant = dark
        ? const Color(0xFFADB5BF)
        : const Color(0xFF606A75);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFC73139),
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: dark ? const Color(0xFFF06369) : const Color(0xFFC73139),
          onPrimary: const Color(0xFFFFFFFF),
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          surfaceContainerLow: dark
              ? const Color(0xFF1A1D22)
              : const Color(0xFFFCFCFD),
          surfaceContainer: dark
              ? const Color(0xFF252A31)
              : const Color(0xFFECEFF1),
          surfaceContainerHigh: dark
              ? const Color(0xFF30353D)
              : const Color(0xFFE4E8EB),
          surfaceContainerHighest: dark
              ? const Color(0xFF3A414A)
              : const Color(0xFFD8DEE2),
          secondaryContainer: tokens.sidebarSelected,
          onSecondaryContainer: onSurface,
          outlineVariant: tokens.cardBorder,
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
      sliderTheme: SliderThemeData(
        activeTrackColor: onSurfaceVariant,
        inactiveTrackColor: tokens.cardBorder,
        thumbColor: onSurface,
        trackHeight: 3,
      ),
      extensions: [tokens],
      useMaterial3: true,
    );
  }
}
