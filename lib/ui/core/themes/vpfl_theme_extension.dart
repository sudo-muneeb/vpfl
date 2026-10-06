import 'package:flutter/material.dart';

/// Semantic VPFL colors that are not represented by Material's color scheme.
@immutable
class VpflThemeExtension extends ThemeExtension<VpflThemeExtension> {
  const VpflThemeExtension({
    required this.topBarBackground,
    required this.sidebarBackground,
    required this.sidebarSelected,
    required this.sidebarHover,
    required this.sidebarFocus,
    required this.cardSurface,
    required this.cardBorder,
    required this.cardBorderActive,
    required this.cardArtworkTop,
    required this.cardArtworkBottom,
    required this.cardOverlay,
    required this.playbackProgress,
    required this.playerControlSurface,
    required this.playerControlForeground,
    required this.playerBackground,
    required this.playerOverlayForeground,
    required this.playerOverlayTop,
    required this.playerOverlayMiddle,
    required this.playerOverlayBottom,
    required this.playerEdgeBackground,
  });

  /// Background shown behind video frames.
  final Color topBarBackground;
  final Color sidebarBackground;
  final Color sidebarSelected;
  final Color sidebarHover;
  final Color sidebarFocus;
  final Color cardSurface;
  final Color cardBorder;
  final Color cardBorderActive;
  final Color cardArtworkTop;
  final Color cardArtworkBottom;
  final Color cardOverlay;
  final Color playbackProgress;
  final Color playerControlSurface;
  final Color playerControlForeground;
  final Color playerBackground;
  final Color playerOverlayForeground;
  final Color playerOverlayTop;
  final Color playerOverlayMiddle;
  final Color playerOverlayBottom;
  final Color playerEdgeBackground;

  @override
  VpflThemeExtension copyWith({
    Color? topBarBackground,
    Color? sidebarBackground,
    Color? sidebarSelected,
    Color? sidebarHover,
    Color? sidebarFocus,
    Color? cardSurface,
    Color? cardBorder,
    Color? cardBorderActive,
    Color? cardArtworkTop,
    Color? cardArtworkBottom,
    Color? cardOverlay,
    Color? playbackProgress,
    Color? playerControlSurface,
    Color? playerControlForeground,
    Color? playerBackground,
    Color? playerOverlayForeground,
    Color? playerOverlayTop,
    Color? playerOverlayMiddle,
    Color? playerOverlayBottom,
    Color? playerEdgeBackground,
  }) {
    return VpflThemeExtension(
      topBarBackground: topBarBackground ?? this.topBarBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarFocus: sidebarFocus ?? this.sidebarFocus,
      cardSurface: cardSurface ?? this.cardSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBorderActive: cardBorderActive ?? this.cardBorderActive,
      cardArtworkTop: cardArtworkTop ?? this.cardArtworkTop,
      cardArtworkBottom: cardArtworkBottom ?? this.cardArtworkBottom,
      cardOverlay: cardOverlay ?? this.cardOverlay,
      playbackProgress: playbackProgress ?? this.playbackProgress,
      playerControlSurface: playerControlSurface ?? this.playerControlSurface,
      playerControlForeground:
          playerControlForeground ?? this.playerControlForeground,
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
      topBarBackground: Color.lerp(
        topBarBackground,
        other.topBarBackground,
        t,
      )!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      sidebarSelected: Color.lerp(sidebarSelected, other.sidebarSelected, t)!,
      sidebarHover: Color.lerp(sidebarHover, other.sidebarHover, t)!,
      sidebarFocus: Color.lerp(sidebarFocus, other.sidebarFocus, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderActive: Color.lerp(
        cardBorderActive,
        other.cardBorderActive,
        t,
      )!,
      cardArtworkTop: Color.lerp(cardArtworkTop, other.cardArtworkTop, t)!,
      cardArtworkBottom: Color.lerp(
        cardArtworkBottom,
        other.cardArtworkBottom,
        t,
      )!,
      cardOverlay: Color.lerp(cardOverlay, other.cardOverlay, t)!,
      playbackProgress: Color.lerp(
        playbackProgress,
        other.playbackProgress,
        t,
      )!,
      playerControlSurface: Color.lerp(
        playerControlSurface,
        other.playerControlSurface,
        t,
      )!,
      playerControlForeground: Color.lerp(
        playerControlForeground,
        other.playerControlForeground,
        t,
      )!,
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
