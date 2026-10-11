import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/repositories/playback_history_repository.dart';

import '../../support/isolated_database.dart';

void main() {
  test('schema 1 history and settings survive upgrade to schema 2', () async {
    final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final storage = await IsolatedDatabase.create();
    addTearDown(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
      await storage.dispose();
    });

    // Schema 1 at e390c16 had only playback_histories and app_settings;
    // the existing columns are unchanged in schema 2. Reconstruct that
    // historical table set without copying any personal database.
    final historical = storage.open();
    await PlaybackHistoryRepository(historical).recordStarted(
      uri: 'file:///videos/legacy.mp4',
      displayName: 'legacy.mp4',
      duration: const Duration(minutes: 2),
    );
    await SettingsRepository(historical).setValue('themeMode', 'dark');
    await historical.customStatement('DROP TABLE library_media_items');
    await historical.customStatement('DROP TABLE saved_folders');
    await historical.customStatement('PRAGMA user_version = 1');
    await historical.close();

    final upgraded = storage.open();
    expect(upgraded.schemaVersion, 2);
    expect(
      (await PlaybackHistoryRepository(upgraded)
              .find('file:///videos/legacy.mp4'))
          ?.displayName,
      'legacy.mp4',
    );
    final settings = SettingsRepository(upgraded);
    expect(await settings.getValue('themeMode'), 'dark');
    expect(
      await upgraded
          .customSelect('PRAGMA integrity_check')
          .getSingle()
          .then((row) => row.data['integrity_check']),
      'ok',
    );
    expect(
      await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((row) => row.data['user_version']),
      2,
    );
    expect(
      await upgraded
          .customSelect('SELECT COUNT(*) AS count FROM saved_folders')
          .getSingle()
          .then((row) => row.data['count']),
      0,
    );
    await upgraded.close();

    final reopened = storage.open();
    expect(await SettingsRepository(reopened).getValue('themeMode'), 'dark');
    await SettingsRepository(reopened).setValue('historyEnabled', 'invalid');
    expect(
      await SettingsRepository(reopened)
          .getBool('historyEnabled', defaultValue: true),
      isTrue,
    );
    await reopened.close();
  });
}
