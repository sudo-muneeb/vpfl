import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/thumbnail_service.dart';

void main() {
  late Directory root;
  late Directory cacheHome;
  late File media;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vpfl-thumb-test');
    cacheHome = Directory('${root.path}/cache')..createSync();
    media = File('${root.path}/clip.mp4')..writeAsBytesSync([0, 1, 2]);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  int mtimeSeconds() =>
      media.statSync().modified.millisecondsSinceEpoch ~/ 1000;

  String digest() {
    final String uri = Uri.file(media.path).normalizePath().toString();
    return md5.convert(utf8.encode(uri)).toString();
  }

  /// A PNG with only the signature, tEXt metadata, and an empty IDAT marker.
  Uint8List pngWithText(Map<String, String> text) {
    final List<int> bytes = [137, 80, 78, 71, 13, 10, 26, 10];
    void chunk(String type, List<int> data) {
      final ByteData length = ByteData(4)..setUint32(0, data.length);
      bytes
        ..addAll(length.buffer.asUint8List())
        ..addAll(ascii.encode(type))
        ..addAll(data)
        ..addAll([0, 0, 0, 0]);
    }

    for (final MapEntry<String, String> entry in text.entries) {
      chunk('tEXt', [
        ...latin1.encode(entry.key),
        0,
        ...latin1.encode(entry.value),
      ]);
    }
    chunk('IDAT', []);
    chunk('IEND', []);
    return Uint8List.fromList(bytes);
  }

  void writeFreedesktop(String size, Map<String, String> text) {
    File('${cacheHome.path}/thumbnails/$size/${digest()}.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(pngWithText(text));
  }

  test('uses a Freedesktop thumbnail whose MTime matches the file', () async {
    writeFreedesktop('normal', {'Thumb::MTime': '${mtimeSeconds()}'});

    final File? thumbnail = await ThumbnailService(cacheHome: cacheHome.path)
        .resolve(media.path);

    expect(thumbnail?.path, endsWith('/normal/${digest()}.png'));
  });

  test('rejects a Freedesktop thumbnail made from an older file', () async {
    writeFreedesktop('normal', {'Thumb::MTime': '${mtimeSeconds() - 60}'});

    final File? thumbnail = await ThumbnailService(cacheHome: cacheHome.path)
        .resolve(media.path);

    expect(thumbnail, isNull);
  });

  test(
    'rejects a Freedesktop thumbnail whose URI names another file',
    () async {
      writeFreedesktop('large', {
        'Thumb::MTime': '${mtimeSeconds()}',
        'Thumb::URI': 'file:///elsewhere/clip.mp4',
      });

      final File? thumbnail = await ThumbnailService(cacheHome: cacheHome.path)
          .resolve(media.path);

      expect(thumbnail, isNull);
    },
  );

  test('returns a VPFL frame and announces it to watchers', () async {
    final ThumbnailService service = ThumbnailService(
      cacheHome: cacheHome.path,
    );
    final Future<String> saved = service.savedFrames.first;

    await service.captureFrame(media.path, pngWithText({}));

    expect(await saved, ThumbnailService.keyFor(media.path));
    expect(await service.resolve(media.path), isNotNull);
    await service.close();
  });

  test('ignores a VPFL frame after the media file changes', () async {
    final ThumbnailService service = ThumbnailService(
      cacheHome: cacheHome.path,
    );
    await service.captureFrame(media.path, pngWithText({}));

    media.setLastModifiedSync(DateTime(2001));

    expect(await service.resolve(media.path), isNull);
    await service.close();
  });
}
