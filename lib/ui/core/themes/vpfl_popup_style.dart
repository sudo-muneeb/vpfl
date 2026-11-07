import 'package:flutter/material.dart';

import 'vpfl_theme.dart';

/// Opaque black menu styling shared by the library and player.
abstract final class VpflPopupStyle {
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide(color: VpflColors.darkBorder),
  );

  static PopupMenuThemeData popupTheme(BuildContext context) =>
      PopupMenuThemeData(
        color: VpflColors.popupBlack,
        menuPadding: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 12,
        shape: _shape,
        textStyle: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: VpflColors.darkText),
        labelTextStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: VpflColors.darkText),
        ),
      );

  static MenuStyle menu(BuildContext context) => const MenuStyle(
    alignment: AlignmentDirectional.topEnd,
    backgroundColor: WidgetStatePropertyAll(VpflColors.popupBlack),
    surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    shadowColor: WidgetStatePropertyAll(Colors.black),
    elevation: WidgetStatePropertyAll(12),
    shape: WidgetStatePropertyAll(_shape),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
  );

  static ButtonStyle item(BuildContext context, {bool selected = false}) =>
      ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(
          selected ? VpflColors.brandRed : VpflColors.darkText,
        ),
        overlayColor: const WidgetStatePropertyAll(VpflColors.darkHover),
        minimumSize: const WidgetStatePropertyAll(Size(190, 42)),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.bodyMedium,
        ),
      );

  static ThemeData dialogTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: VpflColors.popupBlack,
        onSurface: VpflColors.darkText,
        onSurfaceVariant: VpflColors.darkSecondaryText,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: VpflColors.popupBlack,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        elevation: 12,
        shape: _shape,
      ),
    );
  }
}
