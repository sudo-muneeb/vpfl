import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/thumbnail_providers.dart';
import 'package:vpfl/data/services/application_shutdown.dart';
import 'package:vpfl/ui/app.dart';
import 'package:vpfl/ui/library/media_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');
  const sourceB = String.fromEnvironment('VPFL_TEST_VIDEO_B');
  const sourceC = String.fromEnvironment('VPFL_TEST_VIDEO_C');
  const cycles = int.fromEnvironment('VPFL_TEST_CYCLES', defaultValue: 20);
  const subtitleTracks = int.fromEnvironment(
    'VPFL_TEST_SUBTITLE_TRACKS',
    defaultValue: -1,
  );

  testWidgets('Back stops playback over $cycles return cycles', (tester) async {
    final container = ProviderContainer();
    final uri = Uri.file(File(source).absolute.path).toString();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: VpflApp(initialMediaUri: uri, startupError: null),
      ),
    );
    final playback = container.read(playbackServiceProvider);
    Future<void> expectSubtitleCount(int count) async {
      for (
        var attempt = 0;
        attempt < 100 &&
            RealMediaTracks(playback.tracks).subtitle.length != count;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(RealMediaTracks(playback.tracks).subtitle.length, count);
      expect(await playback.nativeSubtitleTrackCount(), count);
    }

    for (var i = 0; i < 120 && !playback.isPlaying; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(playback.isPlaying, isTrue);
    if (subtitleTracks >= 0) await expectSubtitleCount(subtitleTracks);
    final controller = playback.videoController;
    for (var cycle = 0; cycle < cycles; cycle++) {
      debugPrint('lifecycle cycle ${cycle + 1}/$cycles: Back');
      await tester.tap(find.byTooltip('Back'));
      for (var i = 0; i < 40 && playback.isPlaying; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(playback.isPlaying, isFalse, reason: 'cycle $cycle');
      if (subtitleTracks >= 0) await expectSubtitleCount(0);
      final stopped = playback.position;
      if (cycle == 0) {
        await Future<void>.delayed(const Duration(seconds: 10));
        await tester.pump();
        expect(playback.position, stopped);
      }
      for (
        var i = 0;
        i < 40 && find.byType(MediaCard).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MediaCard), findsWidgets);
      await tester.tap(find.byType(MediaCard).first);
      for (var i = 0; i < 80 && !playback.isPlaying; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(playback.isPlaying, isTrue, reason: 'reopen cycle $cycle');
      if (subtitleTracks >= 0) await expectSubtitleCount(subtitleTracks);
      if (cycle == 0) {
        final pausedAfterReturn = playback.playingStream
            .firstWhere((playing) => !playing)
            .timeout(const Duration(seconds: 10));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(await pausedAfterReturn, isFalse);
        final resumedAfterReturn = playback.playingStream
            .firstWhere((playing) => playing)
            .timeout(const Duration(seconds: 10));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(await resumedAfterReturn, isTrue);
      }
      debugPrint('lifecycle cycle ${cycle + 1}/$cycles: playing');
      expect(identical(controller, playback.videoController), isTrue);
    }
    if (sourceB.isNotEmpty && sourceC.isNotEmpty) {
      String localPath(String value) {
        final parsed = Uri.tryParse(value);
        return parsed?.scheme == 'file' ? parsed!.toFilePath() : value;
      }

      await tester.pump(const Duration(seconds: 1));
      final b = Uri.file(File(sourceB).absolute.path).toString();
      final c = Uri.file(File(sourceC).absolute.path).toString();
      Future<void> expectSource(
        String expected,
        Future<void> Function() action,
      ) async {
        bool selected(Playlist queue) {
          final current = queue.medias.isNotEmpty && queue.index >= 0
              ? queue.medias[queue.index].uri
              : '';
          return Uri.tryParse(current)?.pathSegments.lastOrNull ==
              Uri.parse(expected).pathSegments.last;
        }

        final event = playback.playlistStream
            .firstWhere(selected)
            .timeout(const Duration(seconds: 10));
        await action();
        await event;
      }

      await expectSource(b, () => playback.open(b));
      if (subtitleTracks >= 0) await expectSubtitleCount(0);
      await expectSource(c, () => playback.open(c));
      if (subtitleTracks >= 0) await expectSubtitleCount(3);
      await expectSource(uri, () => playback.open(uri));
      if (subtitleTracks >= 0) await expectSubtitleCount(subtitleTracks);
      final selectedDuringBurst = <String>[];
      final subscription = playback.playlistStream.listen((queue) {
        if (queue.medias.isNotEmpty && queue.index >= 0) {
          selectedDuringBurst.add(localPath(queue.medias[queue.index].uri));
        }
      });
      await Future.wait([
        playback.open(b),
        playback.open(c),
        playback.open(uri),
      ]);
      await tester.pump(const Duration(milliseconds: 300));
      await subscription.cancel();
      expect(selectedDuringBurst, isNot(contains(localPath(b))));
      expect(selectedDuringBurst, isNot(contains(localPath(c))));
      expect(localPath(playback.playlist.medias.single.uri), localPath(uri));
      if (subtitleTracks >= 0) await expectSubtitleCount(subtitleTracks);
      for (var i = 0; i < 80 && !playback.hasVideoOutput; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        playback.hasVideoOutput,
        isTrue,
        reason: 'final video must decode after rapid source switching',
      );
      expect(identical(controller, playback.videoController), isTrue);
    }
    final shutdown = ApplicationShutdown(
      playback: playback,
      history: container.read(playbackHistoryRecorderProvider),
      thumbnails: container.read(thumbnailServiceProvider),
      database: container.read(appDatabaseProvider),
    );
    debugPrint('lifecycle: shutdown');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() => shutdown.shutdown());
    await tester.runAsync(() => shutdown.shutdown());
    await expectLater(playback.open(uri), throwsStateError);
    container.dispose();
  }, skip: source.isEmpty);
}
