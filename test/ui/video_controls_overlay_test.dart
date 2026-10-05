import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/player/video_controls_overlay.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';

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
    final bottom = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Visible controls'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(bottom.opacity, 0);
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

  testWidgets('playback shortcuts work immediately and after control clicks', (
    tester,
  ) async {
    var pauses = 0;
    var seeks = 0;
    await tester.pumpWidget(
      _overlay(
        fullscreen: false,
        controls: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () {}, child: const Text('Control')),
            Slider(value: 0.5, onChanged: (_) {}),
          ],
        ),
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () => pauses++,
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => seeks++,
        },
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect((pauses, seeks), (1, 1));

    await tester.tap(find.text('Control'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pauses, 2);

    await tester.tap(find.byType(Slider));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pauses, 3);
  });
}

Widget _overlay({
  required bool fullscreen,
  Widget? controls,
  Map<ShortcutActivator, VoidCallback> bindings = const {},
}) => MaterialApp(
  theme: VpflTheme.light,
  home: Scaffold(
    body: SizedBox.expand(
      child: VideoControlsOverlay(
        title: 'Video title',
        fullscreen: fullscreen,
        controls:
            controls ??
            const SizedBox(
              height: 80,
              child: Center(child: Text('Visible controls')),
            ),
        onExit: () async {},
        bindings: bindings,
      ),
    ),
  ),
);
