import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/library_repository.dart';
import 'package:vpfl/data/services/library_scanner.dart';
import 'package:vpfl/data/services/media_format_policy.dart';

void main() {
  test('automatic scan accepts video names and rejects source files', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-scan-');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LibraryRepository(database);
    try {
      for (final name in [
        'real.mp4',
        'real.MKV',
        'real.webm',
        'plain.d',
        'source.ts',
        'types.d.ts',
        'types.d.mts',
        'types.d.cts',
        'movie.mp4.d',
        'movie.mts.d',
        'foo.txt',
        'foo.dart',
        'foo.js',
        '.hidden',
        'no-extension',
        'many.dots.Mp4',
        '.hidden.mp4',
      ]) {
        await File('${root.path}/$name').writeAsString('sample');
      }
      final transportStream = List<int>.filled(188 * 3, 0);
      for (final offset in [0, 188, 376]) {
        transportStream[offset] = 0x47;
      }
      await File('${root.path}/recording.mts').writeAsBytes(transportStream);
      await Directory('${root.path}/node_modules/pkg').create(recursive: true);
      for (final name in [
        'index.d.ts',
        'module.d.mts',
        'types.d',
        'index-browser.mts',
        'video.mp4',
      ]) {
        await File('${root.path}/node_modules/pkg/$name')
            .writeAsString('sample');
      }
      await Directory('${root.path}/folder.mp4').create();
      await Link('${root.path}/linked.mp4').create('${root.path}/real.mp4');

      final folder = await repository.addFolder(root.path);
      for (final name in [
        'plain.d',
        'source.ts',
        'types.d.mts',
        'missing.mp4',
      ]) {
        final file = File('${root.path}/$name');
        final stat = await file.stat();
        await repository.upsertMedia([
          LibraryMediaItemsCompanion.insert(
            uri: Uri.file(file.path).toString(),
            folderId: folder.id,
            path: file.path,
            displayName: name,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
            indexedAt: DateTime.now(),
          ),
        ]);
      }
      expect((await repository.mediaForFolder(folder.id)).length, 4);
      expect(
        (await repository.watchAllMedia().first).map(
          (item) => item.displayName,
        ),
        ['missing.mp4'],
      );
      await LibraryScanner(repository).scan(folder);
      final names = (await repository.mediaForFolder(folder.id))
          .map((item) => item.path.split('/').last)
          .toSet();
      expect(names, {
        'real.mp4',
        'real.MKV',
        'real.webm',
        'recording.mts',
        'many.dots.Mp4',
        '.hidden.mp4',
        'video.mp4',
      });

      await File('${root.path}/real.mp4').delete();
      await LibraryScanner(repository).scan(folder);
      expect(
        (await repository.mediaForFolder(folder.id))
            .map((item) => item.path.split('/').last),
        isNot(contains('real.mp4')),
      );
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });

  test('compound declarations are rejected before final extension checks', () {
    for (final path in [
      'plain.d',
      'source.ts',
      'types.d.ts',
      'types.d.mts',
      'types.d.cts',
      'movie.mp4.d',
      'video.mp4.tmp',
      'foo.mts.d',
    ]) {
      expect(
        MediaFormatPolicy.shouldAutomaticallyIndex(path),
        isFalse,
        reason: path,
      );
    }
    for (final path in ['video.mp4', 'VIDEO.MP4', 'movie.mkv', 'camera.mts']) {
      expect(
        MediaFormatPolicy.shouldAutomaticallyIndex(path),
        isTrue,
        reason: path,
      );
    }
    expect(MediaFormatPolicy.mayOpenExplicitly('movie.ts'), isTrue);
    expect(MediaFormatPolicy.mayOpenExplicitly('types.d.mts'), isFalse);
  });

  test(
    'overlapping roots keep one canonical row owned by inner root',
    () async {
      final root = await Directory.systemTemp.createTemp('vpfl-overlap-');
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LibraryRepository(database);
      try {
        final inner = await Directory('${root.path}/inner').create();
        await File('${inner.path}/clip.mp4').writeAsString('sample');
        final parentFolder = await repository.addFolder(root.path);
        final innerFolder = await repository.addFolder(inner.path);
        final scanner = LibraryScanner(repository);
        await scanner.scan(parentFolder);
        await scanner.scan(innerFolder);
        await scanner.scan(parentFolder);
        final rows = await repository.watchAllMedia().first;
        expect(rows, hasLength(1));
        expect(rows.single.folderId, innerFolder.id);
      } finally {
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
}
