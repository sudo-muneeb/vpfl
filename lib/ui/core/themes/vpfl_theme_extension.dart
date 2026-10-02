import 'package:flutter/material.dart';

/// Semantic VPFL colors that are not represented by Material's color scheme.
@immutable
class VpflThemeExtension extends ThemeExtension<VpflThemeExtension> {
  const VpflThemeExtension({required this.playerBackground});

  /// Background shown behind video frames.
  final Color playerBackground;

  @override
  VpflThemeExtension copyWith({Color? playerBackground}) {
    return VpflThemeExtension(
      playerBackground: playerBackground ?? this.playerBackground,
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
    );
  }
}
