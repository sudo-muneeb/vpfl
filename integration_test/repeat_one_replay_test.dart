import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets('Repeat One restarts a long video after seeking near EOF', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(
            initialMediaUri: File(source).uri.toString(),
            startupError: null,
          ),
        ),
      );
      final videoOutput = await playback.videoController.platform.future;
      for (
        var i = 0;
        i < 80 &&
            (videoOutput.rect.value == null ||
                videoOutput.rect.value!.width <= 1);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await videoOutput.waitUntilFirstFrameRendered.timeout(
        const Duration(seconds: 20),
      );
      expect(playback.duration, greaterThan(const Duration(seconds: 10)));

      final videoRect = tester.getRect(find.byType(Video));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: videoRect.center);
      await mouse.moveTo(videoRect.bottomCenter - const Offset(0, 40));
      await tester.pump();
      await tester.tap(
        find.byTooltip('Repeat off. Click to repeat this video'),
      );
      await tester.pump();
      expect(playback.playlistMode, PlaylistMode.single);

      await playback.seek(playback.duration - const Duration(seconds: 2));
      var replays = 0;
      final subscription = playback.playlistStream.listen((_) => replays++);
      try {
        for (var i = 0; i < 100 && replays < 1; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(replays, greaterThanOrEqualTo(1));
      } finally {
        await subscription.cancel();
      }
      for (
        var i = 0;
        i < 100 &&
            (playback.position > const Duration(milliseconds: 400) ||
                !playback.isPlaying);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        playback.position,
        lessThanOrEqualTo(const Duration(milliseconds: 400)),
      );
      expect(playback.isPlaying, isTrue);
      for (
        var i = 0;
        i < 100 && playback.position < const Duration(milliseconds: 650);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        playback.position,
        greaterThanOrEqualTo(const Duration(milliseconds: 650)),
      );
      expect(playback.isCompleted, isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  }, skip: source.isEmpty);
}
