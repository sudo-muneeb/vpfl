import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vpfl/data/services/subtitle_file_identity.dart';

void main() {
  test(
    'local subtitle identity uses path, URI decoding, and symlink target',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vpfl-subtitle-id-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File(path.join(directory.path, 'Caption 50%.srt'))
        ..writeAsStringSync('one');
      final link = Link(path.join(directory.path, 'alias.srt'))
        ..createSync(source.path);

      final canonical = await canonicalSubtitlePath(source.path);
      expect(await canonicalSubtitlePath(source.uri.toString()), canonical);
      expect(await canonicalSubtitlePath(link.path), canonical);
      expect(
        await canonicalSubtitlePath(path.relative(source.path)),
        canonical,
      );
    },
  );

  test(
    'distinct case and directory remain distinct even with same basename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vpfl-subtitle-id-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final first = File(path.join(directory.path, 'one', 'same.srt'))
        ..createSync(recursive: true);
      final second = File(path.join(directory.path, 'two', 'same.srt'))
        ..createSync(recursive: true);
      final caseVariant = File(path.join(directory.path, 'one', 'Same.srt'))
        ..createSync();

      expect(
        await canonicalSubtitlePath(first.path),
        isNot(await canonicalSubtitlePath(second.path)),
      );
      expect(
        await canonicalSubtitlePath(first.path),
        isNot(await canonicalSubtitlePath(caseVariant.path)),
      );
      expect(
        await canonicalSubtitlePath('https://example.com/same.srt'),
        isNull,
      );
    },
  );
}
