import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/services/playback_service.dart';

import 'support/subtitle_integration_helpers.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('source change and disposal drain an in-flight subtitle load', (
    tester,
  ) async {
    final playback = PlaybackService();
    final root = Directory('$_fixturesPath/subtitle-suite');
    expect(root.existsSync(), isTrue);
    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        MaterialApp(home: Video(controller: playback.videoController)),
      );
      await waitForSubtitleRenderer(tester, playback);
      await openSubtitleVideo(playback, '${root.path}/plain.mp4', 0);

      final requested = playback.selectedTracksStream.firstWhere(
        (selection) => selection.subtitle.uri,
      );
      final loading = playback.loadSubtitleFile(
        '${root.path}/external/english.srt',
      );
      await requested.timeout(const Duration(seconds: 8));
      final changing = playback.open(
        File('${root.path}/nearby/movie.mkv').absolute.uri.toString(),
      );
      await Future.wait([loading, changing]);
      await waitForSubtitleTracks(playback, 2);
      expect(await playback.nativeSubtitleTrackCount(), 2);
      expect(playback.selectedTracks.subtitle.id, 'auto');

      await playback.loadSubtitleFile('${root.path}/nearby/movie.ur.srt');
      expect(await playback.nativeSubtitleTrackCount(), 2);
      final nextRequest = playback.selectedTracksStream.firstWhere(
        (selection) => selection.subtitle.uri,
      );
      await openSubtitleVideo(playback, '${root.path}/plain.mp4', 0);
      final closing = playback.loadSubtitleFile(
        '${root.path}/external/english.ass',
      );
      await nextRequest.timeout(const Duration(seconds: 8));
      await playback.dispose();
      await closing;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.dispose();
    }
  });
}
