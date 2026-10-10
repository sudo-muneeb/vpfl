import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/media_format_policy.dart';

void main() {
  test('video fixture extensions match the explicit-open policy', () {
    final manifest = jsonDecode(
      File('ci/media-matrix.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final extensions = (manifest['fixtures'] as List)
        .cast<Map<String, dynamic>>()
        .map((entry) => entry['extension'] as String)
        .toSet();
    expect(extensions, MediaFormatPolicy.supportedForExplicitOpen.toSet());
    expect(MediaFormatPolicy.mayScan('clip.ts'), isFalse);
    expect(MediaFormatPolicy.mayScan('types.d.mts'), isFalse);
  });

  test('standalone audio is outside the V1 media policy', () {
    for (final extension in [
      'mp3',
      'flac',
      'wav',
      'm4a',
      'ac3',
      'opus',
      'ogg',
    ]) {
      expect(MediaFormatPolicy.mayOpenExplicitly('track.$extension'), isFalse);
      expect(MediaFormatPolicy.mayScan('track.$extension'), isFalse);
    }
  });
}
