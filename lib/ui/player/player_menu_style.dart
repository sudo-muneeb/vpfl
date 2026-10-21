import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/themes/vpfl_theme_extension.dart';

/// Shared surfaces and text styling for menus on top of video.
abstract final class PlayerMenuStyle {
  static List<PopupMenuEntry<T>> frostedPopupItems<T>(
    List<PopupMenuEntry<T>> entries,
  ) => [for (final entry in entries) _FrostedPopupEntry<T>(entry: entry)];

  static List<Widget> frostedMenuChildren(List<Widget> children) => [
    for (final child in children) _FrostedMenuChild(child: child),
  ];

  static PopupMenuThemeData popupTheme(BuildContext context) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return PopupMenuThemeData(
      color: colors.playerMenuBackground,
      menuPadding: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: TextStyle(color: colors.playerOverlayForeground),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: colors.playerOverlayForeground),
      ),
    );
  }

  static MenuStyle menu(BuildContext context) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return MenuStyle(
      alignment: AlignmentDirectional.topEnd,
      backgroundColor: WidgetStatePropertyAll(colors.playerMenuBackground),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: const WidgetStatePropertyAll(Colors.black),
      elevation: const WidgetStatePropertyAll(12),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    );
  }

  static ButtonStyle item(BuildContext context, {bool selected = false}) {
    final colors = Theme.of(context).extension<VpflThemeExtension>()!;
    return ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(
        selected ? colors.playbackProgress : colors.playerOverlayForeground,
      ),
      overlayColor: WidgetStatePropertyAll(
        colors.playerOverlayForeground.withValues(alpha: 0.12),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(190, 42)),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.bodyMedium),
    );
  }

  static ThemeData dialogTheme(BuildContext context) {
    final base = Theme.of(context);
    final colors = base.extension<VpflThemeExtension>()!;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: colors.playerMenuBackground,
        onSurface: colors.playerOverlayForeground,
        onSurfaceVariant: colors.playerOverlayForeground.withValues(
          alpha: 0.72,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.playerMenuBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FrostedPopupEntry<T> extends PopupMenuEntry<T> {
  const _FrostedPopupEntry({required this.entry});

  final PopupMenuEntry<T> entry;

  @override
  double get height => entry.height;

  @override
  bool represents(T? value) => entry.represents(value);

  @override
  State<_FrostedPopupEntry<T>> createState() => _FrostedPopupEntryState<T>();
}

class _FrostedPopupEntryState<T> extends State<_FrostedPopupEntry<T>> {
  @override
  Widget build(BuildContext context) => _FrostedMenuChild(child: widget.entry);
}

class _FrostedMenuChild extends StatelessWidget {
  const _FrostedMenuChild({required this.child});

  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 10, sigmaY: 10);
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(filter: _blur, child: child),
  );
}
