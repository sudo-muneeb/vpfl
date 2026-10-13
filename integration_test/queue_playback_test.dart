import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:drift/native.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/services/playback_service.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets(
    'short local videos advance, stop, repeat, and do not skip errors',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp('vpfl-queue-');
      final files = [
        for (final name in ['a.mp4', 'b.mp4', 'c.mp4'])
          await File(source).copy('${directory.path}/$name'),
      ];
      final corrupt = File('${directory.path}/broken.mp4')
        ..writeAsStringSync('invalid video');
      final uris = files.map((file) => file.uri.toString()).toList();
      final database = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final playback = container.read(playbackServiceProvider);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: VpflApp(initialMediaUri: uris[0], startupError: null),
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

        await playback.openQueue(uris);
        await _waitForIndex(tester, playback, 1);
        await _waitForFreshPlayback(tester, playback);
        await _waitForIndex(tester, playback, 2);
        await _waitForFreshPlayback(tester, playback);
        await _waitForCompletion(tester, playback);
        expect(playback.playlist.index, 2);
        expect(playback.isPlaying, isFalse);

        await playback.setPlaylistMode(PlaylistMode.loop);
        await playback.openQueue(uris, startIndex: 2);
        await _waitForIndex(tester, playback, 0);
        await _waitForFreshPlayback(tester, playback);

        await playback.setPlaylistMode(PlaylistMode.single);
        await playback.openQueue(uris, startIndex: 1);
        await _waitForSelectionCount(tester, playback, 1, 1);
        expect(playback.playlist.index, 1);
        await _waitForFreshPlayback(tester, playback);

        await playback.setPlaylistMode(PlaylistMode.none);
        await playback.setShuffle(true);
        final shuffled = <int>{0};
        final shuffledSubscription = playback.playlistStream.listen((queue) {
          shuffled.add(queue.index);
        });
        await playback.openQueue(uris);
        for (var i = 0; i < 160 && shuffled.length < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await shuffledSubscription.cancel();
        expect(shuffled, {0, 1, 2});
        await _waitForCompletion(tester, playback);
        await playback.setShuffle(false);

        await playback.openQueue([uris[0], corrupt.uri.toString(), uris[2]]);
        await _waitForIndex(tester, playback, 1);
        await tester.pump(const Duration(seconds: 4));
        expect(playback.playlist.index, 1);
        await playback.stopFailedMedia();
        await playback.next();
        await _waitForPlaying(tester, playback);
        expect(playback.playlist.index, 2);

        await playback.openQueue([uris[0], uris[0], uris[2]]);
        await playback.next();
        expect(playback.playlist.index, 1);
        expect(
          playback.playlist.medias[0].uri,
          playback.playlist.medias[1].uri,
        );
        await Future.wait([
          playback.previous(),
          playback.next(),
          playback.next(),
        ]);
        expect(playback.playlist.index, 2);
        await _waitForPlaying(tester, playback);

        await playback.setPlaylistMode(PlaylistMode.none);
        await playback.openQueue([uris[0]]);
        await _waitForCompletion(tester, playback);
        await playback.playOrPause();
        await _waitForFreshPlayback(tester, playback);
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
        await _waitForSelectionCount(tester, playback, 0, 2);
        await _waitForFreshPlayback(tester, playback);

        await playback.stop();
        await tester.pump(const Duration(seconds: 3));
        expect(playback.isPlaying, isFalse);
        expect(playback.playlist.medias, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await container.read(playbackHistoryRecorderProvider).dispose();
        await playback.dispose();
        await database.close();
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
    skip: source.isEmpty,
  );
}

Future<void> _waitForIndex(
  WidgetTester tester,
  PlaybackService playback,
  int index,
) async {
  for (var i = 0; i < 100 && playback.playlist.index != index; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    playback.playlist.index,
    index,
    reason:
        'playing=${playback.isPlaying} completed=${playback.isCompleted} '
        'position=${playback.position} duration=${playback.duration} '
        'video=${playback.hasVideoOutput}',
  );
}

Future<void> _waitForCompletion(
  WidgetTester tester,
  PlaybackService playback,
) async {
  for (var i = 0; i < 100 && !playback.isCompleted; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(playback.isCompleted, isTrue);
}

Future<void> _waitForSelectionCount(
  WidgetTester tester,
  PlaybackService playback,
  int index,
  int count,
) async {
  var selections = 0;
  final subscription = playback.playlistStream.listen((queue) {
    if (queue.index == index) selections++;
  });
  try {
    for (var i = 0; i < 100 && selections < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(selections, greaterThanOrEqualTo(count));
  } finally {
    await subscription.cancel();
  }
}

Future<void> _waitForPlaying(
  WidgetTester tester,
  PlaybackService playback,
) async {
  for (var i = 0; i < 100 && !playback.isPlaying; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(playback.isPlaying, isTrue);
}

Future<void> _waitForFreshPlayback(
  WidgetTester tester,
  PlaybackService playback,
) async {
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
}
