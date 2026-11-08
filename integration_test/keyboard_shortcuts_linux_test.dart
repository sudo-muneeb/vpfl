import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/widgets/app_shortcuts.dart';
import 'package:vpfl/ui/player/player_screen.dart';
import 'package:vpfl/ui/player/player_shortcuts.dart';
import 'package:vpfl/ui/player/player_inspector.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets('native player preserves held-key and release behavior', (
    tester,
  ) async {
    expect(File(source).existsSync(), isTrue);
    final database = AppDatabase(NativeDatabase.memory());
    final alternateDirectory = await Directory.systemTemp.createTemp(
      'vpfl-keyboard-source-',
    );
    final alternateSource = await File(source)
        .copy('${alternateDirectory.path}/alternate.mp4');
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    var backCalls = 0;
    final playingEvents = <bool>[];
    final subscription = playback.playingStream.listen(playingEvents.add);
    Future<void> until(bool Function() condition, String description) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(
        condition(),
        isTrue,
        reason:
            '$description: position=${playback.position}, '
            'duration=${playback.duration}, playing=${playback.isPlaying}, '
            'completed=${playback.isCompleted}, '
            'sourceGeneration=${playback.sourceGeneration}',
      );
    }

    Future<void> repeat(LogicalKeyboardKey key) async {
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyRepeatEvent(key);
        await tester.pump();
      }
      // Read through the real backend before checking for unexpected effects.
      await playback.nativeTimePositionSeconds();
      await tester.pump();
    }

    bool fullscreen() =>
        tester.state<VideoState>(find.byType(Video)).isFullscreen();

    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: VpflTheme.dark,
            shortcuts: appShortcutBindings(),
            builder: (context, child) =>
                PlayerMenuShortcuts(child: child ?? const SizedBox.shrink()),
            home: PlayerScreen(
              initialMediaUri: File(source).absolute.uri.toString(),
              startupError: null,
              onOpenMedia: (_) {},
              onBack: () => backCalls++,
              themeMode: ThemeMode.dark,
              onThemeModeChanged: (_) {},
              historyEnabled: false,
              resumeEnabled: false,
              onHistoryEnabledChanged: (_) {},
              onResumeEnabledChanged: (_) {},
            ),
          ),
        ),
      );
      await until(
        () => playback.hasVideoOutput && playback.isPlaying,
        'video opened and playing',
      );
      playingEvents.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await until(() => !playback.isPlaying, 'Space pauses');
      await repeat(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      expect(playback.isPlaying, isFalse);
      expect(playingEvents, [false]);

      await playback.seek(Duration.zero);
      await until(
        () => playback.position < const Duration(seconds: 1),
        'seek reset completed',
      );
      for (final (key, targets) in [
        (LogicalKeyboardKey.arrowRight, [10, 20]),
        (LogicalKeyboardKey.arrowLeft, [10, 0]),
      ]) {
        for (var i = 0; i < targets.length; i++) {
          if (i == 0) {
            await tester.sendKeyDownEvent(key);
          } else {
            await tester.sendKeyRepeatEvent(key);
          }
          await until(
            () =>
                (playback.position.inMilliseconds - targets[i] * 1000).abs() <
                1000,
            'arrow seek to ${targets[i]} seconds',
          );
        }
        await tester.sendKeyUpEvent(key);
      }

      await playback.setVolume(50);
      await until(() => playback.volume == 50, 'volume initialized');
      for (final (key, targets) in [
        (LogicalKeyboardKey.arrowUp, [55, 60]),
        (LogicalKeyboardKey.arrowDown, [55, 50]),
      ]) {
        await tester.sendKeyDownEvent(key);
        await until(() => playback.volume == targets[0], 'volume press');
        await tester.sendKeyRepeatEvent(key);
        await until(() => playback.volume == targets[1], 'volume repeat');
        await tester.sendKeyUpEvent(key);
        expect(playback.volume, targets[1]);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyM);
      await until(() => playback.volume == 0, 'M mutes');
      await repeat(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyM);
      expect(playback.volume, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await until(() => playback.volume == 100, 'new M press unmutes');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await until(fullscreen, 'F enters fullscreen');
      await repeat(LogicalKeyboardKey.keyF);
      expect(fullscreen(), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info').last);
      await tester.pump();
      expect(find.byType(PlayerInspector), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await until(
        () => find.byType(PlayerInspector).evaluate().isEmpty,
        'Escape closes inspector first',
      );
      await repeat(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      expect(fullscreen(), isTrue);
      expect(backCalls, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await until(() => !fullscreen(), 'Escape exits fullscreen');
      await repeat(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      expect(fullscreen(), isFalse);
      expect(backCalls, 0, reason: 'holding Escape must not also leave player');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(backCalls, 1);
      playingEvents.clear();
      for (var press = 0; press < 6; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
      }
      await until(
        () => playingEvents.length >= 6,
        'rapid Space presses finish',
      );
      expect(playingEvents, [true, false, true, false, true, false]);
      expect(playback.isPlaying, isFalse);
      final native = playback.videoController.player.platform! as NativePlayer;
      await playback.setVolume(50);
      await until(() => playback.volume == 50, 'rapid volume baseline');
      for (final (key, presses, held, expected) in [
        (LogicalKeyboardKey.arrowUp, 6, false, 80),
        (LogicalKeyboardKey.arrowDown, 6, true, 50),
        (LogicalKeyboardKey.arrowUp, 30, true, 100),
        (LogicalKeyboardKey.arrowDown, 30, false, 0),
        (LogicalKeyboardKey.arrowUp, 2, true, 10),
      ]) {
        for (var press = 0; press < presses; press++) {
          if (!held) {
            await tester.sendKeyEvent(key);
          } else if (press == 0) {
            await tester.sendKeyDownEvent(key);
          } else {
            await tester.sendKeyRepeatEvent(key);
          }
        }
        if (held) await tester.sendKeyUpEvent(key);
        await NativePlayer.lock.synchronized(() async {
          expect(
            double.parse(await native.getProperty('volume')),
            expected,
            reason: 'rapid volume changes accumulate and clamp',
          );
        });
        await until(
          () => playback.volume == expected,
          'volume stream reflects rapid adjustment result',
        );
      }
      await playback.setVolume(100);
      await until(() => playback.volume == 100, 'rapid mute baseline');
      for (final (presses, expected) in [(6, 100), (5, 0), (1, 100)]) {
        for (var press = 0; press < presses; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        }
        await NativePlayer.lock.synchronized(() async {
          expect(
            double.parse(await native.getProperty('volume')),
            expected,
            reason: '$presses rapid mute presses preserve parity',
          );
        });
        await until(
          () => playback.volume == expected,
          'volume stream reflects rapid mute result',
        );
      }
      for (var press = 0; press < 6; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      }
      await tester.pumpAndSettle();
      expect(
        fullscreen(),
        isFalse,
        reason: 'rapid fullscreen presses preserve parity',
      );
      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      expect(find.text('Info').last, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await until(() => playback.isPlaying, 'menu Space resumes playback');
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await until(() => !playback.isPlaying, 'Space pauses after menu closes');

      await playback.seek(Duration.zero);
      await until(
        () => playback.position < const Duration(seconds: 1),
        'rapid seek baseline',
      );
      for (var press = 0; press < 2; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await until(
        () => (playback.position.inMilliseconds - 20000).abs() < 1000,
        'rapid seeks accumulate to twenty seconds',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await until(() => playback.isPlaying, 'Space resumes after fullscreen');

      // A source change must not leave relative seeks using the old source's
      // position. Seeking backward from completion must restart that source.
      final uri = alternateSource.uri.toString();
      await playback.openQueue([uri]);
      await until(
        () =>
            playback.position < const Duration(seconds: 1) &&
            playback.isPlaying,
        'single-item queue opened',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await until(
        () => (playback.position.inMilliseconds - 10000).abs() < 1200,
        'seek follows newly opened source',
      );
      await playback.seek(playback.duration - const Duration(seconds: 1));
      await until(() => playback.isCompleted, 'source completed naturally');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await until(
        () =>
            !playback.isCompleted &&
            playback.position < playback.duration - const Duration(seconds: 5),
        'seek backward recovers completed playback',
      );
    } finally {
      await subscription.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
      await alternateDirectory.delete(recursive: true);
    }
  }, skip: source.isEmpty);
}
