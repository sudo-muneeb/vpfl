import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/linux_file_manager_service.dart';

void main() {
  test('opens the immediate parent through FileManager1', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    final nested = await Directory('${root.path}/clips % " π').create();
    final file = File('${nested.path}/movie % " π.mp4');
    await file.writeAsBytes([1, 2, 3]);
    final requestedFolders = <Uri>[];
    var launched = false;
    final service = LinuxFileManagerService(
      showFolder: (uri) async {
        requestedFolders.add(uri);
        return true;
      },
      launchDirectory: (uri) async {
        launched = true;
        return true;
      },
    );

    await service.showContainingFolder(file.path);

    expect(requestedFolders, [Uri.directory(nested.path)]);
    expect(requestedFolders.single.toFilePath(), '${nested.path}/');
    expect(requestedFolders.single.toString(), contains('%25'));
    expect(launched, false);
  });

  test(
    'falls back to the immediate parent when FileManager1 is unavailable',
    () async {
      final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
      addTearDown(() => root.delete(recursive: true));
      final nested = await Directory('${root.path}/clips').create();
      final file = File('${nested.path}/movie with spaces.mp4');
      await file.writeAsBytes([1, 2, 3]);
      final requestedFolders = <Uri>[];
      final launched = <Uri>[];
      final service = LinuxFileManagerService(
        showFolder: (uri) async {
          requestedFolders.add(uri);
          throw StateError('FileManager1 unavailable');
        },
        launchDirectory: (uri) async {
          launched.add(uri);
          return true;
        },
      );

      await service.showContainingFolder(file.path);

      expect(requestedFolders, [Uri.directory(nested.path)]);
      expect(launched, [Uri.directory(nested.path)]);
      expect(launched.single.scheme, 'file');
    },
  );

  test('reports a missing parent and a rejected launch', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    var launchCount = 0;
    var fileManagerCount = 0;
    final service = LinuxFileManagerService(
      showFolder: (uri) async {
        fileManagerCount += 1;
        return false;
      },
      launchDirectory: (uri) async {
        launchCount += 1;
        return false;
      },
    );

    await expectLater(
      service.showContainingFolder('${root.path}/missing/video.mp4'),
      throwsA(isA<FileSystemException>()),
    );
    expect(launchCount, 0);
    await expectLater(
      service.showContainingFolder('${root.path}/video.mp4'),
      throwsA(isA<FileSystemException>()),
    );
    expect(launchCount, 1);
    expect(fileManagerCount, 1);
  });

  test(
    'opens the containing folder when the video itself is missing',
    () async {
      final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
      addTearDown(() => root.delete(recursive: true));
      final requestedFolders = <Uri>[];
      final service = LinuxFileManagerService(
        showFolder: (uri) async {
          requestedFolders.add(uri);
          return true;
        },
        launchDirectory: (_) async => false,
      );

      await service.showContainingFolder('${root.path}/moved.mp4');

      expect(requestedFolders, [Uri.directory(root.path)]);
    },
  );
}
