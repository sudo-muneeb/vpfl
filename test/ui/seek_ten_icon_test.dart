import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vpfl/ui/player/seek_ten_icon.dart';

void main() {
  setUpAll(() async {
    // Widget tests otherwise substitute Ahem and cannot verify icon contours.
    for (final (family, asset) in [
      ('VpflSeek', 'assets/fonts/VpflSeek.ttf'),
      (
        'packages/lucide_icons_flutter/Lucide',
        'packages/lucide_icons_flutter/assets/lucide.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('seek glyphs inherit Icon size, color and opacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IconTheme(
          data: IconThemeData(size: 28, color: Colors.amber, opacity: 0.5),
          child: Row(
            children: [SeekTenIcon(forward: false), SeekTenIcon(forward: true)],
          ),
        ),
      ),
    );

    expect(find.byIcon(SeekTenIcon.backwardIcon), findsOneWidget);
    expect(find.byIcon(SeekTenIcon.forwardIcon), findsOneWidget);
    for (final icon in [SeekTenIcon.backwardIcon, SeekTenIcon.forwardIcon]) {
      final finder = find.byIcon(icon);
      expect(tester.getSize(finder), const Size.square(28));
      final glyph = tester.widget<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      // Icon quantizes its inherited opacity to an 8-bit alpha channel.
      expect(glyph.text.style!.color, Colors.amber.withAlpha(128));
    }
    expect(
      tester.getCenter(find.byIcon(SeekTenIcon.backwardIcon)).dy,
      tester.getCenter(find.byIcon(SeekTenIcon.forwardIcon)).dy,
    );
  });

  for (final (name, theme) in [
    ('dark', ThemeData.dark()),
    ('light', ThemeData.light()),
  ]) {
    for (final scale in [1.0, 1.25, 2.0]) {
      testWidgets('seek and Lucide glyphs: $name at ${scale}x', (tester) async {
        tester.view.physicalSize = Size(256 * scale, 80 * scale);
        tester.view.devicePixelRatio = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_preview(theme));
        await tester.pumpAndSettle();

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('seek-icons-preview')),
        );
        final image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: scale),
        );
        try {
          await expectLater(
            image!,
            matchesGoldenFile('goldens/seek_ten_icons_${name}_${scale}x.png'),
          );
        } finally {
          image?.dispose();
        }
      });
    }
  }
}

Widget _preview(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: const ValueKey('seek-icons-preview'),
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: SizedBox(
            width: 256,
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {},
                  iconSize: 24,
                  icon: const SeekTenIcon(forward: false),
                ),
                IconButton(
                  onPressed: () {},
                  iconSize: 32,
                  icon: const Icon(LucideIcons.play),
                ),
                IconButton(
                  onPressed: () {},
                  iconSize: 24,
                  icon: const SeekTenIcon(forward: true),
                ),
                IconButton(
                  onPressed: () {},
                  iconSize: 24,
                  icon: const Icon(LucideIcons.shuffle),
                ),
                IconButton(
                  onPressed: () {},
                  iconSize: 24,
                  icon: const Icon(LucideIcons.repeat),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
