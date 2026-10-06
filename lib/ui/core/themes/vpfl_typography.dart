import 'package:flutter/material.dart';

/// The type scale shared by VPFL's desktop surfaces.
abstract final class VpflTypography {
  static const String family = 'NotoSansDisplay';

  static const TextStyle timecode = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.18,
      letterSpacing: -0.7,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      height: 1.42,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.25,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0.15,
    ),
  );
}
