import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
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
                  technicalMetadata: 'H.264 · 1920 × 1080',
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
    expect(find.text('H.264 · 1920 × 1080'), findsOneWidget);
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

  testWidgets('unknown technical metadata leaves no placeholder line', (
    tester,
  ) async {
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

  testWidgets('watched time appears over the thumbnail on hover and focus', (
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

    final overlay = find.descendant(
      of: find.byType(MediaCard),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 0);
    expect(find.text('Ready to play'), findsNothing);
    expect(find.text('00:07 / 00:22'), findsOneWidget);
    final initialSize = tester.getSize(find.byType(MediaCard));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(MediaCard)));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 1);
    expect(tester.getSize(find.byType(MediaCard)), initialSize);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 1);
    expect(tester.getSize(find.byType(MediaCard)), initialSize);
  });
}

void _noop() {}
