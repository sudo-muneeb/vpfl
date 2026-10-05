import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../model/app_database.dart';
import '../services/media_format_policy.dart';

class LibraryRepository {
  LibraryRepository(this._database);
  final AppDatabase _database;

  Stream<List<SavedFolder>> watchFolders() => (_database.select(
    _database.savedFolders,
  )..orderBy([(SavedFolders f) => OrderingTerm.asc(f.displayName)])).watch();

  Future<List<SavedFolder>> allFolders() =>
      _database.select(_database.savedFolders).get();

  Stream<List<LibraryMediaItem>> watchAllMedia() =>
      (_database.select(_database.libraryMediaItems)..orderBy([
            (LibraryMediaItems m) => OrderingTerm.asc(m.displayName),
          ]))
          .watch()
          .map(
            (items) => items
                .where(
                  (item) =>
                      MediaFormatPolicy.shouldAutomaticallyIndex(item.path),
                )
                .toList(growable: false),
          );

  Stream<List<LibraryMediaItem>> watchFolderMedia(int folderId) =>
      (_database.select(_database.libraryMediaItems)
            ..where((LibraryMediaItems m) => m.folderId.equals(folderId))
            ..orderBy([
              (LibraryMediaItems m) => OrderingTerm.asc(m.displayName),
            ]))
          .watch()
          .map(
            (items) => items
                .where(
                  (item) =>
                      MediaFormatPolicy.shouldAutomaticallyIndex(item.path),
                )
                .toList(growable: false),
          );

  Future<List<LibraryMediaItem>> mediaForFolder(int folderId) =>
      (_database.select(
        _database.libraryMediaItems,
      )..where((LibraryMediaItems m) => m.folderId.equals(folderId))).get();

  Future<SavedFolder> addFolder(String folderPath) async {
    String normalized;
    try {
      normalized = await Directory(folderPath).resolveSymbolicLinks();
    } on FileSystemException {
      normalized = path.normalize(path.absolute(folderPath));
    }
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

  Future<int> removeMissing(int folderId, Set<String> seen) async {
    final List<LibraryMediaItem> existing = await mediaForFolder(folderId);
    final List<String> missing = [
      for (final item in existing)
        if (!seen.contains(item.uri)) item.uri,
    ];
    if (missing.isEmpty) return 0;
    await removeUris(folderId, missing);
    return missing.length;
  }

  Future<void> removeUris(int folderId, Iterable<String> uris) async {
    final values = uris.toList(growable: false);
    for (var offset = 0; offset < values.length; offset += 400) {
      final chunk = values.skip(offset).take(400).toList(growable: false);
      await (_database.delete(
        _database.libraryMediaItems,
      )..where((m) => m.folderId.equals(folderId) & m.uri.isIn(chunk))).go();
    }
  }

  Future<void> markScanned(int folderId, DateTime time) =>
      (_database.update(_database.savedFolders)
            ..where((SavedFolders f) => f.id.equals(folderId)))
          .write(SavedFoldersCompanion(lastScannedAt: Value(time)));
}
