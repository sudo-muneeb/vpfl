import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/media_source_identity.dart';

void main() {
  test('local path and file URI identify the same source', () {
    final directory = Directory.systemTemp.absolute;
    for (final name in ['clip.mp4', 'a video ü.mkv']) {
      final path = '${directory.path}/$name';
      final uri = Uri.file(path).toString();
      expect(canonicalMediaUri(path), uri);
      expect(canonicalMediaUri(uri), uri);
    }
  });

  test('different paths stay distinct and remote URIs are retained', () {
    expect(
      canonicalMediaUri('/videos/a.mp4'),
      isNot(canonicalMediaUri('/other/a.mp4')),
    );
    expect(
      canonicalMediaUri('https://example.test/a.mp4'),
      'https://example.test/a.mp4',
    );
  });
}
