import 'package:drift/drift.dart';

import '../model/app_database.dart';

/// Persistence operations for successfully started local media sessions.
class PlaybackHistoryRepository {
  PlaybackHistoryRepository(this._database);

  final AppDatabase _database;

  Stream<List<PlaybackHistory>> watchRecent({int limit = 20}) =>
      (_database.select(_database.playbackHistories)
            ..orderBy([
              (PlaybackHistories table) =>
                  OrderingTerm.desc(table.lastOpenedAt),
            ])
            ..limit(limit))
          .watch();

  Future<PlaybackHistory?> find(String uri) => (_database.select(
    _database.playbackHistories,
  )..where((PlaybackHistories row) => row.uri.equals(uri))).getSingleOrNull();

  Future<void> recordStarted({
    required String uri,
    required String displayName,
    required Duration duration,
  }) => _database.transaction(() async {
    final PlaybackHistory? existing = await find(uri);
    await _database
        .into(_database.playbackHistories)
        .insertOnConflictUpdate(
          PlaybackHistoriesCompanion.insert(
            uri: uri,
            displayName: displayName,
            lastOpenedAt: DateTime.now(),
            positionMs: Value(
              existing?.completed == true ? 0 : existing?.positionMs ?? 0,
            ),
            durationMs: Value(duration.inMilliseconds),
            watchCount: Value((existing?.watchCount ?? 0) + 1),
            completed: const Value(false),
          ),
        );
  });

  Future<void> saveProgress({
    required String uri,
    required Duration position,
    required Duration duration,
  }) async {
    final PlaybackHistory? existing = await find(uri);
    if (existing == null) return;

    final int durationMs = duration.inMilliseconds;
    final bool completed =
        durationMs > 0 &&
        (durationMs > 15000
            ? position.inMilliseconds >= durationMs - 15000
            : position.inMilliseconds * 10 >= durationMs * 9);
    await (_database.update(
      _database.playbackHistories,
    )..where((PlaybackHistories row) => row.uri.equals(uri))).write(
      PlaybackHistoriesCompanion(
        positionMs: Value(
          completed ? 0 : position.inMilliseconds.clamp(0, durationMs),
        ),
        durationMs: Value(durationMs),
        completed: Value(completed),
      ),
    );
  }

  Future<Duration?> resumePosition(String uri) async {
    final PlaybackHistory? history = await find(uri);
    if (history == null || history.completed || history.positionMs < 10000) {
      return null;
    }
    return Duration(milliseconds: history.positionMs);
  }

  Future<int> clear() => _database.delete(_database.playbackHistories).go();
}

/// Key/value storage for small application preferences.
class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  Future<String?> getValue(String key) async => (await (_database.select(
    _database.appSettings,
  )..where((AppSettings row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<bool> getBool(String key, {required bool defaultValue}) async =>
      switch (await getValue(key)) {
        'true' => true,
        'false' => false,
        _ => defaultValue,
      };

  Future<void> setValue(String key, String value) => _database
      .into(_database.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  Future<void> setBool(String key, bool value) => setValue(key, '$value');
}
