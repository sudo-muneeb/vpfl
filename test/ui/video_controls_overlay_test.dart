import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
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
    final slide = tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.text('Visible controls'),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(slide.offset.dy, greaterThan(0));
  });

  testWidgets('bottom controls slide down while fading and rise on hover', (
    tester,
  ) async {
    await tester.pumpWidget(_overlay(fullscreen: false));
    final controls = find.text('Visible controls');
    final visibleY = tester.getTopLeft(controls).dy;

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 110));
    final hidingY = tester.getTopLeft(controls).dy;
    expect(hidingY, greaterThan(visibleY));
    final hidingOpacity = tester
        .widget<FadeTransition>(
          find.descendant(
            of: find.ancestor(
              of: controls,
              matching: find.byType(AnimatedOpacity),
            ),
            matching: find.byType(FadeTransition),
          ),
        )
        .opacity
        .value;
    expect(hidingOpacity, inExclusiveRange(0, 1));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getTopLeft(controls).dy, closeTo(visibleY, 0.01));
  });

  testWidgets(
    'pointer near controls and control clicks extend the idle delay',
    (tester) async {
      await tester.pumpWidget(
        _overlay(
          fullscreen: false,
          controls: SizedBox(
            height: 80,
            child: Center(
              child: TextButton(onPressed: () {}, child: const Text('Control')),
            ),
          ),
        ),
      );
      final bottom = find.ancestor(
        of: find.text('Control'),
        matching: find.byType(AnimatedOpacity),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 560));
      await mouse.moveTo(const Offset(400, 560));
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
      await tester.tap(find.text('Control'));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);
    },
  );

  testWidgets('moving away from controls restores the shorter idle delay', (
    tester,
  ) async {
    await tester.pumpWidget(_overlay(fullscreen: false));
    final bottom = find.ancestor(
      of: find.text('Visible controls'),
      matching: find.byType(AnimatedOpacity),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 560));
    await mouse.moveTo(const Offset(400, 560));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);

    await mouse.moveTo(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);
  });

  testWidgets('pausing reveals controls until playback resumes', (
    tester,
  ) async {
    final playingChanges = StreamController<bool>.broadcast(sync: true);
    addTearDown(playingChanges.close);
    await tester.pumpWidget(
      _overlay(fullscreen: false, playingStream: playingChanges.stream),
    );
    final bottom = find.ancestor(
      of: find.text('Visible controls'),
      matching: find.byType(AnimatedOpacity),
    );
    await tester.pump(const Duration(milliseconds: 1720));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);

    playingChanges.add(false);
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);

    playingChanges.add(true);
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
    await tester.pump(const Duration(milliseconds: 1720));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);
  });

  testWidgets(
    'clicking the video toggles playback without hijacking controls',
    (tester) async {
      final playingChanges = StreamController<bool>.broadcast(sync: true);
      addTearDown(playingChanges.close);
      var playing = true;
      var toggles = 0;
      var controlClicks = 0;
      await tester.pumpWidget(
        _overlay(
          fullscreen: false,
          playingStream: playingChanges.stream,
          onPlayPause: () async {
            toggles++;
            playing = !playing;
            playingChanges.add(playing);
          },
          controls: SizedBox(
            height: 80,
            child: Center(
              child: TextButton(
                onPressed: () => controlClicks++,
                child: const Text('Control'),
              ),
            ),
          ),
        ),
      );
      final bottom = find.ancestor(
        of: find.text('Control'),
        matching: find.byType(AnimatedOpacity),
      );

      await tester.tap(find.text('Control'));
      expect(controlClicks, 1);
      expect(toggles, 0);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump();
      expect(toggles, 1);
      expect(playing, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);

      await tester.tapAt(const Offset(700, 300));
      await tester.pump();
      expect(toggles, 2);
      expect(playing, isTrue);
      await tester.pump(const Duration(milliseconds: 1720));
      expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);
    },
  );

  testWidgets('bottom controls stay visible while a popup is open', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _overlay(
        fullscreen: false,
        onPlayPause: () async => toggles++,
        controls: SizedBox(
          height: 80,
          child: PopupMenuButton<int>(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('Option')),
            ],
            child: const Text('Open menu'),
          ),
        ),
      ),
    );
    final bottom = find.ancestor(
      of: find.text('Open menu'),
      matching: find.byType(AnimatedOpacity),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(toggles, 0);
    expect(find.text('Option'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);

    await tester.tap(find.text('Option'));
    await tester.pumpAndSettle();
    expect(toggles, 0);
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 1);
    await tester.pump(const Duration(seconds: 1, milliseconds: 220));
    expect(tester.widget<AnimatedOpacity>(bottom).opacity, 0);
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
    var videoToggles = 0;
    await tester.pumpWidget(
      _overlay(
        fullscreen: false,
        onPlayPause: () async => videoToggles++,
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
    expect(videoToggles, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pauses, 3);
  });

  testWidgets('both queue buttons appear near either edge', (tester) async {
    final semantics = tester.ensureSemantics();
    var nextCount = 0;
    var videoToggles = 0;
    final queueChanges = StreamController<Playlist>.broadcast(sync: true);
    addTearDown(queueChanges.close);
    final queue = Playlist([
      Media('file:///one.mp4'),
      Media('file:///two.mp4'),
    ]);
    await tester.pumpWidget(
      _overlay(
        fullscreen: false,
        playlist: queue,
        playlistStream: queueChanges.stream,
        onNext: () async => nextCount++,
        onPlayPause: () async => videoToggles++,
      ),
    );

    final next = find.byIcon(Icons.skip_next_rounded);
    final previous = find.byIcon(Icons.skip_previous_rounded);
    final nextButton = find.ancestor(
      of: next,
      matching: find.byType(OutlinedButton),
    );
    final previousButton = find.ancestor(
      of: previous,
      matching: find.byType(OutlinedButton),
    );
    expect(next, findsOneWidget);
    expect(previous, findsOneWidget);
    expect(find.text('Next video'), findsNothing);
    expect(find.byTooltip('Next video'), findsNothing);
    expect(tester.getSize(nextButton), const Size(72, 48));
    expect(tester.getSize(previousButton), const Size(72, 48));
    expect(tester.widget<Icon>(next).size, 36);
    expect(tester.widget<Icon>(previous).size, 36);
    expect(
      tester.widget<OutlinedButton>(nextButton).style!.side!.resolve({}),
      BorderSide.none,
    );
    expect(
      tester.getRect(previousButton).right,
      lessThan(tester.getRect(nextButton).left),
    );
    double opacity(Finder button) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: button, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(next), 0);
    expect(opacity(previous), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 300));
    await mouse.moveTo(const Offset(400, 300));
    await tester.pump();
    expect(opacity(next), 0);
    expect(opacity(previous), 0);

    await mouse.moveTo(const Offset(796, 300));
    await tester.pumpAndSettle();
    expect(opacity(next), 1);
    expect(opacity(previous), 1);
    expect(find.bySemanticsLabel('Next video'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(nextButton).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(previousButton).onPressed, isNull);
    await tester.tap(next);
    expect(nextCount, 1);
    expect(videoToggles, 0);

    await mouse.moveTo(const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(opacity(previous), 1);
    expect(opacity(next), 1);
    expect(find.bySemanticsLabel('Previous video'), findsOneWidget);
    await tester.tap(previous);
    expect(videoToggles, 0);

    await mouse.moveTo(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(opacity(previous), 0);
    expect(opacity(next), 0);

    await mouse.moveTo(const Offset(796, 40));
    await tester.pump();
    expect(opacity(next), 0);
    expect(opacity(previous), 0);

    await tester.pump(const Duration(seconds: 4));
    await mouse.moveTo(const Offset(400, 300));
    await tester.pumpAndSettle();
    final bottom = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Visible controls'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(bottom.opacity, 1);
    expect(opacity(next), 0);
    expect(opacity(previous), 0);

    queueChanges.add(Playlist([Media('file:///one.mp4')]));
    await tester.pump();
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    semantics.dispose();
  });
}

Widget _overlay({
  required bool fullscreen,
  bool isPlaying = true,
  Stream<bool> playingStream = const Stream<bool>.empty(),
  Future<void> Function()? onPlayPause,
  Widget? controls,
  Map<ShortcutActivator, VoidCallback> bindings = const {},
  Playlist? playlist,
  Stream<Playlist>? playlistStream,
  Future<void> Function()? onNext,
}) => MaterialApp(
  theme: VpflTheme.light,
  home: Scaffold(
    body: SizedBox.expand(
      child: VideoControlsOverlay(
        title: 'Video title',
        fullscreen: fullscreen,
        isPlaying: isPlaying,
        playingStream: playingStream,
        onPlayPause: onPlayPause ?? () async {},
        controls:
            controls ??
            const SizedBox(
              height: 80,
              child: Center(child: Text('Visible controls')),
            ),
        onExit: () async {},
        bindings: bindings,
        playlist: playlist,
        playlistStream: playlistStream,
        onNext: onNext,
      ),
    ),
  ),
);
