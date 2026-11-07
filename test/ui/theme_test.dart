import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme_extension.dart';

void main() {
  test('Obsidian and Porcelain preserve their semantic surfaces', () {
    final cases = [
      (
        VpflTheme.dark,
        VpflColors.darkBackground,
        VpflColors.darkSidebar,
        VpflColors.darkSidebar,
        VpflColors.darkSurface,
        VpflColors.darkText,
        VpflColors.darkSecondaryText,
        VpflColors.popupBlack,
      ),
      (
        VpflTheme.light,
        VpflColors.lightBackground,
        VpflColors.lightSurface,
        VpflColors.lightSidebar,
        VpflColors.lightSurface,
        VpflColors.lightText,
        VpflColors.lightSecondaryText,
        VpflColors.popupBlack,
      ),
    ];
    for (final (
          theme,
          background,
          topBar,
          sidebar,
          card,
          foreground,
          secondary,
          popup,
        )
        in cases) {
      final tokens = theme.extension<VpflThemeExtension>()!;
      expect(theme.scaffoldBackgroundColor, background);
      expect(tokens.topBarBackground, topBar);
      expect(tokens.sidebarBackground, sidebar);
      expect(tokens.cardSurface, card);
      expect(theme.colorScheme.onSurface, foreground);
      expect(theme.colorScheme.onSurfaceVariant, secondary);
      expect(theme.popupMenuTheme.color, popup);
      expect(popup.a, 1);
      expect(theme.popupMenuTheme.textStyle?.color, VpflColors.darkText);
      expect(theme.menuTheme.style!.backgroundColor!.resolve({}), popup);
      expect(tokens.playbackProgress, theme.colorScheme.primary);
      expect(tokens.cardBorder, theme.colorScheme.outlineVariant);
    }
  });

  testWidgets(
    'segmented appearance keeps selected and focused states visible',
    (tester) async {
      for (final theme in [VpflTheme.light, VpflTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: const {ThemeMode.system},
              ),
            ),
          ),
        );
        final style = theme.segmentedButtonTheme.style!;
        expect(
          style.backgroundColor!.resolve({WidgetState.selected}),
          isNot(style.backgroundColor!.resolve({})),
        );
        expect(
          style.side!.resolve({WidgetState.focused})!.color,
          theme.colorScheme.primary,
        );
      }
    },
  );
}
