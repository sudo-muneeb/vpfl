import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/library_repository.dart';
import 'package:vpfl/data/services/library_scanner.dart';
import 'package:vpfl/data/services/media_format_policy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const runOnActiveDatabase = bool.fromEnvironment('VPFL_RESCAN_ACTIVE_DB');

  testWidgets(
    'rescan saved folders in the active database',
    (tester) async {
      final database = AppDatabase();
      try {
        final repository = LibraryRepository(database);
        final scanner = LibraryScanner(repository);
        for (final folder in await repository.allFolders()) {
          final before = (await repository.mediaForFolder(folder.id)).length;
          final upserts = await scanner.scan(folder);
          final after = (await repository.mediaForFolder(folder.id)).length;
          debugPrint(
            '${folder.path}: before=$before upserts=$upserts after=$after',
          );
        }
        final rows = await repository.watchAllMedia().first;
        expect(
          rows.every(
            (item) => MediaFormatPolicy.shouldAutomaticallyIndex(item.path),
          ),
          isTrue,
        );
        debugPrint('active library valid rows=${rows.length}');
      } finally {
        await database.close();
      }
    },
    skip: !runOnActiveDatabase,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
