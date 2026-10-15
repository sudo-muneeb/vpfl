import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/services/playback_service.dart';

import 'support/subtitle_integration_helpers.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

Future<Uint8List> _pixels(
  PlaybackService playback, {
  required bool includeSubtitles,
}) async {
  final png = await playback.screenshot(includeSubtitles: includeSubtitles);
  if (png == null) throw StateError('Native screenshot unavailable');
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    try {
      if (frame.image.width != 640 || frame.image.height != 360) {
        throw StateError(
          'Screenshot is ${frame.image.width}x${frame.image.height}, expected 640x360',
        );
      }
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (bytes == null) throw StateError('Screenshot decode unavailable');
      return bytes.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

int _differentPixels(Uint8List left, Uint8List right) {
  if (left.length != right.length) throw StateError('Screenshot sizes differ');
  var count = 0;
  for (var pixel = 0; pixel < left.length; pixel += 4) {
    if (left[pixel] != right[pixel] ||
        left[pixel + 1] != right[pixel + 1] ||
        left[pixel + 2] != right[pixel + 2]) {
      count++;
    }
  }
  return count;
}

Future<void> _expectCaptionAt(
  PlaybackService playback,
  Duration position, {
  required bool visible,
}) async {
  await playback.seek(position - const Duration(milliseconds: 100));
  await playback.seek(position);
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  int? difference;
  String? cue;
  double? actualPosition;
  while (DateTime.now().isBefore(deadline)) {
    actualPosition = await playback.nativeTimePositionSeconds();
    if ((actualPosition - position.inMilliseconds / 1000).abs() <= 0.13) {
      try {
        final withSubtitles = await _pixels(playback, includeSubtitles: true);
        final withoutSubtitles = await _pixels(
          playback,
          includeSubtitles: false,
        );
        difference = _differentPixels(withSubtitles, withoutSubtitles);
        cue = await playback.nativeSubtitleText();
        if (visible && difference > 500 && cue.contains('ENGLISH FIRST')) {
          return;
        }
        if (!visible && difference < 10 && cue.isEmpty) return;
      } on StateError {
        // The first decoded frame may still be the controller's 1×1 surface.
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TestFailure(
    'Caption at ${position.inMilliseconds} ms: expected visible=$visible, '
    'actual position=$actualPosition, changed pixels=$difference, text=$cue',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('native delay shifts pixels and resets across sources', (
    tester,
  ) async {
    final root = Directory('$_fixturesPath/subtitle-suite');
    expect(root.existsSync(), isTrue);
    final playback = PlaybackService();
    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        MaterialApp(home: Video(controller: playback.videoController)),
      );
      await waitForSubtitleRenderer(tester, playback);
      await openSubtitleVideo(playback, '${root.path}/embedded_srt.mkv', 1);
      expect(await playback.nativeSubtitleDelayMilliseconds(), 0);
      final subtitle = RealMediaTracks(playback.tracks).subtitle.single;
      await playback.setTrack(subtitle);
      await _expectCaptionAt(
        playback,
        const Duration(milliseconds: 1200),
        visible: true,
      );

      for (var step = 0; step < 5; step++) {
        await playback.adjustSubtitleDelay(-100);
      }
      expect(await playback.nativeSubtitleDelayMilliseconds(), -500);
      expect(playback.subtitleDelayMilliseconds, -500);
      await _expectCaptionAt(
        playback,
        const Duration(milliseconds: 1200),
        visible: true,
      );
      await _expectCaptionAt(
        playback,
        const Duration(milliseconds: 2200),
        visible: false,
      );
      await playback.resetSubtitleDelay();
      await _expectCaptionAt(
        playback,
        const Duration(milliseconds: 2200),
        visible: true,
      );

      for (var step = 0; step < 5; step++) {
        await playback.adjustSubtitleDelay(100);
      }
      expect(await playback.nativeSubtitleDelayMilliseconds(), 500);
      await _expectCaptionAt(
        playback,
        const Duration(milliseconds: 1200),
        visible: false,
      );

      await playback.setTrack(SubtitleTrack.no());
      await playback.seek(const Duration(seconds: 4));
      await playback.setTrack(subtitle);
      expect(await playback.nativeSubtitleDelayMilliseconds(), 500);

      await Future.wait(
        List.generate(10, (_) => playback.adjustSubtitleDelay(100)),
      );
      expect(await playback.nativeSubtitleDelayMilliseconds(), 1500);
      await Future.wait(
        List.generate(35, (_) => playback.adjustSubtitleDelay(100)),
      );
      expect(await playback.nativeSubtitleDelayMilliseconds(), 5000);
      await playback.adjustSubtitleDelay(100);
      expect(await playback.nativeSubtitleDelayMilliseconds(), 5000);
      await playback.resetSubtitleDelay();
      expect(await playback.nativeSubtitleDelayMilliseconds(), 0);
      expect(playback.subtitleDelayMilliseconds, 0);

      await playback.adjustSubtitleDelay(100);
      await Future.wait([
        playback.adjustSubtitleDelay(100),
        openSubtitleVideo(playback, '${root.path}/plain.mp4', 0),
      ]);
      expect(await playback.nativeSubtitleDelayMilliseconds(), 0);
      await openSubtitleVideo(playback, '${root.path}/embedded_srt.mkv', 1);
      expect(await playback.nativeSubtitleDelayMilliseconds(), 0);
      await playback.adjustSubtitleDelay(-100);
      await playback.stop();
      expect(await playback.nativeSubtitleDelayMilliseconds(), 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await playback.dispose();
      final reopened = PlaybackService();
      try {
        await reopened.useNullAudioOutput();
        await tester.pumpWidget(
          MaterialApp(home: Video(controller: reopened.videoController)),
        );
        await waitForSubtitleRenderer(tester, reopened);
        await openSubtitleVideo(reopened, '${root.path}/embedded_srt.mkv', 1);
        expect(await reopened.nativeSubtitleDelayMilliseconds(), 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await reopened.dispose();
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await playback.dispose();
    }
  });
}
