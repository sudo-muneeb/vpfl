import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model/app_database.dart';
import 'repositories/playback_history_repository.dart';
import 'repositories/library_repository.dart';
import 'services/library_scanner.dart';

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

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>(
      (Ref ref) => LibraryRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<LibraryScanner> libraryScannerProvider =
    Provider<LibraryScanner>(
      (Ref ref) => LibraryScanner(ref.watch(libraryRepositoryProvider)),
    );

final StreamProvider<List<PlaybackHistory>> recentPlaybackProvider =
    StreamProvider<List<PlaybackHistory>>(
      (Ref ref) => ref.watch(playbackHistoryRepositoryProvider).watchRecent(),
    );

final StreamProvider<List<SavedFolder>> savedFoldersProvider =
    StreamProvider<List<SavedFolder>>(
      (Ref ref) => ref.watch(libraryRepositoryProvider).watchFolders(),
    );

final StreamProvider<List<LibraryMediaItem>> libraryMediaProvider =
    StreamProvider<List<LibraryMediaItem>>(
      (Ref ref) => ref.watch(libraryRepositoryProvider).watchAllMedia(),
    );

final folderMediaProvider = StreamProvider.family<List<LibraryMediaItem>, int>(
  (Ref ref, int folderId) =>
      ref.watch(libraryRepositoryProvider).watchFolderMedia(folderId),
);
