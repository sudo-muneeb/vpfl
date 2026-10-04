import 'package:default_manager_linux/default_manager_linux.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('default_manager_linux');
  const manager = DefaultManagerLinux();

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
}
