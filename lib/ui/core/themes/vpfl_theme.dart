import 'package:flutter/material.dart';

import 'vpfl_theme_extension.dart';

/// Builds the default light and dark VPFL themes.
abstract final class VpflTheme {
  static const Color _lightAccent = Color(0xFF345FA8);
  static const Color _darkAccent = Color(0xFF9BBEFF);

  /// The default light appearance.
  static ThemeData get light => _create(Brightness.light, _lightAccent);

  /// The default dark appearance.
  static ThemeData get dark => _create(Brightness.dark, _darkAccent);

  static ThemeData _create(Brightness brightness, Color accent) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: brightness == Brightness.dark
          ? const Color(0xFF171A20)
          : const Color(0xFFF7F8FA),
    );
    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: const <ThemeExtension<dynamic>>[
        VpflThemeExtension(playerBackground: Color(0xFF080A0E)),
      ],
      useMaterial3: true,
    );
  }
}
