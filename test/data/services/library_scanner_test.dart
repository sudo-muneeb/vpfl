import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/library_repository.dart';
import 'package:vpfl/data/services/library_scanner.dart';

void main() {
  test('automatic scan accepts video names and rejects source files', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-scan-');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LibraryRepository(database);
    try {
      for (final name in [
        'video.mp4',
        'video.MKV',
        'movie.webm',
        'movie.mov',
        'code.ts',
        'transport.ts',
        'dependency.d',
        'video.mp4.d',
        'notes.txt',
        'script.dart',
        'package.json',
        '.hidden',
        'no-extension',
        'many.dots.Mp4',
        '.hidden.mp4',
      ]) {
        await File('${root.path}/$name').writeAsString('sample');
      }
      await Directory('${root.path}/folder.mp4').create();
      await Link('${root.path}/linked.mp4').create('${root.path}/video.mp4');

      final folder = await repository.addFolder(root.path);
      final stale = File('${root.path}/dependency.d');
      final staleStat = await stale.stat();
      await repository.upsertMedia([
        LibraryMediaItemsCompanion.insert(
          uri: Uri.file(stale.path).toString(),
          folderId: folder.id,
          path: stale.path,
          displayName: 'dependency',
          sizeBytes: staleStat.size,
          modifiedAt: staleStat.modified,
          indexedAt: DateTime.now(),
        ),
      ]);
      await LibraryScanner(repository).scan(folder);
      final names = (await repository.mediaForFolder(folder.id))
          .map((item) => item.path.split('/').last)
          .toSet();
      expect(names, {
        'video.mp4',
        'video.MKV',
        'movie.webm',
        'movie.mov',
        'many.dots.Mp4',
        '.hidden.mp4',
      });

      await File('${root.path}/video.mp4').delete();
      await LibraryScanner(repository).scan(folder);
      expect(
        (await repository.mediaForFolder(folder.id))
            .map((item) => item.path.split('/').last),
        isNot(contains('video.mp4')),
      );
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });
}
