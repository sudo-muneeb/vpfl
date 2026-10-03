import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../model/app_database.dart';

class LibraryRepository {
  LibraryRepository(this._database);
  final AppDatabase _database;

  Stream<List<SavedFolder>> watchFolders() => (_database.select(
    _database.savedFolders,
  )..orderBy([(SavedFolders f) => OrderingTerm.asc(f.displayName)])).watch();

  Stream<List<LibraryMediaItem>> watchAllMedia() =>
      (_database.select(_database.libraryMediaItems)..orderBy([
            (LibraryMediaItems m) => OrderingTerm.asc(m.displayName),
          ]))
          .watch();

  Stream<List<LibraryMediaItem>> watchFolderMedia(int folderId) =>
      (_database.select(_database.libraryMediaItems)
            ..where((LibraryMediaItems m) => m.folderId.equals(folderId))
            ..orderBy([
              (LibraryMediaItems m) => OrderingTerm.asc(m.displayName),
            ]))
          .watch();

  Future<List<LibraryMediaItem>> mediaForFolder(int folderId) =>
      (_database.select(
        _database.libraryMediaItems,
      )..where((LibraryMediaItems m) => m.folderId.equals(folderId))).get();

  Future<SavedFolder> addFolder(String folderPath) async {
    final String normalized = path.normalize(folderPath);
    await _database
        .into(_database.savedFolders)
        .insertOnConflictUpdate(
          SavedFoldersCompanion.insert(
            path: normalized,
            displayName: path.basename(normalized),
            addedAt: DateTime.now(),
          ),
        );
    return (_database.select(
      _database.savedFolders,
    )..where((SavedFolders f) => f.path.equals(normalized))).getSingle();
  }

  Future<void> removeFolder(SavedFolder folder) =>
      _database.transaction(() async {
        await (_database.delete(
          _database.libraryMediaItems,
        )..where((LibraryMediaItems m) => m.folderId.equals(folder.id))).go();
        await (_database.delete(
          _database.savedFolders,
        )..where((SavedFolders f) => f.id.equals(folder.id))).go();
      });

  Future<void> upsertMedia(List<LibraryMediaItemsCompanion> items) async {
    await _database.batch((Batch batch) {
      batch.insertAll(
        _database.libraryMediaItems,
        items,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> removeMissing(int folderId, Set<String> seen) async {
    final List<LibraryMediaItem> existing = await mediaForFolder(folderId);
    final List<String> missing = [
      for (final item in existing)
        if (!seen.contains(item.uri)) item.uri,
    ];
    if (missing.isEmpty) return;
    await (_database.delete(
      _database.libraryMediaItems,
    )..where((LibraryMediaItems m) => m.uri.isIn(missing))).go();
  }

  Future<void> markScanned(int folderId, DateTime time) =>
      (_database.update(_database.savedFolders)
            ..where((SavedFolders f) => f.id.equals(folderId)))
          .write(SavedFoldersCompanion(lastScannedAt: Value(time)));
}
