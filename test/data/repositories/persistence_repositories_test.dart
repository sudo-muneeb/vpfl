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
      expect(database.schemaVersion, 1);
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
}
