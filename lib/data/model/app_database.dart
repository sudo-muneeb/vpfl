import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path;

part 'app_database.g.dart';

class PlaybackHistories extends Table {
  TextColumn get uri => text()();
  TextColumn get displayName => text()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get watchCount => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SavedFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
}

class LibraryMediaItems extends Table {
  TextColumn get uri => text()();
  IntColumn get folderId => integer().references(SavedFolders, #id)();
  TextColumn get path => text()();
  TextColumn get displayName => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get modifiedAt => dateTime()();
  DateTimeColumn get indexedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {uri};
}

@DriftDatabase(
  tables: [PlaybackHistories, AppSettings, SavedFolders, LibraryMediaItems],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'vpfl',
              native: DriftNativeOptions(
                databaseDirectory: _applicationDataDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.createTable(savedFolders);
        await migrator.createTable(libraryMediaItems);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

Future<String> _applicationDataDirectory() async {
  final String? xdgDataHome = Platform.environment['XDG_DATA_HOME'];
  final String home = Platform.environment['HOME'] ?? Directory.current.path;
  final String dataHome = xdgDataHome != null && xdgDataHome.isNotEmpty
      ? xdgDataHome
      : path.join(home, '.local', 'share');
  final Directory directory = Directory(path.join(dataHome, 'vpfl'));
  await directory.create(recursive: true);
  return directory.path;
}
