import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vpfl_desktop_linux/vpfl_desktop_linux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native FileManager1 request opens the containing folder', (
    tester,
  ) async {
    if (Platform.environment['VPFL_TEST_FAKE_FILE_MANAGER1'] != '1') {
      throw StateError('Run under an isolated D-Bus session with the fixture.');
    }
    final fixture = File('test/ci/file_manager1_fixture.py').absolute;
    final process = await Process.start('python3', [fixture.path]);
    addTearDown(() async {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    });
    final ready = Completer<void>();
    final requestedUri = Completer<String>();
    final stderrText = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(stderrText.write);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line == 'READY' && !ready.isCompleted) ready.complete();
          if (line.startsWith('URI ') && !requestedUri.isCompleted) {
            requestedUri.complete(line.substring(4));
          }
        });
    await ready.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('FileManager1 fixture: $stderrText'),
    );
    final directory = await Directory.systemTemp.createTemp('vpfl folder % é ');
    addTearDown(() => directory.delete(recursive: true));
    final expected = Uri.directory(directory.path);

    final opened = await const VpflDesktopLinux()
        .showFolder(expected)
        .timeout(const Duration(seconds: 6));

    expect(opened, isTrue, reason: stderrText.toString());
    expect(
      await requestedUri.future.timeout(const Duration(seconds: 3)),
      expected.toString(),
    );
  });
}
