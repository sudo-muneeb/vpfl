import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/repositories/playback_history_repository.dart';
import 'package:vpfl/data/services/application_shutdown.dart';
import 'package:vpfl/data/services/media_source_identity.dart';
import 'package:vpfl/data/services/playback_history_recorder.dart';
import 'package:vpfl/data/services/playback_service.dart';
import 'package:vpfl/data/thumbnail_providers.dart';
import 'package:vpfl/ui/app.dart';
import 'package:vpfl/ui/core/widgets/window_controls.dart';
import 'package:vpfl/ui/library/media_card.dart';

import '../test/support/isolated_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');
  const alternateSource = String.fromEnvironment('VPFL_TEST_VIDEO_B');
  const alternateDuration = Duration(
    seconds: int.fromEnvironment(
      'VPFL_TEST_VIDEO_B_DURATION',
      defaultValue: 30,
    ),
  );

  Future<void> closeApp(
    WidgetTester tester,
    ProviderContainer container,
    AppDatabase database,
  ) async {
    final playback = container.read(playbackServiceProvider);
    final recorder = container.read(playbackHistoryRecorderProvider);
    final thumbnails = container.read(thumbnailServiceProvider);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.invalidate(recentPlaybackProvider);
    container.invalidate(libraryMediaProvider);
    container.invalidate(savedFoldersProvider);
    container.invalidate(folderMediaProvider);
    await tester.runAsync(
      () => ApplicationShutdown(
        playback: playback,
        history: recorder,
        thumbnails: thumbnails,
        database: database,
      ).shutdown(),
    );
    container.dispose();
  }

  Future<void> waitForPosition(
    WidgetTester tester,
    PlaybackService playback,
    Duration minimum,
  ) async {
    for (
      var attempt = 0;
      attempt < 80 && playback.position < minimum;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(playback.position, greaterThanOrEqualTo(minimum));
  }

  testWidgets(
    'resume survives Home, Recents, shutdown, and database reopening',
    (tester) async {
      final storage = await IsolatedDatabase.create();
      addTearDown(storage.dispose);
      final database = storage.open();
      final uri = Uri.file(File(source).absolute.path).toString();
      final history = PlaybackHistoryRepository(database);
      await history.recordStarted(
        uri: uri,
        displayName: File(source).uri.pathSegments.last,
        duration: const Duration(seconds: 30),
      );
      await history.saveProgress(
        uri: uri,
        position: const Duration(seconds: 12),
        duration: const Duration(seconds: 30),
      );
      expect(await history.resumePosition(uri), const Duration(seconds: 12));

      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(initialMediaUri: uri, startupError: null),
        ),
      );
      final playback = container.read(playbackServiceProvider);
      await waitForPosition(tester, playback, const Duration(seconds: 11));
      expect(await history.resumePosition(uri), const Duration(seconds: 12));
      await waitForPosition(tester, playback, const Duration(seconds: 13));
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      final closing = WindowCommands.shutdownHandler!();
      await tester.pump();
      await tester.runAsync(() => closing);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();

      final reopened = storage.open();
      final reopenedHistory = PlaybackHistoryRepository(reopened);
      final saved = await reopenedHistory.resumePosition(uri);
      expect(saved, greaterThanOrEqualTo(const Duration(seconds: 13)));

      final secondContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(reopened)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: secondContainer,
          child: const VpflApp(initialMediaUri: null, startupError: null),
        ),
      );
      for (
        var attempt = 0;
        attempt < 80 && find.byType(MediaCard).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MediaCard), findsOneWidget);
      await tester.tap(find.byType(MediaCard).first);
      final secondPlayback = secondContainer.read(playbackServiceProvider);
      await waitForPosition(
        tester,
        secondPlayback,
        saved! - const Duration(seconds: 1),
      );
      expect(secondPlayback.isPlaying, isTrue);
      await closeApp(tester, secondContainer, reopened);
    },
    skip: source.isEmpty,
  );

  testWidgets('queue switching restores each source without sharing progress', (
    tester,
  ) async {
    final storage = await IsolatedDatabase.create();
    addTearDown(storage.dispose);
    final first = Uri.file(File(source).absolute.path).toString();
    final secondPath = alternateSource.isEmpty
        ? (await File(source).copy(
            path.join(
              storage.directory.path,
              'another${path.extension(source)}',
            ),
          )).path
        : File(alternateSource).absolute.path;
    final second = Uri.file(secondPath).toString();
    final database = storage.open();
    final history = PlaybackHistoryRepository(database);
    final positions = {
      first: const Duration(seconds: 11),
      second: const Duration(seconds: 13),
    };
    final durations = {
      first: const Duration(seconds: 30),
      second: alternateDuration,
    };
    for (final entry in positions.entries) {
      await history.recordStarted(
        uri: entry.key,
        displayName: path.basename(Uri.parse(entry.key).toFilePath()),
        duration: durations[entry.key]!,
      );
      await history.saveProgress(
        uri: entry.key,
        position: entry.value,
        duration: durations[entry.key]!,
      );
    }

    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    container.read(playbackHistoryRecorderProvider);
    await playback.useNullAudioOutput();
    await playback.openQueue([first, second]);
    expect(
      canonicalMediaUri(playback.playlist.medias[playback.playlist.index].uri),
      first,
    );
    expect(
      playback.position,
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
    await playback.next();
    expect(
      canonicalMediaUri(playback.playlist.medias[playback.playlist.index].uri),
      second,
    );
    expect(
      playback.position,
      allOf(
        greaterThanOrEqualTo(const Duration(seconds: 12)),
        lessThanOrEqualTo(const Duration(seconds: 16)),
      ),
    );
    expect(
      await history.resumePosition(first),
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
    await playback.previous();
    expect(
      canonicalMediaUri(playback.playlist.medias[playback.playlist.index].uri),
      first,
    );
    expect(
      playback.position,
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
    expect(
      await history.resumePosition(second),
      greaterThanOrEqualTo(const Duration(seconds: 12)),
    );
    await playback.next();
    expect(
      canonicalMediaUri(playback.playlist.medias[playback.playlist.index].uri),
      second,
    );
    expect(
      playback.position,
      allOf(
        greaterThanOrEqualTo(const Duration(seconds: 12)),
        lessThan(const Duration(seconds: 20)),
      ),
    );

    await playback.open(first);
    expect(
      playback.position,
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );

    final savedFirst = await history.find(first);
    final settings = container.read(settingsRepositoryProvider);
    await settings.setBool('historyEnabled', false);
    await playback.open(first);
    expect(
      playback.position,
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
    await playback.stop();
    expect((await history.find(first))?.positionMs, savedFirst?.positionMs);

    await settings.setBool('resumeEnabled', false);
    final startedAtBeginning = playback.positionStream
        .firstWhere((value) => value > Duration.zero)
        .timeout(const Duration(seconds: 5));
    await playback.open(first);
    expect(await startedAtBeginning, lessThan(const Duration(seconds: 3)));
    await playback.stop();
    expect((await history.find(first))?.positionMs, savedFirst?.positionMs);

    await closeApp(tester, container, database);
  }, skip: source.isEmpty);

  testWidgets('unusable resume point remains intact after a failed restore', (
    tester,
  ) async {
    final storage = await IsolatedDatabase.create();
    addTearDown(storage.dispose);
    final database = storage.open();
    final history = PlaybackHistoryRepository(database);
    final uri = Uri.file(File(source).absolute.path).toString();
    await history.recordStarted(
      uri: uri,
      displayName: path.basename(source),
      duration: const Duration(minutes: 2),
    );
    await history.saveProgress(
      uri: uri,
      position: const Duration(seconds: 40),
      duration: const Duration(minutes: 2),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    final recorder = container.read(playbackHistoryRecorderProvider);
    await playback.useNullAudioOutput();
    await playback.open(uri);
    expect(playback.position, lessThan(const Duration(seconds: 3)));
    final seeked = playback.positionStream
        .firstWhere((value) => value >= const Duration(seconds: 6))
        .timeout(const Duration(seconds: 5));
    await playback.seek(const Duration(seconds: 6));
    expect(await seeked, greaterThanOrEqualTo(const Duration(seconds: 6)));
    await playback.stop();
    await recorder.dispose();
    expect((await history.find(uri))?.positionMs, 40000);
    await closeApp(tester, container, database);
  }, skip: source.isEmpty);

  testWidgets('superseded resume lookup cannot seek the next source', (
    tester,
  ) async {
    final storage = await IsolatedDatabase.create();
    addTearDown(storage.dispose);
    final database = storage.open();
    final history = PlaybackHistoryRepository(database);
    final first = Uri.file(File(source).absolute.path).toString();
    final secondPath = alternateSource.isEmpty
        ? (await File(source).copy(
            path.join(
              storage.directory.path,
              'another${path.extension(source)}',
            ),
          )).path
        : File(alternateSource).absolute.path;
    final second = Uri.file(secondPath).toString();
    for (final entry in {
      first: const Duration(seconds: 11),
      second: const Duration(seconds: 13),
    }.entries) {
      final duration = entry.key == first
          ? const Duration(seconds: 30)
          : alternateDuration;
      await history.recordStarted(
        uri: entry.key,
        displayName: path.basename(Uri.parse(entry.key).toFilePath()),
        duration: duration,
      );
      await history.saveProgress(
        uri: entry.key,
        position: entry.value,
        duration: duration,
      );
    }

    final firstLookup = Completer<void>();
    final releaseFirstLookup = Completer<void>();
    final playback = PlaybackService(
      resumePositionForUri: (uri) async {
        if (uri == first) {
          firstLookup.complete();
          await releaseFirstLookup.future;
        }
        return history.resumePosition(uri);
      },
    );
    final recorder = PlaybackHistoryRecorder(
      playback: playback,
      history: history,
      settings: SettingsRepository(database),
    );
    try {
      await playback.useNullAudioOutput();
      final firstOpen = playback.open(first);
      await firstLookup.future.timeout(const Duration(seconds: 5));
      final secondOpen = playback.open(second);
      releaseFirstLookup.complete();
      await Future.wait([firstOpen, secondOpen]);
      expect(
        canonicalMediaUri(
          playback.playlist.medias[playback.playlist.index].uri,
        ),
        second,
      );
      expect(
        playback.position,
        allOf(
          greaterThanOrEqualTo(const Duration(seconds: 12)),
          lessThan(const Duration(seconds: 17)),
        ),
      );
      expect(await history.resumePosition(first), const Duration(seconds: 11));
    } finally {
      if (!releaseFirstLookup.isCompleted) releaseFirstLookup.complete();
      await playback.stop();
      await recorder.dispose();
      await playback.dispose();
      await database.close();
    }
  }, skip: source.isEmpty);

  testWidgets('progress waits for a delayed history start write', (
    tester,
  ) async {
    final storage = await IsolatedDatabase.create();
    addTearDown(storage.dispose);
    final database = storage.open();
    final history = _DelayedStartHistory(database);
    final uri = Uri.file(File(source).absolute.path).toString();
    final playback = PlaybackService();
    final recorder = PlaybackHistoryRecorder(
      playback: playback,
      history: history,
      settings: SettingsRepository(database),
    );
    try {
      await playback.useNullAudioOutput();
      await playback.open(uri);
      await history.startEntered.future.timeout(const Duration(seconds: 5));
      final reached = playback.positionStream
          .firstWhere((value) => value >= const Duration(seconds: 12))
          .timeout(const Duration(seconds: 5));
      await playback.seek(const Duration(seconds: 12));
      expect(await reached, greaterThanOrEqualTo(const Duration(seconds: 12)));
      await playback.playOrPause();
      await playback.stop();
      history.releaseStart.complete();
      await recorder.dispose();
      expect(
        (await history.find(uri))?.positionMs,
        greaterThanOrEqualTo(12000),
      );
    } finally {
      if (!history.releaseStart.isCompleted) history.releaseStart.complete();
      await recorder.dispose();
      await playback.dispose();
      await database.close();
    }
  }, skip: source.isEmpty);
}

class _DelayedStartHistory extends PlaybackHistoryRepository {
  _DelayedStartHistory(super.database);

  final startEntered = Completer<void>();
  final releaseStart = Completer<void>();

  @override
  Future<void> recordStarted({
    required String uri,
    required String displayName,
    required Duration duration,
  }) async {
    startEntered.complete();
    await releaseStart.future;
    await super.recordStarted(
      uri: uri,
      displayName: displayName,
      duration: duration,
    );
  }
}
