import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/widgets/app_shortcuts.dart';
import 'package:vpfl/ui/player/player_shortcuts.dart';
import 'package:vpfl/ui/player/video_controls_overlay.dart';

class _Calls {
  int playPause = 0;
  int seekBackward = 0;
  int seekForward = 0;
  int volumeUp = 0;
  int volumeDown = 0;
  int mute = 0;
  int fullscreen = 0;
  int escape = 0;
  int openFile = 0;

  List<int> get all => [
    playPause,
    seekBackward,
    seekForward,
    volumeUp,
    volumeDown,
    mute,
    fullscreen,
    escape,
    openFile,
  ];
}

class _Harness {
  final calls = _Calls();
  final selected = <int>[];

  Map<ShortcutActivator, VoidCallback> bindings() => playerShortcutBindings(
    onPlayPause: () => calls.playPause++,
    onSeekBackward: () => calls.seekBackward++,
    onSeekForward: () => calls.seekForward++,
    onVolumeUp: () => calls.volumeUp++,
    onVolumeDown: () => calls.volumeDown++,
    onMute: () => calls.mute++,
    onFullscreen: () => calls.fullscreen++,
    onEscape: () => calls.escape++,
    onOpenFile: () => calls.openFile++,
  );

  Widget app({bool disableAnimations = false}) {
    final bindings = this.bindings();
    return MaterialApp(
      theme: VpflTheme.dark,
      shortcuts: appShortcutBindings(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: PlayerMenuShortcuts(child: child!),
      ),
      home: PlayerShortcuts(
        bindings: bindings,
        child: Scaffold(
          body: VideoControlsOverlay(
            title: 'Menu test',
            fullscreen: false,
            controls: PopupMenuButton<int>(
              tooltip: 'More',
              onSelected: selected.add,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('First')),
                PopupMenuItem(value: 2, child: Text('Second')),
              ],
              child: const SizedBox(width: 80, height: 48, child: Text('Open')),
            ),
            onExit: () async {},
            bindings: bindings,
            isPlaying: true,
            playingStream: const Stream<bool>.empty(),
            onPlayPause: () async {},
          ),
        ),
      ),
    );
  }

  void dispose() {}
}

Future<_Harness> _pump(WidgetTester tester) async {
  final harness = _Harness();
  addTearDown(harness.dispose);
  await tester.pumpWidget(harness.app());
  await tester.pump();
  return harness;
}

Future<void> _openWithMouse(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.text('First'), findsOneWidget);
}

void main() {
  testWidgets('Space with a mouse-opened menu dismisses it and toggles once', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openWithMouse(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(harness.calls.playPause, 1);
    expect(harness.selected, isEmpty);
    // The next press goes straight to the player and still toggles once.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(harness.calls.playPause, 2);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('holding Space with a menu open toggles once per press', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openWithMouse(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(harness.calls.playPause, 1);
    expect(harness.selected, isEmpty);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('a second press during the menu exit animation is not lost', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _openWithMouse(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('First'), findsOneWidget, reason: 'still animating out');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(harness.calls.playPause, 2);
    expect(find.text('First'), findsNothing);
  });

  for (final disableAnimations in [false, true]) {
    testWidgets('rapid open and Space cycles toggle once per cycle '
        '(disableAnimations: $disableAnimations)', (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(
        harness.app(disableAnimations: disableAnimations),
      );
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await tester.tap(find.text('Open'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump(const Duration(milliseconds: 40));
        expect(harness.calls.playPause, i);
      }
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(harness.selected, isEmpty);
    });
  }

  testWidgets('M, F and Ctrl+O dismiss an open menu and run once', (
    tester,
  ) async {
    final harness = await _pump(tester);
    for (final key in [
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyO,
    ]) {
      await _openWithMouse(tester);
      if (key == LogicalKeyboardKey.keyO) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      }
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyRepeatEvent(key);
      await tester.sendKeyUpEvent(key);
      if (key == LogicalKeyboardKey.keyO) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing, reason: '$key');
    }
    expect(harness.calls.all, [0, 0, 0, 0, 0, 1, 1, 0, 1]);
  });

  testWidgets(
    'arrow keys stay with the menu and do not seek or change volume',
    (tester) async {
      final harness = await _pump(tester);
      await _openWithMouse(tester);
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.sendKeyRepeatEvent(key);
      }
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      expect(harness.calls.all, List.filled(9, 0));
    },
  );

  testWidgets('Escape and held Escape close only the menu', (tester) async {
    final harness = await _pump(tester);
    await _openWithMouse(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(harness.calls.escape, 0);
    // A fresh press after the menu is gone reaches the player once.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(harness.calls.escape, 1);
  });

  testWidgets('Space and Enter activate a keyboard-focused menu item once', (
    tester,
  ) async {
    final harness = await _pump(tester);
    for (final (key, expectedSelection) in [
      (LogicalKeyboardKey.space, [1]),
      (LogicalKeyboardKey.enter, [1, 1]),
    ]) {
      Focus.of(tester.element(find.text('Open'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        isNot(isA<FocusScopeNode>()),
        reason: 'an item has focus',
      );
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyRepeatEvent(key);
      await tester.sendKeyUpEvent(key);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(harness.selected, expectedSelection, reason: '$key');
    }
    expect(harness.calls.playPause, 0);
  });

  testWidgets('dialogs keep Space and Escape for themselves', (tester) async {
    final harness = await _pump(tester);
    final context = tester.element(find.byType(VideoControlsOverlay));
    final closed = showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Dialog'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(harness.calls.all, List.filled(9, 0));
    expect(find.text('Dialog'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    await closed;
    expect(find.text('Dialog'), findsNothing);
    expect(harness.calls.all, List.filled(9, 0));
  });
}
