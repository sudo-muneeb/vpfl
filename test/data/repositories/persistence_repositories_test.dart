import 'package:drift/drift.dart' show driftRuntimeOptions;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/playback_history_repository.dart';

void main() {
  late AppDatabase database;
  late PlaybackHistoryRepository history;
  late SettingsRepository settings;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    history = PlaybackHistoryRepository(database);
    settings = SettingsRepository(database);
  });

  tearDown(() => database.close());

  test(
    'creates the current versioned schema and persists preferences',
    () async {
      expect(database.schemaVersion, 2);
      expect(
        await settings.getBool('historyEnabled', defaultValue: true),
        isTrue,
      );

      await settings.setBool('historyEnabled', false);

      expect(
        await settings.getBool('historyEnabled', defaultValue: true),
        isFalse,
      );
    },
  );

  test('history survives closing and reopening the database', () async {
    final bool previousWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarningSetting;
    });
    final Directory directory = await Directory.systemTemp.createTemp(
      'vpfl-history-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/vpfl.sqlite');

    final AppDatabase first = AppDatabase(NativeDatabase(file));
    final PlaybackHistoryRepository firstHistory = PlaybackHistoryRepository(
      first,
    );
    await firstHistory.recordStarted(
      uri: 'file:///videos/reopen.mp4',
      displayName: 'reopen.mp4',
      duration: const Duration(minutes: 3),
    );
    await firstHistory.saveProgress(
      uri: 'file:///videos/reopen.mp4',
      position: const Duration(seconds: 51),
      duration: const Duration(minutes: 3),
    );
    await first.close();

    final AppDatabase reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(
      await PlaybackHistoryRepository(reopened)
          .resumePosition('file:///videos/reopen.mp4'),
      const Duration(seconds: 51),
    );
  });

  test('records started media and updates one-time resume state', () async {
    const String uri = 'file:///videos/clip.mp4';
    await history.recordStarted(
      uri: uri,
      displayName: 'clip.mp4',
      duration: const Duration(minutes: 2),
    );
    await history.saveProgress(
      uri: uri,
      position: const Duration(seconds: 42),
      duration: const Duration(minutes: 2),
    );

    expect(await history.resumePosition(uri), const Duration(seconds: 42));

    await history.saveProgress(
      uri: uri,
      position: const Duration(seconds: 110),
      duration: const Duration(minutes: 2),
    );
    expect(await history.resumePosition(uri), isNull);

    final PlaybackHistory? item = await history.find(uri);
    expect(item?.completed, isTrue);
    expect(item?.positionMs, 0);
  });

  test(
    'recent history is reactive and repeated starts increase watch count',
    () async {
      final List<List<PlaybackHistory>> updates = [];
      final subscription = history.watchRecent().listen(updates.add);
      await Future<void>.delayed(Duration.zero);
      await history.recordStarted(
        uri: 'file:///videos/clip.mp4',
        displayName: 'clip.mp4',
        duration: Duration.zero,
      );
      await history.recordStarted(
        uri: 'file:///videos/clip.mp4',
        displayName: 'clip.mp4',
        duration: Duration.zero,
      );
      await Future<void>.delayed(Duration.zero);

      expect(updates.last.single.watchCount, 2);
      await subscription.cancel();
    },
  );

  test('recent limit does not expire older resume records', () async {
    var now = DateTime.utc(2024, 1, 1);
    final repository = PlaybackHistoryRepository(database, now: () => now);
    final uris = [
      for (var index = 0; index < 5; index++) 'file:///videos/$index.mp4',
    ];
    for (final uri in uris) {
      await repository.recordStarted(
        uri: uri,
        displayName: uri,
        duration: const Duration(minutes: 2),
      );
      await repository.saveProgress(
        uri: uri,
        position: const Duration(seconds: 25),
        duration: const Duration(minutes: 2),
      );
      now = now.add(const Duration(days: 400));
    }

    expect(
      (await repository.watchRecent(limit: 2).first).map((row) => row.uri),
      [uris[4], uris[3]],
    );
    expect(
      await repository.resumePosition(uris.first),
      const Duration(seconds: 25),
    );
    expect(await repository.remove(uris[2]), 1);
    expect(await repository.find(uris[2]), isNull);
    expect(
      await repository.resumePosition(uris.first),
      const Duration(seconds: 25),
    );
    expect(await repository.clear(), 4);
    expect(await repository.find(uris.first), isNull);
  });

  test(
    'completion needs both 90 percent and at most 15 seconds remaining',
    () async {
      final cases = <({Duration duration, Duration position, bool completed})>[
        (
          duration: const Duration(seconds: 30),
          position: const Duration(seconds: 16),
          completed: false,
        ),
        (
          duration: const Duration(seconds: 30),
          position: const Duration(seconds: 27),
          completed: true,
        ),
        (
          duration: const Duration(minutes: 5),
          position: const Duration(minutes: 4, seconds: 44),
          completed: false,
        ),
        (
          duration: const Duration(minutes: 5),
          position: const Duration(minutes: 4, seconds: 45),
          completed: true,
        ),
        (
          duration: const Duration(seconds: 10),
          position: const Duration(seconds: 9),
          completed: true,
        ),
      ];
      for (var index = 0; index < cases.length; index++) {
        final item = cases[index];
        final uri = 'file:///videos/$index.mp4';
        await history.recordStarted(
          uri: uri,
          displayName: '$index',
          duration: item.duration,
        );
        await history.saveProgress(
          uri: uri,
          position: item.position,
          duration: item.duration,
        );
        expect(
          (await history.find(uri))?.completed,
          item.completed,
          reason: '$item',
        );
        expect(
          await history.resumePosition(uri),
          item.completed || item.position < const Duration(seconds: 10)
              ? isNull
              : item.position,
        );
      }
    },
  );

  test(
    'unknown duration does not erase a known duration or positive position',
    () async {
      const uri = 'file:///videos/metadata-late.mp4';
      await history.recordStarted(
        uri: uri,
        displayName: 'metadata-late.mp4',
        duration: const Duration(minutes: 2),
      );
      await history.recordStarted(
        uri: uri,
        displayName: 'metadata-late.mp4',
        duration: Duration.zero,
      );
      await history.saveProgress(
        uri: uri,
        position: const Duration(seconds: 31),
        duration: Duration.zero,
      );
      expect(
        (await history.find(uri))?.durationMs,
        const Duration(minutes: 2).inMilliseconds,
      );
      expect(await history.resumePosition(uri), const Duration(seconds: 31));

      const newUri = 'file:///videos/no-duration.mp4';
      await history.recordStarted(
        uri: newUri,
        displayName: 'no-duration.mp4',
        duration: Duration.zero,
      );
      await history.saveProgress(
        uri: newUri,
        position: const Duration(seconds: -1),
        duration: Duration.zero,
      );
      expect((await history.find(newUri))?.positionMs, 0);
    },
  );
}
