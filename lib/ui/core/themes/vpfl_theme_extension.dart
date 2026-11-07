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
    required this.playbackProgress,
    required this.playerControlSurface,
    required this.playerControlForeground,
    required this.playerBackground,
    required this.playerOverlayForeground,
    required this.playerOverlayTop,
    required this.playerEdgeBackground,
    required this.playerMenuBackground,
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
  final Color playbackProgress;
  final Color playerControlSurface;
  final Color playerControlForeground;
  final Color playerBackground;
  final Color playerOverlayForeground;
  final Color playerOverlayTop;
  final Color playerEdgeBackground;
  final Color playerMenuBackground;

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
    Color? playbackProgress,
    Color? playerControlSurface,
    Color? playerControlForeground,
    Color? playerBackground,
    Color? playerOverlayForeground,
    Color? playerOverlayTop,
    Color? playerEdgeBackground,
    Color? playerMenuBackground,
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
      playbackProgress: playbackProgress ?? this.playbackProgress,
      playerControlSurface: playerControlSurface ?? this.playerControlSurface,
      playerControlForeground:
          playerControlForeground ?? this.playerControlForeground,
      playerBackground: playerBackground ?? this.playerBackground,
      playerOverlayForeground:
          playerOverlayForeground ?? this.playerOverlayForeground,
      playerOverlayTop: playerOverlayTop ?? this.playerOverlayTop,
      playerEdgeBackground: playerEdgeBackground ?? this.playerEdgeBackground,
      playerMenuBackground: playerMenuBackground ?? this.playerMenuBackground,
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
      playerEdgeBackground: Color.lerp(
        playerEdgeBackground,
        other.playerEdgeBackground,
        t,
      )!,
      playerMenuBackground: Color.lerp(
        playerMenuBackground,
        other.playerMenuBackground,
        t,
      )!,
    );
  }
}
