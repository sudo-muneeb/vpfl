import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/services/media_metadata_service.dart';
import 'package:vpfl/data/services/media_source_identity.dart';
import 'package:vpfl/data/services/playback_service.dart';

const _fixturesPath = String.fromEnvironment('VPFL_CI_FIXTURES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('paused inspection reads real mpv tracks without playback', (
    tester,
  ) async {
    final file = File('$_fixturesPath/h264_mp4.mp4');
    expect(
      await file.exists(),
      true,
      reason: 'Generate CI video fixtures first.',
    );
    final service = MediaMetadataService();

    final details = await service.inspect(file.path);

    expect(details.fileName, 'h264_mp4.mp4');
    expect(details.sizeBytes, greaterThan(0));
    expect(details.duration, isNotNull);
    // mpv reports this family of libavformat names for an MP4 fixture.
    expect(details.container, contains('mp4'));
    expect(details.video, isNotEmpty);
    expect(details.video.first.codec, 'H.264');
    expect(details.video.first.width, 320);
    expect(details.video.first.height, 180);
    expect(details.video.first.frameRate, closeTo(24, 0.01));
  });

  testWidgets('inspecting another file leaves active playback unchanged', (
    tester,
  ) async {
    final playingFile = File('$_fixturesPath/regression.mp4');
    final inspectedFile = File('$_fixturesPath/vp9_webm.webm');
    expect(await playingFile.exists(), true);
    expect(await inspectedFile.exists(), true);
    final playback = PlaybackService();
    addTearDown(playback.dispose);
    await playback.useNullAudioOutput();
    final playingUri = canonicalMediaUri(playingFile.path);
    await playback.open(playingUri);
    if (!playback.isPlaying) {
      await playback.playingStream
          .firstWhere((playing) => playing)
          .timeout(const Duration(seconds: 10));
    }
    final generation = playback.sourceGeneration;
    final beforePosition = playback.position;
    final service = MediaMetadataService(
      activeUri: () => playback.loadedMediaUri,
      activeSnapshot: playback.metadataSnapshotFor,
    );

    final active = await service.inspect(playingFile.path);
    final other = await service.inspect(inspectedFile.path);

    expect(active.video, isNotEmpty);
    expect(other.video, isNotEmpty);
    expect(other.video.first.codec, 'VP9');
    expect(playback.loadedMediaUri, playingUri);
    expect(playback.sourceGeneration, generation);
    expect(playback.isPlaying, true);
    if (playback.position <= beforePosition) {
      await playback.positionStream
          .firstWhere((position) => position > beforePosition)
          .timeout(const Duration(seconds: 5));
    }
    expect(playback.position, greaterThan(beforePosition));
  });
}
