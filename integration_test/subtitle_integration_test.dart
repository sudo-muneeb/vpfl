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

  testWidgets('loading an automatically discovered subtitle reuses its track', (
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
      await openSubtitleVideo(playback, '${root.path}/nearby/movie.mkv', 2);
      await playback.loadSubtitleFile('${root.path}/nearby/movie.srt');
      expect(RealMediaTracks(playback.tracks).subtitle, hasLength(2));
      expect(await playback.nativeSubtitleTrackCount(), 2);
      expect(
        playback.selectedTracks.subtitle.id,
        await playback.effectiveSubtitleId(),
      );
      await playback.loadSubtitleFile('${root.path}/nearby/movie.srt');
      expect(RealMediaTracks(playback.tracks).subtitle, hasLength(2));
      expect(await playback.nativeSubtitleTrackCount(), 2);
      await Future.wait([
        playback.loadSubtitleFile('${root.path}/nearby/movie.srt'),
        playback.loadSubtitleFile('${root.path}/nearby/movie.srt'),
        playback.loadSubtitleFile('${root.path}/nearby/movie.srt'),
      ]);
      expect(await playback.nativeSubtitleTrackCount(), 2);

      final available = RealMediaTracks(playback.tracks).subtitle;
      await playback.seek(const Duration(seconds: 4));
      await Future.wait([
        playback.setTrack(available.first),
        playback.setTrack(available.last),
      ]);
      expect(playback.selectedTracks.subtitle.id, available.last.id);
      expect(await playback.effectiveSubtitleId(), available.last.id);

      await playback.setTrack(SubtitleTrack.no());
      expect(playback.selectedTracks.subtitle.id, 'no');
      expect(await playback.effectiveSubtitleId(), 'no');
      await playback.setTrack(SubtitleTrack.auto());
      expect(playback.selectedTracks.subtitle.id, 'auto');
      expect(await playback.effectiveSubtitleId(), isNot('no'));

      await openSubtitleVideo(playback, '${root.path}/plain.mp4', 0);
      expect(playback.selectedTracks.subtitle.id, 'auto');
      await openSubtitleVideo(playback, '${root.path}/nearby/movie.mkv', 2);
      expect(await playback.nativeSubtitleTrackCount(), 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.dispose();
    }
  });

  testWidgets('rejected subtitle does not report a successful load', (
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
      await expectLater(
        playback.loadSubtitleFile('${root.path}/external/malformed.srt'),
        throwsA(isA<SubtitleLoadException>()),
      );
      expect(RealMediaTracks(playback.tracks).subtitle, isEmpty);
      expect(await playback.nativeSubtitleTrackCount(), 0);
      expect(playback.selectedTracks.subtitle.id, 'auto');
      await playback.loadSubtitleFile('${root.path}/external/english.srt');
      expect(RealMediaTracks(playback.tracks).subtitle, hasLength(1));
      expect(await playback.nativeSubtitleTrackCount(), 1);
      final validSid = await playback.effectiveSubtitleId();
      await expectLater(
        playback.loadSubtitleFile('${root.path}/external/malformed.srt'),
        throwsA(isA<SubtitleLoadException>()),
      );
      expect(await playback.nativeSubtitleTrackCount(), 1);
      expect(await playback.effectiveSubtitleId(), validSid);
      expect(playback.selectedTracks.subtitle.id, validSid);
      expect(playback.hasVideoOutput, isTrue);
      await playback.loadSubtitleFile('${root.path}/external/english.ass');
      expect(await playback.nativeSubtitleTrackCount(), 2);
      await expectLater(
        playback.loadSubtitleFile('${root.path}/external/absent.srt'),
        throwsA(isA<FileSystemException>()),
      );
      final unsupported = File(
        'build/ci-native-subtitles/part4/unsupported.txt',
      );
      unsupported.parent.createSync(recursive: true);
      unsupported.writeAsStringSync('not a subtitle');
      try {
        await expectLater(
          playback.loadSubtitleFile(unsupported.path),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        unsupported.deleteSync();
      }
      expect(await playback.nativeSubtitleTrackCount(), 2);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.dispose();
    }
  });
}
