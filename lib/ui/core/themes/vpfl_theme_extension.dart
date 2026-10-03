import 'package:flutter/material.dart';

/// Semantic VPFL colors that are not represented by Material's color scheme.
@immutable
class VpflThemeExtension extends ThemeExtension<VpflThemeExtension> {
  const VpflThemeExtension({
    required this.playerBackground,
    required this.playerOverlayForeground,
    required this.playerOverlayTop,
    required this.playerOverlayMiddle,
    required this.playerOverlayBottom,
    required this.playerEdgeBackground,
  });

  /// Background shown behind video frames.
  final Color playerBackground;
  final Color playerOverlayForeground;
  final Color playerOverlayTop;
  final Color playerOverlayMiddle;
  final Color playerOverlayBottom;
  final Color playerEdgeBackground;

  @override
  VpflThemeExtension copyWith({
    Color? playerBackground,
    Color? playerOverlayForeground,
    Color? playerOverlayTop,
    Color? playerOverlayMiddle,
    Color? playerOverlayBottom,
    Color? playerEdgeBackground,
  }) {
    return VpflThemeExtension(
      playerBackground: playerBackground ?? this.playerBackground,
      playerOverlayForeground:
          playerOverlayForeground ?? this.playerOverlayForeground,
      playerOverlayTop: playerOverlayTop ?? this.playerOverlayTop,
      playerOverlayMiddle: playerOverlayMiddle ?? this.playerOverlayMiddle,
      playerOverlayBottom: playerOverlayBottom ?? this.playerOverlayBottom,
      playerEdgeBackground: playerEdgeBackground ?? this.playerEdgeBackground,
    );
  }

  @override
  VpflThemeExtension lerp(covariant VpflThemeExtension? other, double t) {
    if (other == null) {
      return this;
    }
    return VpflThemeExtension(
      playerBackground: Color.lerp(
        playerBackground,
        other.playerBackground,
        t,
      )!,
      playerOverlayForeground: Color.lerp(
        playerOverlayForeground,
        other.playerOverlayForeground,
        t,
      )!,
      playerOverlayTop: Color.lerp(
        playerOverlayTop,
        other.playerOverlayTop,
        t,
      )!,
      playerOverlayMiddle: Color.lerp(
        playerOverlayMiddle,
        other.playerOverlayMiddle,
        t,
      )!,
      playerOverlayBottom: Color.lerp(
        playerOverlayBottom,
        other.playerOverlayBottom,
        t,
      )!,
      playerEdgeBackground: Color.lerp(
        playerEdgeBackground,
        other.playerEdgeBackground,
        t,
      )!,
    );
  }
}
