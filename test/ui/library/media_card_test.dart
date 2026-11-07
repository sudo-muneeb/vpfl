import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme_extension.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
  testWidgets('dismissing a context menu outside clears card focus styling', (
    tester,
  ) async {
    const path = '/videos/clip.mp4';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: VpflTheme.dark,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MediaCard(
                  title: 'clip.mp4',
                  filePath: path,
                  onTap: _noop,
                  onShowDetails: _noop,
                  onShowContainingFolder: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.down(tester.getCenter(find.byType(MediaCard)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Show details'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Show details'), findsNothing);
    final card = find.descendant(
      of: find.byType(MediaCard),
      matching: find.byType(AnimatedContainer),
    );
    final decoration =
        tester.widget<AnimatedContainer>(card).decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final focusColor = VpflTheme.dark
        .extension<VpflThemeExtension>()!
        .sidebarFocus;
    expect(border.top.color, isNot(focusColor));
    expect(find.text(path), findsNothing);
  });

  testWidgets('filename rests on card and path appears on hover and focus', (
    tester,
  ) async {
    const path = '/very/deep/folder/0219.mov';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: VpflTheme.light,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MediaCard(
                  title: '0219.mov',
                  filePath: path,
                  onTap: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('0219.mov'), findsOneWidget);
    expect(find.text(path), findsNothing);
    expect(find.text('H.264 · 1920 × 1080'), findsNothing);
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(find.text('Ready to play'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(MediaCard)));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(path), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text(path), findsOneWidget);
  });

  testWidgets('cards leave technical metadata off the surface', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: VpflTheme.light,
          home: const Scaffold(
            body: MediaCard(title: 'clip.webm', onTap: _noop),
          ),
        ),
      ),
    );
    expect(find.text('clip.webm'), findsOneWidget);
    expect(find.textContaining('Unknown codec'), findsNothing);
    expect(find.text('Ready to play'), findsNothing);
  });

  testWidgets('progress and watched time stay readable without hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: VpflTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: MediaCard(
                  title: 'A long descriptive video filename.mp4',
                  filePath:
                      '/nested/path/A long descriptive video filename.mp4',
                  watchedTime: '00:07 / 00:22',
                  progress: 7 / 22,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('00:07 / 00:22'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(LucideIcons.clapperboard)).size, 46);
    expect(find.text('No preview'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(7 / 22, 0.001),
    );
    final initialSize = tester.getSize(find.byType(MediaCard));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(MediaCard)));
    await tester.pumpAndSettle();
    expect(find.text('00:07 / 00:22'), findsOneWidget);
    expect(tester.getSize(find.byType(MediaCard)), initialSize);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('00:07 / 00:22'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('00:07 / 00:22'), findsOneWidget);
    expect(tester.getSize(find.byType(MediaCard)), initialSize);
  });
}

void _noop() {}
