import 'dart:io';

import 'package:default_manager_linux/default_manager_linux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GIO sets and verifies a default in an isolated XDG profile', (
    tester,
  ) async {
    if (Platform.environment['VPFL_TEST_XDG_DEFAULTS'] != '1') {
      throw StateError('Run this test only with an isolated XDG profile.');
    }
    final String? dataHome = Platform.environment['XDG_DATA_HOME'];
    final String? configHome = Platform.environment['XDG_CONFIG_HOME'];
    if (dataHome == null ||
        configHome == null ||
        !dataHome.startsWith('/tmp/') ||
        !configHome.startsWith('/tmp/')) {
      throw StateError('XDG_DATA_HOME and XDG_CONFIG_HOME must be under /tmp.');
    }

    const String desktopId = 'com.vpfl.default-manager-test.desktop';
    const String mime = 'application/x-vpfl-default-manager-test';
    final directory = Directory('$dataHome/applications');
    await directory.create(recursive: true);
    await Directory(configHome).create(recursive: true);
    await File('${directory.path}/$desktopId').writeAsString('''
[Desktop Entry]
Type=Application
Name=VPFL default manager test
Exec=/bin/true %f
MimeType=$mime;
''');

    const manager = DefaultManagerLinux();
    expect(await manager.isAvailable(desktopId), isTrue);
    final result = await manager.setDefaultForMimeTypes(desktopId, [mime]);
    expect(result.success, isTrue, reason: result.errors.toString());
    expect(await manager.getDefaultApplication(mime), desktopId);
    expect(
      await File('$configHome/mimeapps.list').readAsString(),
      contains('$mime=$desktopId;'),
    );
  });
}
