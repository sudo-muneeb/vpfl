import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/services/playback_service.dart';

Future<void> waitForSubtitleTracks(PlaybackService playback, int count) async {
  if (RealMediaTracks(playback.tracks).subtitle.length == count) return;
  await playback.tracksStream
      .firstWhere((tracks) => RealMediaTracks(tracks).subtitle.length == count)
      .timeout(const Duration(seconds: 8));
}

Future<void> openSubtitleVideo(
  PlaybackService playback,
  String filePath,
  int subtitleCount,
) async {
  await playback.open(File(filePath).absolute.uri.toString());
  await waitForSubtitleTracks(playback, subtitleCount);
  expect(await playback.nativeSubtitleTrackCount(), subtitleCount);
  if (playback.isPlaying) await playback.playOrPause();
}

Future<void> waitForSubtitleRenderer(
  WidgetTester tester,
  PlaybackService playback,
) async {
  final output = await playback.videoController.platform.future.timeout(
    const Duration(seconds: 10),
  );
  for (var attempt = 0; attempt < 80; attempt++) {
    final mode = output.renderingMode.value;
    if (mode == 'gpu' || mode == 'software') return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw StateError(
    'Video renderer did not become ready: ${output.renderingMode.value}',
  );
}
