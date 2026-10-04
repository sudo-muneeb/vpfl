import 'package:default_manager_linux/default_manager_linux.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/repositories/playback_history_repository.dart';
import 'package:vpfl/data/services/default_app_prompt_service.dart';

class FakeDefaultManager extends DefaultManagerLinux {
  FakeDefaultManager({this.installed = true, this.defaultAll = false});

  bool installed;
  bool defaultAll;

  @override
  Future<bool> isAvailable(String desktopId) async => installed;

  @override
  Future<Map<String, bool>> getDefaultStatus(
    String desktopId,
    List<String> mimeTypes,
  ) async => {for (final mime in mimeTypes) mime: defaultAll};

  @override
  Future<DefaultAppResult> setDefaultForMimeTypes(
    String desktopId,
    List<String> mimeTypes,
  ) async {
    defaultAll = true;
    return DefaultAppResult(
      results: {for (final mime in mimeTypes) mime: true},
      errors: const {},
    );
  }
}

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late FakeDefaultManager manager;
  late DateTime now;
  late DefaultAppPromptService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepository(database);
    manager = FakeDefaultManager();
    now = DateTime.utc(2026, 10, 4);
    service = DefaultAppPromptService(
      settings: settings,
      manager: manager,
      now: () => now,
    );
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  test('first prompt follows three successful plays', () async {
    await service.recordPlay();
    await service.recordPlay();
    expect(service.bannerVisible, isFalse);
    await service.recordPlay();
    expect(service.bannerVisible, isTrue);
    expect(service.promptCount, 1);
  });

  test('Maybe later waits 21 days and persists across restart', () async {
    for (var i = 0; i < 3; i++) {
      await service.recordPlay();
    }
    service.maybeLater();
    service.dispose();
    service = DefaultAppPromptService(
      settings: settings,
      manager: manager,
      now: () => now,
    );
    now = now.add(const Duration(days: 20));
    await service.recordPlay();
    expect(service.bannerVisible, isFalse);
    now = now.add(const Duration(days: 1));
    await service.recordPlay();
    expect(service.bannerVisible, isTrue);
    expect(service.promptCount, 2);
  });

  test('stops prompting after five invitations', () async {
    for (var i = 0; i < 3; i++) {
      await service.recordPlay();
    }
    for (var i = 1; i < 5; i++) {
      service.maybeLater();
      now = now.add(const Duration(days: 21));
      await service.recordPlay();
      expect(service.bannerVisible, isTrue);
    }
    service.maybeLater();
    now = now.add(const Duration(days: 21));
    await service.recordPlay();
    expect(service.bannerVisible, isFalse);
    expect(service.promptCount, 5);
  });

  test('uninstalled and already-default applications do not prompt', () async {
    manager.installed = false;
    for (var i = 0; i < 3; i++) {
      await service.recordPlay();
    }
    expect(service.bannerVisible, isFalse);
    expect(service.promptCount, 0);
    manager.installed = true;
    manager.defaultAll = true;
    await service.recordPlay();
    expect(service.bannerVisible, isFalse);
    expect(service.promptCount, 0);
  });

  test('explicit action changes all supported defaults', () async {
    await service.initialize();
    final result = await service.makeDefault();
    expect(result.success, isTrue);
    expect(service.isDefaultForAll, isTrue);
    expect(service.bannerVisible, isFalse);
  });
}
