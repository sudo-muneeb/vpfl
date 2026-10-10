import 'dart:io';

import 'package:drift/native.dart';
import 'package:vpfl/data/model/app_database.dart';

/// A disposable on-disk database for persistence and migration contracts.
class IsolatedDatabase {
  IsolatedDatabase._(this.directory);

  final Directory directory;
  File get file => File('${directory.path}/vpfl.sqlite');

  static Future<IsolatedDatabase> create() async => IsolatedDatabase._(
    await Directory.systemTemp.createTemp('vpfl-db-test-'),
  );

  AppDatabase open() => AppDatabase(NativeDatabase(file));

  Future<void> dispose() => directory.delete(recursive: true);
}
