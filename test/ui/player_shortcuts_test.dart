import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/widgets/app_shortcuts.dart';
import 'package:vpfl/ui/player/player_shortcuts.dart';
import 'package:vpfl/ui/player/video_controls_overlay.dart';

const _keys = [
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.keyM,
  LogicalKeyboardKey.keyF,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.keyO,
];
const _continuous = {1, 2, 3, 4};

Map<ShortcutActivator, VoidCallback> _bindings(List<int> calls) =>
    playerShortcutBindings(
      onPlayPause: () => calls[0]++,
      onSeekBackward: () => calls[1]++,
      onSeekForward: () => calls[2]++,
      onVolumeUp: () => calls[3]++,
      onVolumeDown: () => calls[4]++,
      onMute: () => calls[5]++,
      onFullscreen: () => calls[6]++,
      onEscape: () => calls[7]++,
      onOpenFile: () => calls[8]++,
    );

Widget _app(
  List<int> calls, {
  Widget? controls,
  bool fullscreen = false,
  bool playing = false,
}) {
  final bindings = _bindings(calls);
  return MaterialApp(
    theme: VpflTheme.dark,
    shortcuts: appShortcutBindings(),
    home: PlayerShortcuts(
      bindings: bindings,
      child: Scaffold(
        body: VideoControlsOverlay(
          title: 'Keyboard test',
          fullscreen: fullscreen,
          controls: controls ?? const SizedBox(height: 80),
          onExit: () async {},
          bindings: bindings,
          isPlaying: playing,
          playingStream: const Stream<bool>.empty(),
          onPlayPause: () async {},
        ),
      ),
    ),
  );
}

void main() {
  for (final fullscreen in [false, true]) {
    testWidgets('all shortcuts obey press/repeat/release rules ($fullscreen)', (
      tester,
    ) async {
      final calls = List.filled(_keys.length, 0);
      await tester.pumpWidget(
        _app(calls, fullscreen: fullscreen, playing: true),
      );
      await tester.pump();
      for (var i = 0; i < _keys.length; i++) {
        if (i == 8) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        }
        await tester.sendKeyDownEvent(_keys[i]);
        expect(calls[i], 1, reason: '${_keys[i]} initial press');
        // Hold through the overlay's idle timeout as well as repeat events.
        await tester.pump(const Duration(seconds: 4));
        expect(calls[i], 1, reason: '${_keys[i]} long press');
        for (var repeat = 0; repeat < 8; repeat++) {
          await tester.sendKeyRepeatEvent(_keys[i]);
        }
        final expected = _continuous.contains(i) ? 9 : 1;
        expect(calls[i], expected, reason: '${_keys[i]} held');
        await tester.sendKeyUpEvent(_keys[i]);
        expect(calls[i], expected, reason: '${_keys[i]} release');
        for (var press = 0; press < 5; press++) {
          await tester.sendKeyEvent(_keys[i]);
        }
        expect(calls[i], expected + 5, reason: '${_keys[i]} rapid presses');
        if (i == 8) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        }
      }
      expect(calls, [6, 14, 14, 14, 14, 6, 6, 6, 6]);
    });
  }

  testWidgets('bindings require exact modifiers, including either Control', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    await tester.pumpWidget(_app(calls));
    await tester.pump();
    for (final modifier in [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      for (final key in _keys) {
        await tester.sendKeyEvent(key);
      }
      await tester.sendKeyUpEvent(modifier);
    }
    expect(calls, [0, 0, 0, 0, 0, 0, 0, 0, 2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    for (final extra in [
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      await tester.sendKeyDownEvent(extra);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(extra);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(calls, [0, 0, 0, 0, 0, 0, 0, 0, 2]);
  });

  testWidgets('typing and pointer focus restoration preserve text entry', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    final controller = TextEditingController(text: 'movie file');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(calls, controls: TextField(controller: controller)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    // Printable keys must remain unhandled so the platform text input can
    // receive them; a no-op callback that consumes them is also a regression.
    for (final key in [LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyF]) {
      expect(await tester.sendKeyEvent(key), isFalse);
    }
    for (final key in _keys.take(8)) {
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyRepeatEvent(key);
      await tester.sendKeyUpEvent(key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    tester.testTextInput.enterText('m f space');
    await tester.pump();
    expect(controller.text, 'm f space');
    expect(calls, List.filled(9, 0));
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>(),
      isNotNull,
    );

    await tester.tapAt(const Offset(400, 200));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(calls[6], 1);
  });

  testWidgets('held toggles stay suppressed across rebuild and focus changes', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    final inputFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    await tester.pumpWidget(
      _app(calls, controls: TextField(focusNode: inputFocus)),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    expect(calls[6], 1);
    inputFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyF);
    await tester.tapAt(const Offset(400, 200));
    await tester.pump();
    await tester.pumpWidget(_app(calls, fullscreen: true));
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    expect(calls[6], 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(calls[6], 2);
  });

  for (final iconOnly in [false, true]) {
    testWidgets(
      'Space activates a focused control once per press (icon: $iconOnly)',
      (tester) async {
        final calls = List.filled(_keys.length, 0);
        final buttonFocus = FocusNode();
        addTearDown(buttonFocus.dispose);
        var buttonCalls = 0;
        await tester.pumpWidget(
          _app(
            calls,
            controls: iconOnly
                ? IconButton(
                    focusNode: buttonFocus,
                    onPressed: () => buttonCalls++,
                    icon: const Icon(Icons.volume_off),
                  )
                : TextButton(
                    focusNode: buttonFocus,
                    onPressed: () => buttonCalls++,
                    child: const Text('Toggle'),
                  ),
          ),
        );
        buttonFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        expect(calls[0], 0);
        expect(buttonCalls, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(calls[0], 0);
        expect(buttonCalls, 2);
        await tester.tapAt(const Offset(400, 200));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(calls[0], 1);
      },
    );
  }

  testWidgets('focus synchronization does not execute a shortcut', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    await tester.pumpWidget(_app(calls));
    await tester.pump();
    for (final key in [LogicalKeyboardKey.keyF, LogicalKeyboardKey.space]) {
      final physical = key == LogicalKeyboardKey.keyF
          ? PhysicalKeyboardKey.keyF
          : PhysicalKeyboardKey.space;
      HardwareKeyboard.instance.handleKeyEvent(
        KeyDownEvent(
          physicalKey: physical,
          logicalKey: key,
          timeStamp: Duration.zero,
          synthesized: true,
        ),
      );
      HardwareKeyboard.instance.handleKeyEvent(
        KeyUpEvent(
          physicalKey: physical,
          logicalKey: key,
          timeStamp: Duration.zero,
          synthesized: true,
        ),
      );
    }
    expect(calls, List.filled(9, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(calls[6], 1);
  });

  testWidgets('changing modifiers while held does not create a new press', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    await tester.pumpWidget(_app(calls));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyO);
    expect(calls[8], 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyO);
    expect(calls[8], 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyM);
    expect(calls[5], 1);
  });

  testWidgets('focused sliders own repeated arrows without seeking', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    final sliderFocus = FocusNode();
    addTearDown(sliderFocus.dispose);
    var value = 0.5;
    await tester.pumpWidget(
      _app(
        calls,
        controls: StatefulBuilder(
          builder: (context, setState) => Slider(
            focusNode: sliderFocus,
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    sliderFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final first = value;
    expect(first, greaterThan(0.5));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, greaterThan(first));
    final repeated = value;
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(value, repeated);
    expect(calls, List.filled(9, 0));
  });

  testWidgets('modal input owns shortcuts and Escape dismissal', (
    tester,
  ) async {
    final calls = List.filled(_keys.length, 0);
    await tester.pumpWidget(_app(calls));
    await tester.pump();
    final context = tester.element(find.byType(VideoControlsOverlay));
    final dismissed = showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(content: TextField(autofocus: true)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await dismissed;
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, List.filled(9, 0));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    expect(calls[5], 1);
  });
}
