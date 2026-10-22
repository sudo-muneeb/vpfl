import 'package:vpfl_desktop_linux/vpfl_desktop_linux.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vpfl_desktop_linux');
  const manager = VpflDesktopLinux();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('queries desktop availability and per-MIME defaults', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isAvailable') return true;
          if (call.method == 'getDefaultApplication') {
            return call.arguments == 'video/mp4'
                ? 'vpfl.desktop'
                : 'other.desktop';
          }
          return null;
        });
    expect(await manager.isAvailable('vpfl.desktop'), isTrue);
    expect(
      await manager.getDefaultStatus('vpfl.desktop', [
        'video/mp4',
        'video/webm',
      ]),
      {'video/mp4': true, 'video/webm': false},
    );
  });

  test('returns verified per-format failures', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'setDefaultForMimeTypes');
          return {
            'results': {'video/mp4': true, 'video/webm': false},
            'errors': {'video/webm': 'Denied by desktop'},
          };
        });
    final result = await manager.setDefaultForMimeTypes('vpfl.desktop', [
      'video/mp4',
      'video/webm',
    ]);
    expect(result.success, isFalse);
    expect(result.results['video/mp4'], isTrue);
    expect(result.errors['video/webm'], 'Denied by desktop');
  });

  test('passes an encoded folder URI to FileManager1 bridge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'showFolder');
          expect(call.arguments, 'file:///home/me/a%20%25%20%C3%A9/');
          return true;
        });
    expect(await manager.showFolder(Uri.directory('/home/me/a % é')), true);
    await expectLater(
      manager.showFolder(Uri.https('example.com', '/videos/')),
      throwsArgumentError,
    );
  });
}
