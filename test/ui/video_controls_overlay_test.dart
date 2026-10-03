import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/player/video_controls_overlay.dart';

void main() {
  testWidgets('fullscreen title bar activates only at the top edge', (
    tester,
  ) async {
    await tester.pumpWidget(_overlay(fullscreen: true));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(400, 160));

    expect(find.byTooltip('Exit fullscreen'), findsNothing);
    expect(find.text('Visible controls'), findsOneWidget);

    await mouse.moveTo(const Offset(400, 160));
    await tester.pump();
    expect(find.byTooltip('Exit fullscreen'), findsNothing);

    await mouse.moveTo(const Offset(400, 8));
    await tester.pump();
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
    expect(find.text('Video title'), findsOneWidget);
  });

  testWidgets('fullscreen controls and title bar hide after inactivity', (
    tester,
  ) async {
    await tester.pumpWidget(_overlay(fullscreen: true));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(400, 8));
    await mouse.moveTo(const Offset(400, 8));
    await tester.pump();
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byTooltip('Exit fullscreen'), findsNothing);
    expect(find.text('Visible controls'), findsNothing);
  });

  testWidgets('normal playback keeps top bar hidden', (tester) async {
    await tester.pumpWidget(_overlay(fullscreen: false));
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(400, 8));
    await mouse.moveTo(const Offset(400, 8));
    await tester.pump();

    expect(find.byTooltip('Exit fullscreen'), findsNothing);
    expect(find.text('Visible controls'), findsOneWidget);
  });
}

Widget _overlay({required bool fullscreen}) => MaterialApp(
  home: Scaffold(
    body: SizedBox.expand(
      child: VideoControlsOverlay(
        title: 'Video title',
        fullscreen: fullscreen,
        controls: const SizedBox(
          height: 80,
          child: Center(child: Text('Visible controls')),
        ),
        onExit: () async {},
        bindings: const <ShortcutActivator, VoidCallback>{},
      ),
    ),
  ),
);
