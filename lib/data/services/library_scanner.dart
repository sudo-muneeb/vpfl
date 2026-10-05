import 'dart:io';

import 'package:path/path.dart' as path;

import '../model/app_database.dart';
import '../repositories/library_repository.dart';
import 'media_format_policy.dart';
import 'lifecycle_trace.dart';

/// Walks saved roots without following links or decoding media. A short `.mts`
/// packet probe distinguishes transport streams from TypeScript modules.
class LibraryScanner {
  LibraryScanner(this._repository);

  final LibraryRepository _repository;

  static const int _batchSize = 100;

  Future<int> scan(SavedFolder folder) async {
    final Directory root = Directory(folder.path);
    final Map<String, LibraryMediaItem> known = await _repository
        .mediaForFolder(folder.id)
        .then(
          (List<LibraryMediaItem> items) => {
            for (final item in items) item.uri: item,
          },
        );
    final rejected = <String>[];
    for (final item in known.values) {
      if (!MediaFormatPolicy.shouldAutomaticallyIndex(item.path)) {
        rejected.add(item.uri);
      } else if (MediaFormatPolicy.extensionOf(item.path) == 'mts') {
        try {
          final file = File(item.path);
          if (await file.exists() &&
              !await MediaFormatPolicy.hasTransportStreamSignature(file)) {
            rejected.add(item.uri);
          }
        } on FileSystemException {
          // Retain an unreadable row until a complete walk can verify it.
        }
      }
    }
    await _repository.removeUris(folder.id, rejected);
    if (rejected.isNotEmpty) {
      LifecycleTrace.event(
        'media.db.remove_rejected',
        detail: 'folder=${folder.id} count=${rejected.length}',
      );
    }
    if (!await root.exists()) return 0;
    final rootPath = await root.resolveSymbolicLinks();
    final nestedRoots = (await _repository.allFolders())
        .where((saved) => saved.id != folder.id)
        .map((saved) => saved.path)
        .where((candidate) => path.isWithin(rootPath, candidate))
        .toSet();
    final Set<String> seen = {};
    final List<Directory> pending = [Directory(rootPath)];
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
            if (!nestedRoots.contains(entity.path)) pending.add(entity);
            continue;
          }
          final reason = entity is File
              ? MediaFormatPolicy.automaticScanReason(entity.path)
              : 'not-regular-file';
          LifecycleTrace.event(
            'media.classify',
            detail:
                'path=${entity.path} extension=${MediaFormatPolicy.extensionOf(entity.path)} decision=$reason',
          );
          if (entity is! File || reason != 'accepted') {
            continue;
          }
          try {
            final FileStat stat = await entity.stat();
            if (stat.type != FileSystemEntityType.file) continue;
            if (!await MediaFormatPolicy.hasTransportStreamSignature(entity)) {
              LifecycleTrace.event(
                'media.classify',
                detail:
                    'path=${entity.path} extension=mts decision=non-transport-stream-mts',
              );
              continue;
            }
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
            LifecycleTrace.event(
              'media.db.upsert',
              detail: 'path=${entity.path}',
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
      final removed = await _repository.removeMissing(folder.id, seen);
      LifecycleTrace.event(
        'media.db.remove_missing',
        detail: 'folder=${folder.id} count=$removed',
      );
      await _repository.markScanned(folder.id, DateTime.now());
    }
    return indexed;
  }
}
