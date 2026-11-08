import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/library_repository.dart';

void main() {
  late AppDatabase database;
  late LibraryRepository repository;
  late Directory root;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LibraryRepository(database);
    root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'adding an existing folder returns its record without resetting it',
    () async {
      final Directory folder = await Directory('${root.path}/Videos').create();
      final SavedFolder first = await repository.addFolder(folder.path);
      final DateTime scannedAt = DateTime(2025, 1, 2);
      await repository.markScanned(first.id, scannedAt);

      final SavedFolder repeated = await repository.addFolder(folder.path);

      expect(repeated.id, first.id);
      expect(repeated.addedAt, first.addedAt);
      expect(repeated.lastScannedAt, scannedAt);
      expect(await repository.allFolders(), hasLength(1));
    },
  );

  test(
    'different paths add separate folders and aliases reuse the same one',
    () async {
      final Directory firstPath = await Directory('${root.path}/One').create();
      final Directory secondPath = await Directory('${root.path}/Two').create();
      final Link alias = await Link('${root.path}/Alias')
          .create(firstPath.path);

      final SavedFolder first = await repository.addFolder(firstPath.path);
      final SavedFolder second = await repository.addFolder(secondPath.path);
      final SavedFolder viaAlias = await repository.addFolder(alias.path);

      expect(second.id, isNot(first.id));
      expect(viaAlias.id, first.id);
      expect(await repository.allFolders(), hasLength(2));
    },
  );
}
