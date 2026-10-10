import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/ui/app.dart';

const _fixturesPath = String.fromEnvironment('VPFL_CI_FIXTURES');

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String label,
) async {
  for (var attempt = 0; attempt < 80 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    ready(),
    isTrue,
    reason: '$label did not become ready within 8 seconds',
  );
}

Future<void> _checkPatches(Uint8List bytes, String id) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    expect(
      image.width,
      greaterThanOrEqualTo(160),
      reason: '$id screenshot width',
    );
    expect(
      image.height,
      greaterThanOrEqualTo(90),
      reason: '$id screenshot height',
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull, reason: '$id screenshot cannot be decoded');
    final rgba = data!.buffer.asUint8List();
    List<int> sample(double x, double y) {
      final offset =
          ((image.height * y).floor() * image.width +
              (image.width * x).floor()) *
          4;
      return rgba.sublist(offset, offset + 3);
    }

    final red = sample(0.075, 0.13);
    final green = sample(0.925, 0.13);
    final blue = sample(0.075, 0.86);
    expect(red[0], greaterThan(red[1] + 35), reason: '$id red patch $red');
    expect(red[0], greaterThan(red[2] + 35), reason: '$id red patch $red');
    expect(
      green[1],
      greaterThan(green[0] + 25),
      reason: '$id green patch $green',
    );
    expect(
      green[1],
      greaterThan(green[2] + 25),
      reason: '$id green patch $green',
    );
    expect(blue[2], greaterThan(blue[0] + 25), reason: '$id blue patch $blue');
    expect(blue[2], greaterThan(blue[1] + 25), reason: '$id blue patch $blue');
  } finally {
    image.dispose();
    codec.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('every declared fixture plays through VPFL', (tester) async {
    final directory = Directory(_fixturesPath);
    expect(
      directory.existsSync(),
      isTrue,
      reason: 'VPFL_CI_FIXTURES is required',
    );
    final manifest = jsonDecode(
      File('ci/media-matrix.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final index = jsonDecode(
      File('${directory.path}/index.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final rows = (index['fixtures'] as List).cast<Map<String, dynamic>>();
    expect(rows, hasLength(31));
    final expectedIds = <String>{
      for (final group in [
        'fixtures',
        'subtitle_fixtures',
        'embedded_subtitle_fixtures',
      ])
        for (final entry
            in (manifest[group] as List).cast<Map<String, dynamic>>())
          entry['id'] as String,
    };
    expect(rows.map((row) => row['id']).toSet(), expectedIds);
    final byId = {for (final row in rows) row['id'] as String: row};
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    final first = byId['h264_mp4']!;
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(
            initialMediaUri: Uri.file('${directory.path}/${first['file']}')
                .toString(),
            startupError: null,
          ),
        ),
      );
      final expectedBackend = Platform.environment['VPFL_CI_DISPLAY_BACKEND'];
      if (expectedBackend != null) {
        const channel = MethodChannel('com.app.vpfl/window');
        final actualBackend = await channel.invokeMethod<String>(
          'getDisplayBackend',
        );
        expect(
          actualBackend,
          expectedBackend,
          reason: 'GTK selected a different display backend',
        );
      }
      await _until(tester, () => playback.hasVideoOutput, 'initial video');
      final output = await playback.videoController.platform.future;
      await _until(
        tester,
        () =>
            output.renderingMode.value == 'gpu' ||
            output.renderingMode.value == 'software',
        'native renderer',
      );
      if (Platform.environment['VPFL_TEST_FAIL_GPU_INIT'] == '1') {
        expect(
          output.renderingMode.value,
          'software',
          reason: 'injected GPU failure must select software output',
        );
      }
      stdout.writeln('VPFL_RENDERING_MODE=${output.renderingMode.value}');
      for (final entry
          in (manifest['fixtures'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['id'] as String;
        final file = File('${directory.path}/${byId[id]!['file']}');
        await playback
            .open(file.uri.toString())
            .timeout(const Duration(seconds: 12));
        await _until(
          tester,
          () =>
              RealMediaTracks(playback.tracks).video.isNotEmpty &&
              playback.hasVideoOutput,
          '$id tracks',
        );
        final tracks = RealMediaTracks(playback.tracks);
        expect(
          tracks.video.single.codec?.toLowerCase(),
          entry['codec'],
          reason: id,
        );
        expect(
          tracks.audio.single.codec?.toLowerCase(),
          entry['audio_codec'],
          reason: id,
        );
        await _until(tester, () => playback.isPlaying, '$id playback start');
        await playback.playOrPause();
        await _until(tester, () => !playback.isPlaying, '$id pause');
        await playback.seek(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 250));
        final screenshot = await playback.screenshot().timeout(
          const Duration(seconds: 8),
        );
        expect(screenshot, isNotNull, reason: '$id produced no decoded frame');
        await _checkPatches(screenshot!, id);
        if (id == 'h264_mp4' &&
            Platform.environment['VPFL_CI_REQUIRE_HARDWARE'] == '1') {
          expect(
            output.renderingMode.value,
            'gpu',
            reason: 'hardware lane requires the native GPU rendering path',
          );
          final decoder = await playback.hardwareDecoder();
          stdout.writeln('VPFL_HARDWARE_DECODER=$decoder');
          expect(
            decoder,
            isNot(anyOf(isNull, isEmpty, 'no')),
            reason: 'hardware lane requires an observed H.264 hardware decoder',
          );
        }
        expect(
          playback.duration.inMilliseconds,
          inInclusiveRange(1900, 3100),
          reason: id,
        );
        await playback.playOrPause();
        await _until(tester, () => playback.isPlaying, '$id resume');
        for (
          var attempt = 0;
          attempt < 60 && !playback.isCompleted;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(
          playback.isCompleted,
          isTrue,
          reason:
              '$id did not naturally complete; '
              'position=${playback.position}, duration=${playback.duration}, '
              'playing=${playback.isPlaying}',
        );
        await _until(tester, () => !playback.isPlaying, '$id completion stop');
        await playback.stop();
        stdout.writeln('PASS video $id');
      }
      final source = File('${directory.path}/${byId['h264_mkv']!['file']}');
      for (final entry
          in (manifest['subtitle_fixtures'] as List)
              .cast<Map<String, dynamic>>()) {
        final id = entry['id'] as String;
        await playback.open(source.uri.toString());
        final initial = RealMediaTracks(playback.tracks).subtitle.length;
        await playback.loadSubtitleFile(
          '${directory.path}/${byId[id]!['file']}',
        );
        await _until(
          tester,
          () => RealMediaTracks(playback.tracks).subtitle.length > initial,
          '$id subtitle',
        );
        await playback.stop();
        stdout.writeln('PASS external subtitle track $id');
      }
      final embedded = File(
        '${directory.path}/${byId['embed_srt_mkv']!['file']}',
      );
      await playback.open(embedded.uri.toString());
      await _until(
        tester,
        () => RealMediaTracks(playback.tracks).subtitle.isNotEmpty,
        'embedded subtitle',
      );
      expect(RealMediaTracks(playback.tracks).subtitle, hasLength(1));
      await playback.seek(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 200));
      final screenshot = await playback.screenshot();
      expect(screenshot, isNotNull, reason: 'embedded subtitle video frame');
      await _checkPatches(screenshot!, 'embed_srt_mkv');
      await playback.stop();
      stdout.writeln('PASS embedded subtitle track embed_srt_mkv');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
