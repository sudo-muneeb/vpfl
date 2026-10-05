import 'dart:io';

import 'package:path/path.dart' as path;

import '../model/app_database.dart';
import '../repositories/library_repository.dart';
import 'media_format_policy.dart';

/// Walks saved roots without following links or opening media contents.
class LibraryScanner {
  LibraryScanner(this._repository);

  final LibraryRepository _repository;

  static const int _batchSize = 100;

  Future<int> scan(SavedFolder folder) async {
    final Directory root = Directory(folder.path);
    if (!await root.exists()) return 0;
    final Map<String, LibraryMediaItem> known = await _repository
        .mediaForFolder(folder.id)
        .then(
          (List<LibraryMediaItem> items) => {
            for (final item in items) item.uri: item,
          },
        );
    final Set<String> seen = {};
    final List<Directory> pending = [root];
    final List<LibraryMediaItemsCompanion> changed = [];
    bool incomplete = false;
    int indexed = 0;
    while (pending.isNotEmpty) {
      final Directory current = pending.removeLast();
      try {
        await for (final FileSystemEntity entity in current.list(
          followLinks: false,
          recursive: false,
        )) {
          if (entity is Directory) {
            pending.add(entity);
            continue;
          }
          if (entity is! File || !MediaFormatPolicy.mayScan(entity.path)) {
            continue;
          }
          try {
            final FileStat stat = await entity.stat();
            final String uri = Uri.file(entity.path).toString();
            seen.add(uri);
            final LibraryMediaItem? previous = known[uri];
            if (previous?.sizeBytes == stat.size &&
                previous?.modifiedAt == stat.modified) {
              continue;
            }
            changed.add(
              LibraryMediaItemsCompanion.insert(
                uri: uri,
                folderId: folder.id,
                path: entity.path,
                displayName: path.basenameWithoutExtension(entity.path),
                sizeBytes: stat.size,
                modifiedAt: stat.modified,
                indexedAt: DateTime.now(),
              ),
            );
            if (changed.length >= _batchSize) {
              await _repository.upsertMedia(changed);
              indexed += changed.length;
              changed.clear();
            }
          } on FileSystemException {
            // A file may disappear or become inaccessible while scanning.
            incomplete = true;
          }
        }
      } on FileSystemException {
        // A nested directory can be inaccessible; continue with other roots.
        incomplete = true;
      }
    }
    if (changed.isNotEmpty) {
      await _repository.upsertMedia(changed);
      indexed += changed.length;
    }
    if (!incomplete) {
      await _repository.removeMissing(folder.id, seen);
      await _repository.markScanned(folder.id, DateTime.now());
    }
    return indexed;
  }
}
