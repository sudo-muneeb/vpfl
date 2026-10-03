import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model/app_database.dart';
import 'repositories/playback_history_repository.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final Provider<PlaybackHistoryRepository> playbackHistoryRepositoryProvider =
    Provider<PlaybackHistoryRepository>(
      (Ref ref) => PlaybackHistoryRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
    );

final StreamProvider<List<PlaybackHistory>> recentPlaybackProvider =
    StreamProvider<List<PlaybackHistory>>(
      (Ref ref) => ref.watch(playbackHistoryRepositoryProvider).watchRecent(),
    );
