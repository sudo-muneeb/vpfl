import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
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
                  status: 'Recent playback',
                  detail: null,
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
    expect(find.text('Recent playback'), findsOneWidget);
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
