import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/services/playback_service.dart';

import 'support/subtitle_integration_helpers.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets(
    'new files remain distinct and rapid repeat loads add one track',
    (tester) async {
      final playback = PlaybackService();
      final root = Directory('$_fixturesPath/subtitle-suite');
      final output = await Directory('build/ci-native-subtitles/part4')
          .create(recursive: true);
      final temporary = await output.createTemp('subtitle-');
      final duplicateName = await Directory('${temporary.path}/different')
          .create(recursive: true);
      final second = await File('${root.path}/external/english.srt')
          .copy('${duplicateName.path}/english.srt');
      try {
        await playback.useNullAudioOutput();
        await tester.pumpWidget(
          MaterialApp(home: Video(controller: playback.videoController)),
        );
        await waitForSubtitleRenderer(tester, playback);
        await openSubtitleVideo(playback, '${root.path}/plain.mp4', 0);
        final first = '${root.path}/external/english.srt';
        await Future.wait([
          playback.loadSubtitleFile(first),
          playback.loadSubtitleFile(first),
          playback.loadSubtitleFile(first),
        ]);
        expect(await playback.nativeSubtitleTrackCount(), 1);
        final alias = Link('${temporary.path}/alias.srt')
          ..createSync(File(first).absolute.path);
        await playback.loadSubtitleFile(alias.path);
        expect(await playback.nativeSubtitleTrackCount(), 1);
        await playback.loadSubtitleFile(File(first).absolute.uri.toString());
        expect(await playback.nativeSubtitleTrackCount(), 1);
        await playback.loadSubtitleFile(second.path);
        expect(await playback.nativeSubtitleTrackCount(), 2);
        expect(
          RealMediaTracks(playback.tracks).subtitle
              .map((track) => track.title)
              .toSet(),
          {'english.srt'},
        );
        await openSubtitleVideo(playback, '${root.path}/embedded_srt.mkv', 1);
        await openSubtitleVideo(playback, '${root.path}/plain.mp4', 0);
        expect(playback.selectedTracks.subtitle.id, 'auto');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await playback.dispose();
        await temporary.delete(recursive: true);
      }
    },
  );
}
