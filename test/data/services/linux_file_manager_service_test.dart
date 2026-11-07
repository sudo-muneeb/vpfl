import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/linux_file_manager_service.dart';

void main() {
  test('selects an existing video through FileManager1', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    final nested = await Directory('${root.path}/clips % " π').create();
    final file = File('${nested.path}/movie % " π.mp4');
    await file.writeAsBytes([1, 2, 3]);
    final requestedItems = <Uri>[];
    final requestedFolders = <Uri>[];
    var launched = false;
    final service = LinuxFileManagerService(
      showItem: (uri) async {
        requestedItems.add(uri);
        return true;
      },
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

    expect(requestedItems, [Uri.file(file.path)]);
    expect(requestedItems.single.toFilePath(), file.path);
    expect(requestedItems.single.toString(), contains('%25'));
    expect(requestedFolders, isEmpty);
    expect(launched, false);
  });

  test('opens the parent when FileManager1 cannot select the item', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    final nested = await Directory('${root.path}/clips').create();
    final file = File('${nested.path}/movie with spaces.mp4');
    await file.writeAsBytes([1, 2, 3]);
    final requestedItems = <Uri>[];
    final requestedFolders = <Uri>[];
    final launched = <Uri>[];
    final service = LinuxFileManagerService(
      showItem: (uri) async {
        requestedItems.add(uri);
        throw StateError('ShowItems unavailable');
      },
      showFolder: (uri) async {
        requestedFolders.add(uri);
        return true;
      },
      launchDirectory: (uri) async {
        launched.add(uri);
        return true;
      },
    );

    await service.showContainingFolder(file.path);

    expect(requestedItems, [Uri.file(file.path)]);
    expect(requestedFolders, [Uri.directory(nested.path)]);
    expect(launched, isEmpty);
  });

  test('launches the parent when FileManager1 rejects both methods', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/movie.mp4');
    await file.writeAsBytes([1]);
    final requests = <String>[];
    final service = LinuxFileManagerService(
      showItem: (uri) async {
        requests.add('item:${uri.toFilePath()}');
        return false;
      },
      showFolder: (uri) async {
        requests.add('folder:${uri.toFilePath()}');
        return false;
      },
      launchDirectory: (uri) async {
        requests.add('launch:${uri.toFilePath()}');
        return true;
      },
    );

    await service.showContainingFolder(file.path);

    expect(requests, [
      'item:${file.path}',
      'folder:${root.path}/',
      'launch:${root.path}/',
    ]);
  });

  test('reports a missing parent and a rejected launch', () async {
    final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
    addTearDown(() => root.delete(recursive: true));
    var launchCount = 0;
    var fileManagerCount = 0;
    final service = LinuxFileManagerService(
      showItem: (uri) async {
        fileManagerCount += 1;
        return false;
      },
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
    await File('${root.path}/video.mp4').writeAsBytes([1]);
    await expectLater(
      service.showContainingFolder('${root.path}/video.mp4'),
      throwsA(isA<FileSystemException>()),
    );
    expect(launchCount, 1);
    expect(fileManagerCount, 2);
  });

  test(
    'opens the containing folder when the video itself is missing',
    () async {
      final root = await Directory.systemTemp.createTemp('vpfl-folder-test-');
      addTearDown(() => root.delete(recursive: true));
      final requestedFolders = <Uri>[];
      final requestedItems = <Uri>[];
      final service = LinuxFileManagerService(
        showItem: (uri) async {
          requestedItems.add(uri);
          return true;
        },
        showFolder: (uri) async {
          requestedFolders.add(uri);
          return true;
        },
        launchDirectory: (_) async => false,
      );

      await service.showContainingFolder('${root.path}/moved.mp4');

      expect(requestedFolders, [Uri.directory(root.path)]);
      expect(requestedItems, isEmpty);
    },
  );
}
