import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/thumbnail_providers.dart';
import 'package:vpfl/data/services/application_shutdown.dart';
import 'package:vpfl/data/services/playback_service.dart';
import 'package:vpfl/ui/app.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/library/media_card.dart';
import 'package:vpfl/ui/player/player_controls.dart';
import 'package:vpfl/ui/player/player_screen.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

Future<String> _command(
  String executable,
  List<String> arguments, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final result = await Process.run(executable, arguments).timeout(timeout);
  if (result.exitCode != 0) {
    throw TestFailure(
      '$executable ${arguments.join(' ')} failed (${result.exitCode}): '
      '${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

Future<(int, int)> _windowOrigin() async {
  final ids = (await _command('xdotool', [
    'search',
    '--pid',
    '$pid',
    '--onlyvisible',
  ])).split('\n');
  for (final id in ids.reversed) {
    final details = await _command('xdotool', [
      'getwindowgeometry',
      '--shell',
      id,
    ]);
    final values = <String, int>{};
    for (final line in details.split('\n')) {
      final parts = line.split('=');
      if (parts.length == 2) {
        values[parts[0]] = int.tryParse(parts[1]) ?? -1;
      }
    }
    if ((values['WIDTH'] ?? 0) >= 600 && (values['HEIGHT'] ?? 0) >= 400) {
      return (values['X']!, values['Y']!);
    }
  }
  throw TestFailure('No visible VPFL X11 window for process $pid: $ids');
}

Future<void> _capture(WidgetTester tester, File output) async {
  final display = Platform.environment['DISPLAY'];
  if (display == null || display.isEmpty) {
    throw TestFailure('X11 window test requires DISPLAY and Xvfb');
  }
  output.parent.createSync(recursive: true);
  final size = (await _command('xdotool', ['getdisplaygeometry'])).split(' ');
  for (var attempt = 0; attempt < 4; attempt++) {
    await _hideControlsForCapture(tester);
    await _command('ffmpeg', [
      '-nostdin',
      '-v',
      'error',
      '-y',
      '-f',
      'x11grab',
      '-draw_mouse',
      '0',
      '-video_size',
      '${size[0]}x${size[1]}',
      '-i',
      display,
      '-frames:v',
      '1',
      output.path,
    ]);
    try {
      await _compare(
        tester,
        output,
        output,
        expectResult: 'absent',
        record: false,
      );
      return;
    } on TestFailure {
      if (attempt == 3) rethrow;
      await _quietOverlay(tester);
    }
  }
}

Future<Map<String, dynamic>> _compare(
  WidgetTester tester,
  File enabled,
  File disabled, {
  String region = 'bottom',
  String expectResult = 'visible',
  bool record = true,
}) async {
  final (windowX, windowY) = await _windowOrigin();
  final texture = tester
      .getRect(find.byType(Texture).first)
      .intersect(tester.getRect(find.byType(Video)));
  final ratio = tester.view.devicePixelRatio;
  final left = windowX + (texture.left * ratio).round() + 3;
  final top = windowY + (texture.top * ratio).round() + 3;
  final width = math.max(0, (texture.width * ratio).round() - 6);
  final height = math.max(0, (texture.height * ratio).round() - 6);
  final base = enabled.path.replaceFirst(RegExp(r'-on[.]png$'), '');
  final output = await _command('python3', [
    'scripts/ci/check_subtitle_window.py',
    enabled.path,
    disabled.path,
    '--rect',
    '$left',
    '$top',
    '$width',
    '$height',
    '--expect',
    expectResult,
    if (record) ...['--metrics', '$base-metrics.json'],
    if (record) ...['--difference', '$base-difference.png'],
    if (expectResult == 'visible') ...['--region', region],
  ]);
  return jsonDecode(output) as Map<String, dynamic>;
}

Future<void> _waitForVideo(
  WidgetTester tester,
  PlaybackService playback,
  int subtitleCount, {
  String? expectedPath,
  List<String?>? expectedSubtitleTitles,
}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    // A new request can retain the previous clip's texture and track count.
    final playlist = playback.videoController.player.state.playlist;
    final currentPath = playlist.medias.isNotEmpty
        ? playlist.medias[playlist.index].uri
        : null;
    final subtitles = RealMediaTracks(playback.tracks).subtitle;
    if (playback.hasVideoOutput &&
        subtitles.length == subtitleCount &&
        (expectedPath == null || currentPath == expectedPath) &&
        (expectedSubtitleTitles == null ||
            listEquals(
              subtitles.map((track) => track.title).toList(),
              expectedSubtitleTitles,
            )) &&
        find.byType(Texture).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Video/texture/tracks not ready: video=${playback.hasVideoOutput}, '
    'tracks=${RealMediaTracks(playback.tracks).subtitle.length}, '
    'titles=${RealMediaTracks(playback.tracks).subtitle.map((track) => track.title).toList()}, '
    'source=${playback.videoController.player.state.playlist.medias.map((media) => media.uri).toList()}, '
    'expectedSource=$expectedPath, expectedTitles=$expectedSubtitleTitles, '
    'texture=${find.byType(Texture).evaluate().length}',
  );
}

Future<void> _chooseSubtitle(WidgetTester tester, String label) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getRect(find.byType(Video)).center);
  await mouse.moveTo(
    tester.getRect(find.byType(Video)).bottomCenter - const Offset(0, 40),
  );
  await tester.pump();
  await tester.tap(find.byTooltip('Subtitles'));
  await tester.pumpAndSettle();
  final option = find.textContaining(label);
  if (option.evaluate().isEmpty) {
    final labels = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data);
    throw TestFailure(
      'CC option "$label" missing; visible text: ${labels.join(' | ')}',
    );
  }
  expect(option, findsOneWidget);
  // Text is inside the popup's hit target, so Flutter can report a harmless
  // hit-test warning for the text render object itself.
  await tester.tap(option, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 150));
  await mouse.removePointer();
}

Future<void> _openSubtitleTiming(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getRect(find.byType(Video)).center);
  await mouse.moveTo(
    tester.getRect(find.byType(Video)).bottomCenter - const Offset(0, 40),
  );
  await tester.pump();
  await tester.tap(find.byTooltip('More playback options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Subtitle timing…'));
  await tester.pumpAndSettle();
  await mouse.removePointer();
}

Future<void> _toggleFullscreen(WidgetTester tester, bool enter) async {
  final video = find.byType(Video);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getRect(video).center);
  await mouse.moveTo(tester.getRect(video).bottomCenter - const Offset(0, 40));
  await tester.pump();
  await tester.tap(
    find.byTooltip(enter ? 'Enter Fullscreen' : 'Exit Fullscreen'),
  );
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.state<VideoState>(video).isFullscreen() == enter) break;
  }
  await mouse.removePointer();
  expect(tester.state<VideoState>(video).isFullscreen(), enter);
}

Future<void> _resizeWindow(WidgetTester tester) async {
  final ids = (await _command('xdotool', [
    'search',
    '--pid',
    '$pid',
    '--onlyvisible',
  ])).split('\n');
  final before = tester.getRect(find.byType(Texture)).size;
  for (final id in ids.reversed) {
    final geometry = await _command('xdotool', [
      'getwindowgeometry',
      '--shell',
      id,
    ]);
    if (!geometry.contains('WIDTH=')) continue;
    final width =
        int.tryParse(
          RegExp(r'WIDTH=(\d+)').firstMatch(geometry)?.group(1) ?? '',
        ) ??
        0;
    if (width < 600) continue;
    await _command('xdotool', ['windowsize', id, '1000', '800']);
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.getRect(find.byType(Texture)).size != before) return;
    }
    throw TestFailure('VPFL video texture did not resize with X11 window');
  }
  throw TestFailure('VPFL X11 window was unavailable for resize');
}

Future<void> _quietOverlay(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: tester.getRect(find.byType(Video)).center);
  await gesture.moveTo(const Offset(5, 5));
  await tester.pump();
  final screen = (await _command('xdotool', ['getdisplaygeometry'])).split(' ');
  await _command('xdotool', [
    'mousemove',
    '${int.parse(screen[0]) - 5}',
    '${int.parse(screen[1]) - 5}',
  ]);
  await gesture.removePointer();
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _hideControlsForCapture(WidgetTester tester) async {
  // Paused controls stay visible by design. Suppress only their render layer
  // for pixel comparisons, keeping the real player and subtitle output.
  final controls = find.ancestor(
    of: find.byType(PlayerControls),
    matching: find.byType(AnimatedOpacity),
  );
  expect(controls, findsOneWidget);
  final fade = find.descendant(
    of: controls,
    matching: find.byType(FadeTransition),
  );
  expect(fade, findsOneWidget);
  tester.renderObject<RenderAnimatedOpacity>(fade).opacity =
      const AlwaysStoppedAnimation<double>(0);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets(
    'VPFL X11 window renders subtitle fixtures through the player UI',
    (tester) async {
      final root = Directory('$_fixturesPath/subtitle-suite');
      expect(root.existsSync(), isTrue);
      final artifacts = Directory('build/ci-logs/subtitle-window/$pid');
      final database = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final playback = container.read(playbackServiceProvider);
      Widget screen(String? file, {Future<String?> Function()? picker}) =>
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: VpflTheme.dark,
              home: PlayerScreen(
                initialMediaUri: file == null
                    ? null
                    : File('${root.path}/$file').absolute.uri.toString(),
                startupError: null,
                onOpenMedia: (_) {},
                onBack: () {},
                themeMode: ThemeMode.dark,
                onThemeModeChanged: (_) {},
                historyEnabled: false,
                resumeEnabled: false,
                onHistoryEnabledChanged: (_) {},
                onResumeEnabledChanged: (_) {},
                subtitleFilePicker: picker,
              ),
            ),
          );

      Future<void> open(String file, int count, {List<String?>? titles}) async {
        final oldGeneration = playback.sourceGeneration;
        await tester.pumpWidget(screen(file));
        for (
          var attempt = 0;
          attempt < 100 && playback.sourceGeneration == oldGeneration;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(playback.sourceGeneration, greaterThan(oldGeneration));
        await _waitForVideo(
          tester,
          playback,
          count,
          expectedPath: File('${root.path}/$file').absolute.path,
          expectedSubtitleTitles: titles,
        );
        if (playback.isPlaying) await playback.playOrPause();
        await playback.seek(const Duration(milliseconds: 1500));
      }

      Future<Map<String, dynamic>> pair(
        String name,
        String? selection, {
        String region = 'bottom',
        String expectResult = 'visible',
      }) async {
        if (selection != null) await _chooseSubtitle(tester, selection);
        final position = await playback.nativeTimePositionSeconds();
        await _quietOverlay(tester);
        final enabled = File('${artifacts.path}/$name-on.png');
        await _capture(tester, enabled);
        await _chooseSubtitle(tester, 'Off');
        await _quietOverlay(tester);
        final disabled = File('${artifacts.path}/$name-off.png');
        await _capture(tester, disabled);
        final after = await playback.nativeTimePositionSeconds();
        expect((after - position).abs(), lessThan(0.08));
        return _compare(
          tester,
          enabled,
          disabled,
          region: region,
          expectResult: expectResult,
        );
      }

      Future<void> compareAuthoredWithNative(
        String name,
        double seconds,
        String region,
      ) async {
        final (windowX, windowY) = await _windowOrigin();
        final texture = tester.getRect(find.byType(Texture).first);
        final scale = tester.view.devicePixelRatio;
        final output = await _command('python3', [
          'scripts/ci/check_subtitle_sharpness.py',
          '--fixture',
          File('${root.path}/authored_ass.mkv').absolute.path,
          '--window-on',
          '${artifacts.path}/$name-on.png',
          '--window-off',
          '${artifacts.path}/$name-off.png',
          '--rect',
          '${windowX + (texture.left * scale).round()}',
          '${windowY + (texture.top * scale).round()}',
          '${(texture.width * scale).round()}',
          '${(texture.height * scale).round()}',
          '--seconds',
          '$seconds',
          '--expected-region',
          region,
          '--minimum-shape-overlap',
          '0.95',
          '--out',
          '${artifacts.path}/$name-native-reference',
        ], timeout: const Duration(seconds: 60));
        final metrics = jsonDecode(output) as Map<String, dynamic>;
        expect(
          metrics['edge_variance_ratio'] as num,
          greaterThanOrEqualTo(0.85),
        );
        expect(
          metrics['caption_shape_overlap'] as num,
          greaterThanOrEqualTo(0.95),
        );
      }

      try {
        await playback.useNullAudioOutput();
        await tester.pumpWidget(screen('embedded_srt.mkv'));
        await _waitForVideo(
          tester,
          playback,
          1,
          expectedPath: File('${root.path}/embedded_srt.mkv').absolute.path,
          expectedSubtitleTitles: ['English SRT'],
        );
        if (playback.isPlaying) await playback.playOrPause();
        await playback.seek(const Duration(milliseconds: 1500));
        final result = await pair('embedded-srt', 'English SRT');
        expect(result['changed_pixels'] as int, greaterThan(120));
        expect(await playback.nativeSubtitleTrackCount(), 1);

        for (final (file, label, titles) in [
          ('embedded_ass.mkv', 'English ASS', <String?>['English ASS']),
          ('mov_text.mp4', 'eng', <String?>[null]),
          (
            'multilingual.mkv',
            'English',
            <String?>['English', 'Urdu', 'Japanese'],
          ),
        ]) {
          await open(file, titles.length, titles: titles);
          final name = file.replaceAll('.', '-');
          final metrics = await pair(name, label);
          expect(metrics['changed_pixels'] as int, greaterThan(120));
          expect(await playback.nativeSubtitleTrackCount(), titles.length);
        }
        final urdu = await pair('multilingual-urdu', 'Urdu');
        final japanese = await pair('multilingual-japanese', 'Japanese');
        expect(urdu['changed_pixels'] as int, greaterThan(120));
        expect(japanese['changed_pixels'] as int, greaterThan(120));
        final urduImage = File('${artifacts.path}/multilingual-urdu-on.png');
        final japaneseImage = File(
          '${artifacts.path}/multilingual-japanese-on.png',
        );
        final languages = await _compare(
          tester,
          urduImage,
          japaneseImage,
          region: 'bottom',
        );
        expect(languages['changed_pixels'] as int, greaterThan(120));
        for (final label in [
          'Urdu',
          'English',
          'Japanese',
          'Urdu',
          'Japanese',
        ]) {
          await _chooseSubtitle(tester, label);
        }
        await pair('multilingual-rapid', null);
        expect(await playback.nativeSubtitleTrackCount(), 3);

        await open('authored_ass.mkv', 1);
        final styled = await pair(
          'authored-top',
          'Authored style',
          region: 'top',
        );
        expect(
          (styled['dominant_colors'] as Map)['red'] as int,
          greaterThan(100),
        );
        expect(styled['darker_pixels'] as int, greaterThan(100));
        await compareAuthoredWithNative('authored-top', 1.5, 'top');
        await playback.seek(const Duration(milliseconds: 4500));
        final blue = await pair(
          'authored-middle',
          'Authored style',
          region: 'middle',
        );
        expect(
          (blue['dominant_colors'] as Map)['blue'] as int,
          greaterThan(100),
        );
        expect(blue['darker_pixels'] as int, greaterThan(100));
        await compareAuthoredWithNative('authored-middle', 4.5, 'middle');
        await playback.seek(const Duration(milliseconds: 6500));
        final green = await pair(
          'authored-bottom',
          'Authored style',
          region: 'bottom',
        );
        expect(
          (green['dominant_colors'] as Map)['green'] as int,
          greaterThan(100),
        );
        expect(green['darker_pixels'] as int, greaterThan(100));
        await compareAuthoredWithNative('authored-bottom', 6.5, 'bottom');
        await open('attached_ass.mkv', 1);
        await pair('attached-font', 'Attached font');

        await open('nearby/movie.mkv', 2);
        await pair('nearby-exact', 'movie.srt');
        await pair('nearby-language', 'movie.ur.srt');
        expect(await playback.nativeSubtitleTrackCount(), 2);
        await _chooseSubtitle(tester, 'Auto');
        for (
          var attempt = 0;
          attempt < 80 && playback.selectedTracks.subtitle.id != 'auto';
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(playback.selectedTracks.subtitle.id, 'auto');
        await pair('nearby-auto', null);

        await open('plain.mp4', 0);
        expect(await playback.nativeSubtitleTrackCount(), 0);
        var chosenPath = '${root.path}/external/english.srt';
        await tester.pumpWidget(
          screen('plain.mp4', picker: () async => chosenPath),
        );
        Future<void> load(String filename, int count) async {
          chosenPath = '${root.path}/external/$filename';
          await _chooseSubtitle(tester, 'Load subtitle file');
          for (
            var attempt = 0;
            attempt < 80 && await playback.nativeSubtitleTrackCount() != count;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(await playback.nativeSubtitleTrackCount(), count);
        }

        await load('english.srt', 1);
        await pair('external-srt', null);
        await load('english.vtt', 2);
        await pair('external-vtt', null);
        await load('english.ass', 3);
        await pair('external-ass', null);
        await load('english.srt', 3);
        expect(await playback.nativeSubtitleTrackCount(), 3);

        for (final invalid in ['malformed.srt', 'absent.srt']) {
          chosenPath = '${root.path}/external/$invalid';
          await _chooseSubtitle(tester, 'Load subtitle file');
          for (
            var attempt = 0;
            attempt < 80 &&
                find.textContaining('Could not load').evaluate().isEmpty;
            attempt++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.textContaining('Could not load'), findsWidgets);
          expect(await playback.nativeSubtitleTrackCount(), 3);
          expect(playback.hasVideoOutput, isTrue);
          tester
              .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
              .removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
        await load('english.srt', 3);
        await pair('external-recovered', null);

        await load('effects.ass', 4);
        await playback.seek(const Duration(milliseconds: 1150));
        final moveStart = await pair('effect-move-start', null);
        await playback.seek(const Duration(milliseconds: 2350));
        final moveEnd = await pair(
          'effect-move-end',
          'effects.ass',
          region: 'top',
        );
        final startBox = (moveStart['bbox'] as List).cast<int>();
        final endBox = (moveEnd['bbox'] as List).cast<int>();
        expect(
          ((startBox[0] + startBox[2]) - (endBox[0] + endBox[2])).abs(),
          greaterThan(140),
        );
        await playback.seek(const Duration(milliseconds: 4100));
        final colorStart = await pair('effect-color-start', 'effects.ass');
        await playback.seek(const Duration(milliseconds: 5300));
        final colorEnd = await pair('effect-color-end', 'effects.ass');
        expect(
          ((colorEnd['dominant_colors'] as Map)['red'] as int) -
              ((colorStart['dominant_colors'] as Map)['red'] as int),
          greaterThan(150),
        );

        await playback.seek(const Duration(milliseconds: 1500));
        await load('missing_font.ass', 5);
        await pair('missing-font', null);
        await load('unicode.srt', 6);
        await pair('unicode', null);
        await playback.seek(const Duration(milliseconds: 4500));
        await pair('unicode-arabic', 'unicode.srt');
        await playback.seek(const Duration(milliseconds: 6500));
        await pair('unicode-mixed', 'unicode.srt');
        await load('overlap.srt', 7);
        await playback.seek(const Duration(milliseconds: 2200));
        await pair('overlap', null);
        await playback.seek(const Duration(milliseconds: 4200));
        await _chooseSubtitle(tester, 'overlap.srt');
        await _quietOverlay(tester);
        final gapOn = File('${artifacts.path}/overlap-gap-on.png');
        await _capture(tester, gapOn);
        await _chooseSubtitle(tester, 'Off');
        await _quietOverlay(tester);
        final gapOff = File('${artifacts.path}/overlap-gap-off.png');
        await _capture(tester, gapOff);
        await _compare(tester, gapOn, gapOff, expectResult: 'absent');

        await open('embedded_srt.mkv', 1);
        await tester.pumpWidget(
          screen('embedded_srt.mkv', picker: () async => chosenPath),
        );
        await pair('embedded-with-picker', 'English SRT');
        await load('english.srt', 2);
        await pair('external-over-embedded', null);
        await pair('embedded-after-external', 'English SRT');
        await pair('external-after-embedded', 'english.srt');
        expect(await playback.nativeSubtitleTrackCount(), 2);

        await open('plain.mp4', 0);
        await _quietOverlay(tester);
        final plainCue = File('${artifacts.path}/plain-on.png');
        await _capture(tester, plainCue);
        await _compare(tester, plainCue, plainCue, expectResult: 'plain');
        await playback.seek(const Duration(milliseconds: 3200));
        await _quietOverlay(tester);
        final plainGap = File('${artifacts.path}/plain-off.png');
        await _capture(tester, plainGap);
        await _compare(tester, plainGap, plainGap, expectResult: 'plain');
        await _compare(tester, plainCue, plainGap, expectResult: 'absent');
        expect(await playback.nativeSubtitleTrackCount(), 0);

        await open('burned.mp4', 0);
        final burned = await pair('burned', null, expectResult: 'burned');
        expect(burned['burned_white_pixels'] as int, greaterThan(120));
        expect(await playback.nativeSubtitleTrackCount(), 0);

        await open('embedded_srt.mkv', 1);
        await playback.seek(const Duration(milliseconds: 1050));
        await _chooseSubtitle(tester, 'English SRT');
        await _quietOverlay(tester);
        final original = File('${artifacts.path}/timing-original-on.png');
        await _capture(tester, original);
        await _openSubtitleTiming(tester);
        expect(find.text('0 ms'), findsOneWidget);
        await tester.tap(find.byTooltip('Show subtitles 100 ms later'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('+100 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('+100 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await _quietOverlay(tester);
        final delayed = File('${artifacts.path}/timing-later-off.png');
        await _capture(tester, delayed);
        await _compare(tester, original, delayed);

        await playback.seek(const Duration(milliseconds: 1150));
        await _quietOverlay(tester);
        final repeatBefore = File('${artifacts.path}/timing-repeat-on.png');
        await _capture(tester, repeatBefore);
        await _openSubtitleTiming(tester);
        await tester.tap(find.byTooltip('Show subtitles 100 ms later'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('+200 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('+200 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await _quietOverlay(tester);
        final repeatAfter = File('${artifacts.path}/timing-repeat-off.png');
        await _capture(tester, repeatAfter);
        await _compare(tester, repeatBefore, repeatAfter);

        await _openSubtitleTiming(tester);
        expect(find.text('+200 ms'), findsOneWidget);
        await tester.tap(find.text('Reset'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('0 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('0 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await playback.seek(const Duration(milliseconds: 1050));
        await _quietOverlay(tester);
        final reset = File('${artifacts.path}/timing-reset-off.png');
        await _capture(tester, reset);
        await _compare(tester, original, reset, expectResult: 'absent');

        await playback.seek(const Duration(milliseconds: 950));
        await _quietOverlay(tester);
        final beforeEarly = File('${artifacts.path}/timing-early-off.png');
        await _capture(tester, beforeEarly);
        await _openSubtitleTiming(tester);
        await tester.tap(find.byTooltip('Show subtitles 100 ms earlier'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('−100 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('−100 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await _quietOverlay(tester);
        final early = File('${artifacts.path}/timing-early-on.png');
        await _capture(tester, early);
        await _compare(tester, early, beforeEarly);

        await playback.resetSubtitleDelay();
        await playback.seek(const Duration(milliseconds: 1050));
        await _openSubtitleTiming(tester);
        expect(find.text('0 ms'), findsOneWidget);
        await Future.wait(
          List.generate(50, (_) => playback.adjustSubtitleDelay(100)),
        );
        for (
          var attempt = 0;
          attempt < 30 && find.text('+5000 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('+5000 ms'), findsOneWidget);
        await tester.tap(
          find.byTooltip('Show subtitles 100 ms later'),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(find.text('+5000 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await _quietOverlay(tester);
        final maxDelay = File('${artifacts.path}/timing-max-off.png');
        await _capture(tester, maxDelay);
        await _compare(tester, original, maxDelay);
        await _openSubtitleTiming(tester);
        expect(find.text('+5000 ms'), findsOneWidget);
        await tester.tap(find.byTooltip('Show subtitles 100 ms earlier'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('+4900 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('+4900 ms'), findsOneWidget);
        await tester.tap(find.text('Reset'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('0 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('0 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await _quietOverlay(tester);
        final maxReset = File('${artifacts.path}/timing-max-reset.png');
        await _capture(tester, maxReset);
        await _compare(tester, original, maxReset, expectResult: 'absent');

        await playback.seek(const Duration(milliseconds: 800));
        await playback.playOrPause();
        expect(playback.isPlaying, isTrue);
        await _openSubtitleTiming(tester);
        await tester.tap(find.byTooltip('Show subtitles 100 ms later'));
        for (
          var attempt = 0;
          attempt < 30 && find.text('+100 ms').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('+100 ms'), findsOneWidget);
        expect(playback.isPlaying, isTrue);
        await tester.tap(find.text('Close'));
        await playback.playOrPause();
        expect(playback.isPlaying, isFalse);
        await playback.seek(const Duration(milliseconds: 1050));
        await _quietOverlay(tester);
        final playingDelay = File('${artifacts.path}/timing-playing-off.png');
        await _capture(tester, playingDelay);
        await _compare(tester, original, playingDelay);
        await _chooseSubtitle(tester, 'Off');
        await _chooseSubtitle(tester, 'English SRT');
        expect(playback.subtitleDelayMilliseconds, 100);
        await _quietOverlay(tester);
        final switchedDelay = File('${artifacts.path}/timing-track-off.png');
        await _capture(tester, switchedDelay);
        await _compare(tester, original, switchedDelay);

        await open('plain.mp4', 0);
        expect(playback.subtitleDelayMilliseconds, 0);
        await open('embedded_srt.mkv', 1);
        expect(playback.subtitleDelayMilliseconds, 0);

        await pair('windowed-before-fullscreen', 'English SRT');
        await _toggleFullscreen(tester, true);
        await pair('fullscreen-srt', 'English SRT');
        await playback.seek(const Duration(milliseconds: 4500));
        await pair('fullscreen-seek', 'English SRT');
        await _openSubtitleTiming(tester);
        expect(find.text('0 ms'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await pair('fullscreen-after-settings', 'English SRT');
        await _toggleFullscreen(tester, false);
        await pair('windowed-after-fullscreen', 'English SRT');
        await _resizeWindow(tester);
        await pair('resized-window', 'English SRT');
      } finally {
        // Remove Video while its MaterialApp and inherited fullscreen context
        // are still mounted, then detach the test root.
        await tester.pumpAndSettle();
        await tester.pumpWidget(screen(null));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await container.read(playbackHistoryRecorderProvider).dispose();
        await playback.dispose();
        await database.close();
        container.dispose();
      }
    },
  );

  testWidgets('Home and reopen restore visible subtitles in VPFL window', (
    tester,
  ) async {
    final root = Directory('$_fixturesPath/subtitle-suite');
    expect(root.existsSync(), isTrue);
    final source = File('${root.path}/embedded_srt.mkv').absolute.uri
        .toString();
    final container = ProviderContainer();
    final playback = container.read(playbackServiceProvider);
    final artifacts = Directory('build/ci-logs/subtitle-window/$pid');

    Future<void> visiblePair(String name) async {
      await _chooseSubtitle(tester, 'English SRT');
      await _quietOverlay(tester);
      final shown = File('${artifacts.path}/$name-on.png');
      await _capture(tester, shown);
      await _chooseSubtitle(tester, 'Off');
      await _quietOverlay(tester);
      final hidden = File('${artifacts.path}/$name-off.png');
      await _capture(tester, hidden);
      final metrics = await _compare(tester, shown, hidden);
      expect(metrics['changed_pixels'] as int, greaterThan(120));
    }

    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(initialMediaUri: source, startupError: null),
        ),
      );
      await _waitForVideo(tester, playback, 1);
      if (playback.isPlaying) await playback.playOrPause();
      await playback.seek(const Duration(milliseconds: 1500));
      await visiblePair('home-before');

      await tester.tap(find.byTooltip('Back'));
      for (
        var attempt = 0;
        attempt < 100 && find.byType(MediaCard).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MediaCard), findsWidgets);
      for (
        var attempt = 0;
        attempt < 100 && await playback.nativeSubtitleTrackCount() != 0;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(await playback.nativeSubtitleTrackCount(), 0);

      await tester.tap(find.byType(MediaCard).first);
      await _waitForVideo(tester, playback, 1);
      if (playback.isPlaying) await playback.playOrPause();
      await playback.seek(const Duration(milliseconds: 1500));
      await visiblePair('home-after');
      expect(await playback.nativeSubtitleTrackCount(), 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      final shutdown = ApplicationShutdown(
        playback: playback,
        history: container.read(playbackHistoryRecorderProvider),
        thumbnails: container.read(thumbnailServiceProvider),
        database: container.read(appDatabaseProvider),
      );
      await shutdown.shutdown();
      container.dispose();
    }
  });

  testWidgets(
    'Attached ASS stays sharp at native, resized, and fullscreen sizes',
    (tester) async {
      final fixture = File('$_fixturesPath/subtitle-suite/attached_ass.mkv')
          .absolute;
      final source = fixture.uri.toString();
      final artifacts = Directory('build/ci-logs/subtitle-sharpness/$pid')
        ..createSync(recursive: true);
      final database = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final playback = container.read(playbackServiceProvider);
      final exactNativeSize = ValueNotifier(false);
      final screen = UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VpflTheme.dark,
          home: ValueListenableBuilder<bool>(
            valueListenable: exactNativeSize,
            child: PlayerScreen(
              key: GlobalKey(),
              initialMediaUri: source,
              startupError: null,
              onOpenMedia: (_) {},
              onBack: () {},
              themeMode: ThemeMode.dark,
              onThemeModeChanged: (_) {},
              historyEnabled: false,
              resumeEnabled: false,
              onHistoryEnabledChanged: (_) {},
              onResumeEnabledChanged: (_) {},
            ),
            builder: (context, exact, child) => exact
                ? Center(child: SizedBox(width: 640, height: 400, child: child))
                : SizedBox.expand(child: child),
          ),
        ),
      );

      Future<void> waitForOutputSize() async {
        final platform = await playback.videoController.platform.future;
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          final texture = tester.getRect(find.byType(Texture).first);
          final ratio = tester.view.devicePixelRatio;
          final native = platform.rect.value;
          if (native != null &&
              (native.width - texture.width * ratio).abs() <= 1 &&
              (native.height - texture.height * ratio).abs() <= 1) {
            return;
          }
        }
        throw TestFailure(
          'Native video output did not match the displayed physical size: '
          '${platform.rect.value} versus '
          '${tester.getRect(find.byType(Texture).first)} at '
          'DPR ${tester.view.devicePixelRatio}',
        );
      }

      Future<void> resizeWindow(int width, int height) async {
        final before = tester.getRect(find.byType(Texture).first).size;
        final ids = (await _command('xdotool', [
          'search',
          '--pid',
          '$pid',
          '--onlyvisible',
        ])).split('\n');
        for (final id in ids.reversed) {
          final geometry = await _command('xdotool', [
            'getwindowgeometry',
            '--shell',
            id,
          ]);
          if (!geometry.contains('WIDTH=')) continue;
          await _command('xdotool', ['windowsize', id, '$width', '$height']);
          for (var attempt = 0; attempt < 80; attempt++) {
            await tester.pump(const Duration(milliseconds: 100));
            if (tester.getRect(find.byType(Texture).first).size != before) {
              break;
            }
          }
          if (tester.getRect(find.byType(Texture).first).size == before) {
            throw TestFailure(
              'VPFL texture did not follow the X11 window resize',
            );
          }
          await waitForOutputSize();
          return;
        }
        throw TestFailure('No VPFL X11 window found for resizing');
      }

      Future<void> capture(String name) async {
        await waitForOutputSize();
        await _chooseSubtitle(tester, 'Attached font');
        await _quietOverlay(tester);
        final position = await playback.nativeTimePositionSeconds();
        final shown = File('${artifacts.path}/$name-on.png');
        await _capture(tester, shown);
        if (name == 'windowed') {
          final native = await playback.screenshot();
          expect(native, isNotNull);
          await File('${artifacts.path}/media-kit-native.png')
              .writeAsBytes(native!);
        }
        await _chooseSubtitle(tester, 'Off');
        await _quietOverlay(tester);
        final hidden = File('${artifacts.path}/$name-off.png');
        await _capture(tester, hidden);
        expect(
          ((await playback.nativeTimePositionSeconds()) - position).abs(),
          lessThan(0.08),
        );
        final (windowX, windowY) = await _windowOrigin();
        final texture = tester.getRect(find.byType(Texture).first);
        final ratio = tester.view.devicePixelRatio;
        final left = windowX + (texture.left * ratio).round();
        final top = windowY + (texture.top * ratio).round();
        final width = (texture.width * ratio).round();
        final height = (texture.height * ratio).round();
        final result = await _command('python3', [
          'scripts/ci/check_subtitle_sharpness.py',
          '--fixture',
          fixture.path,
          '--window-on',
          shown.path,
          '--window-off',
          hidden.path,
          if (name == 'windowed') ...[
            '--media-kit-native',
            '${artifacts.path}/media-kit-native.png',
          ],
          '--rect',
          '$left',
          '$top',
          '$width',
          '$height',
          '--out',
          '${artifacts.path}/$name-reference',
        ], timeout: const Duration(seconds: 60));
        final metrics = jsonDecode(result) as Map<String, dynamic>;
        expect(
          metrics['edge_variance_ratio'] as num,
          greaterThanOrEqualTo(0.85),
        );
        if (name == 'windowed') {
          expect(metrics['media_kit_native_matches_mpv'], isTrue);
        }
        debugPrint('SHARPNESS $name $result');
      }

      try {
        await playback.useNullAudioOutput();
        await tester.pumpWidget(screen);
        await _waitForVideo(tester, playback, 1);
        if (playback.isPlaying) await playback.playOrPause();
        await playback.seek(const Duration(milliseconds: 1500));
        expect(tester.view.devicePixelRatio, 1.0);
        await capture('windowed');
        await resizeWindow(640, 480);
        await capture('minimum-window');
        exactNativeSize.value = true;
        await tester.pump();
        await waitForOutputSize();
        expect(
          tester.getRect(find.byType(Texture).first).size,
          const Size(640, 360),
        );
        await capture('native-size');
        exactNativeSize.value = false;
        await tester.pump();
        await waitForOutputSize();
        await resizeWindow(1124, 672);
        expect(
          tester.getRect(find.byType(Texture).first).size,
          const Size(1124, 632),
        );
        await capture('comparison-size');
        await resizeWindow(999, 800);
        await capture('resized');
        await _toggleFullscreen(tester, true);
        await capture('fullscreen');
        await _toggleFullscreen(tester, false);
        await capture('after-fullscreen');
        // Native output sizing must preserve the existing video fit choices.
        // In particular, Stretch must fill the viewport without mpv inserting
        // a second letterbox inside the Flutter texture.
        for (final fit in [BoxFit.cover, BoxFit.fill, BoxFit.contain]) {
          tester
              .widget<PlayerControls>(find.byType(PlayerControls))
              .onSetFit(fit);
          await tester.pump(const Duration(milliseconds: 100));
          await _quietOverlay(tester);
          final frame = File('${artifacts.path}/fit-${fit.name}.png');
          await _capture(tester, frame);
          final (windowX, windowY) = await _windowOrigin();
          final visible = tester
              .getRect(find.byType(Texture).first)
              .intersect(tester.getRect(find.byType(Video)));
          final ratio = tester.view.devicePixelRatio;
          await _command('python3', [
            'scripts/ci/check_subtitle_window.py',
            frame.path,
            frame.path,
            '--rect',
            '${windowX + (visible.left * ratio).round() + 3}',
            '${windowY + (visible.top * ratio).round() + 3}',
            '${(visible.width * ratio).round() - 6}',
            '${(visible.height * ratio).round() - 6}',
            '--expect',
            'plain',
            '--metrics',
            '${artifacts.path}/fit-${fit.name}-metrics.json',
          ]);
        }
      } finally {
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await container.read(playbackHistoryRecorderProvider).dispose();
        await playback.dispose();
        await database.close();
        exactNativeSize.dispose();
        container.dispose();
      }
    },
  );
  testWidgets('ASS recovers after repeated Linux window resizes', (
    tester,
  ) async {
    final root = Directory('$_fixturesPath/subtitle-suite').absolute;
    final fixture = File('${root.path}/authored_ass.mkv');
    final artifacts = Directory('build/ci-logs/subtitle-settle/$pid')
      ..createSync(recursive: true);
    final manifest = jsonDecode(
      File('test/fixtures/subtitles/subtitle-matrix.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases =
        <({String id, String? external, double seconds, String region})>[
          (id: 'original-red', external: null, seconds: 1.5, region: 'top'),
          (id: 'original-blue', external: null, seconds: 4.5, region: 'middle'),
          (
            id: 'original-green',
            external: null,
            seconds: 6.5,
            region: 'bottom',
          ),
          for (final item in manifest['resize_experiments'] as List)
            (
              id: item['id'] as String,
              external: item['file'] as String,
              seconds: (item['seconds'] as num).toDouble(),
              region: item['region'] as String,
            ),
        ];
    const selectedResizeCases = String.fromEnvironment('VPFL_RESIZE_CASES');
    if (selectedResizeCases.isNotEmpty) {
      final selected = selectedResizeCases.split(',').toSet();
      cases.removeWhere((item) => !selected.contains(item.id));
      expect(cases, isNotEmpty);
    }
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    final clock = Stopwatch()..start();
    final events = <Map<String, dynamic>>[];
    final comparisons = <Map<String, dynamic>>[];
    void Function()? removeNativeListener;
    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: VpflTheme.dark,
            home: PlayerScreen(
              initialMediaUri: fixture.uri.toString(),
              startupError: null,
              onOpenMedia: (_) {},
              onBack: () {},
              themeMode: ThemeMode.dark,
              onThemeModeChanged: (_) {},
              historyEnabled: false,
              resumeEnabled: false,
              onHistoryEnabledChanged: (_) {},
              onResumeEnabledChanged: (_) {},
            ),
          ),
        ),
      );
      await _waitForVideo(tester, playback, 1);
      if (playback.isPlaying) await playback.playOrPause();
      await playback.seek(const Duration(milliseconds: 1500));
      await _quietOverlay(tester);
      final embedded = playback.selectedTracks.subtitle;
      final platform = await playback.videoController.platform.future;
      expect(
        platform.renderingMode.value,
        Platform.environment['VPFL_TEST_FAIL_GPU_INIT'] == '1'
            ? 'software'
            : 'gpu',
        reason: 'The recovery lane must exercise its requested renderer',
      );
      void record(String event, [Map<String, dynamic> extra = const {}]) {
        final texture = tester.getRect(find.byType(Texture).first);
        final native = platform.rect.value;
        events.add({
          'event': event,
          'microseconds': clock.elapsedMicroseconds,
          'viewport': [
            tester.view.physicalSize.width,
            tester.view.physicalSize.height,
          ],
          'texture': [texture.left, texture.top, texture.width, texture.height],
          'native': [native?.width, native?.height],
          'dpr': tester.view.devicePixelRatio,
          'filter': tester
              .widget<Texture>(find.byType(Texture).first)
              .filterQuality
              .name,
          'rendering_mode': platform.renderingMode.value,
          ...extra,
        });
      }

      void onNativeSize() {
        final native = platform.rect.value;
        events.add({
          'event': 'native_dimension_notification',
          'microseconds': clock.elapsedMicroseconds,
          'native': [native?.width, native?.height],
          'rendering_mode': platform.renderingMode.value,
        });
      }

      platform.rect.addListener(onNativeSize);
      removeNativeListener = () => platform.rect.removeListener(onNativeSize);
      final ids = (await _command('xdotool', [
        'search',
        '--pid',
        '$pid',
        '--onlyvisible',
      ])).split('\n');
      String? window;
      for (final id in ids.reversed) {
        final geometry = await _command('xdotool', [
          'getwindowgeometry',
          '--shell',
          id,
        ]);
        if (RegExp(r'WIDTH=([6-9]\d\d|\d{4,})').hasMatch(geometry)) {
          window = id;
          break;
        }
      }
      if (window == null) {
        throw TestFailure('VPFL window not found for resize recovery');
      }
      await _command('xdotool', ['windowmove', window, '0', '0']);
      Future<void> resize(int width, int height) async {
        record('resize_request', {
          'requested': [width, height],
        });
        await _command('xdotool', ['windowsize', window!, '$width', '$height']);
        await tester.pump(const Duration(milliseconds: 16));
        record('after_resize_pump');
      }

      Future<void> drag(List<(int, int)> sizes) async {
        final (x, y) = await _windowOrigin();
        final size = tester.view.physicalSize;
        final arguments = <String>[
          'mousemove',
          '--window',
          window!,
          '${size.width.round() - 4}',
          '${size.height.round() - 4}',
          'mousedown',
          '1',
          'sleep',
          '0.20',
          for (final (w, h) in sizes) ...[
            'mousemove',
            '--sync',
            '${x + w - 4}',
            '${y + h - 4}',
            'sleep',
            '0.18',
          ],
          'mouseup',
          '1',
        ];
        record('gtk_pointer_drag_start', {
          'targets': [
            for (final (w, h) in sizes) [w, h],
          ],
        });
        final process = await Process.start('xdotool', arguments);
        final errors = process.stderr.transform(utf8.decoder).join();
        final output = process.stdout.drain<void>();
        int? result;
        final finished = process.exitCode.then((code) => result = code);
        try {
          final deadline = clock.elapsedMilliseconds + 8000;
          while (result == null && clock.elapsedMilliseconds < deadline) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (result == null) {
            process.kill();
            throw TestFailure('GTK pointer resize did not finish within 8s');
          }
          await finished;
          await output;
          expect(result, 0, reason: await errors);
        } finally {
          await _command('xdotool', ['mouseup', '1']);
        }
        record('gtk_pointer_drag_released');
      }

      Future<void> settle(int width, int height) async {
        var stable = 0;
        final start = clock.elapsedMilliseconds;
        while (clock.elapsedMilliseconds - start < 1500) {
          await tester.pump(const Duration(milliseconds: 16));
          final size = tester.view.physicalSize;
          final texture = tester.getRect(find.byType(Texture).first);
          final ratio = tester.view.devicePixelRatio;
          final native = platform.rect.value;
          final matches =
              size.width == width &&
              size.height == height &&
              native != null &&
              (native.width - texture.width * ratio).abs() <= 1 &&
              (native.height - texture.height * ratio).abs() <= 1 &&
              (texture.left * ratio - (texture.left * ratio).round()).abs() <
                  0.001 &&
              (texture.top * ratio - (texture.top * ratio).round()).abs() <
                  0.001;
          stable = matches ? stable + 1 : 0;
          record('settle_sample');
          if (stable == 3) {
            record('dimensions_settled', {
              'elapsed_ms': clock.elapsedMilliseconds - start,
            });
            return;
          }
        }
        throw TestFailure(
          'Native output did not converge to $width x $height within 1500ms',
        );
      }

      Future<File> grab(String name) async {
        final path = File('${artifacts.path}/$name.png');
        for (var attempt = 0; attempt < 4; attempt++) {
          await _hideControlsForCapture(tester);
          await _command('ffmpeg', [
            '-nostdin',
            '-v',
            'error',
            '-y',
            '-f',
            'x11grab',
            '-draw_mouse',
            '0',
            '-window_id',
            window!,
            '-i',
            Platform.environment['DISPLAY']!,
            '-frames:v',
            '1',
            path.path,
          ]);
          final texture = tester.getRect(find.byType(Texture).first);
          final ratio = tester.view.devicePixelRatio;
          try {
            await _command('python3', [
              'scripts/ci/check_subtitle_window.py',
              path.path,
              path.path,
              '--rect',
              '${(texture.left * ratio).round()}',
              '${(texture.top * ratio).round()}',
              '${(texture.width * ratio).round()}',
              '${(texture.height * ratio).round()}',
              '--expect',
              'absent',
            ]);
            record('window_capture', {'file': path.path});
            return path;
          } on TestFailure {
            if (attempt == 3) rethrow;
          }
        }
        throw TestFailure('Could not capture video without playback controls');
      }

      for (var index = 0; index < cases.length; index++) {
        final item = cases[index];
        if (item.external == null) {
          await playback.setTrack(embedded);
        } else {
          await playback.loadSubtitleFile('${root.path}/${item.external}');
        }
        final selected = playback.selectedTracks.subtitle;
        await playback.seek(
          Duration(milliseconds: (item.seconds * 1000).round()),
        );
        const width = int.fromEnvironment(
          'VPFL_RESIZE_WIDTH',
          defaultValue: 1000,
        );
        File? firstLate;
        for (var cycle = 0; cycle < 2; cycle++) {
          await playback.setTrack(selected);
          final steps = cycle == 0
              ? [(760, 480), (1201, 740), (850, 610), (1207, 741), (width, 800)]
              : [(1200, 800), (900, 600), (1100, 740), (width, 800)];
          if (cycle == 0) {
            for (final (w, h) in steps) {
              await resize(w, h);
            }
          } else {
            await drag(steps);
          }
          // A window manager may coalesce the final pointer motion. Test the
          // actual released geometry rather than treating pointer coordinates
          // as an acknowledgement that the window reached that exact size.
          await tester.pump(const Duration(milliseconds: 100));
          final finalWidth = tester.view.physicalSize.width.round();
          final finalHeight = tester.view.physicalSize.height.round();
          if (cycle == 0) {
            expect(finalWidth, width);
            expect(finalHeight, 800);
          }
          await settle(finalWidth, finalHeight);
          final name = '${item.id}-$cycle';
          final early = await grab('$name-early');
          await tester.pump(const Duration(milliseconds: 500));
          final late = await grab('$name-late');
          final native = await playback.screenshot();
          expect(native, isNotNull);
          final nativeFile = File('${artifacts.path}/$name-media-kit.png');
          await nativeFile.writeAsBytes(native!);
          await playback.setTrack(SubtitleTrack.no());
          await tester.pump(const Duration(milliseconds: 100));
          final off = await grab('$name-off');
          final texture = tester.getRect(find.byType(Texture).first);
          final ratio = tester.view.devicePixelRatio;
          final crop = [
            (texture.left * ratio).round(),
            (texture.top * ratio).round(),
            (texture.width * ratio).round(),
            (texture.height * ratio).round(),
          ];
          for (final (phase, shown) in [('early', early), ('late', late)]) {
            final output = await _command('python3', [
              'scripts/ci/check_subtitle_sharpness.py',
              '--fixture',
              fixture.path,
              '--reference-mode',
              'window',
              '--reference-vo',
              const String.fromEnvironment(
                'VPFL_REFERENCE_VO',
                defaultValue: 'gpu',
              ),
              if (item.external != null) ...[
                '--subtitle-file',
                '${root.path}/${item.external}',
              ],
              '--window-on',
              shown.path,
              '--window-off',
              off.path,
              '--media-kit-native',
              nativeFile.path,
              '--rect',
              ...crop.map((value) => '$value'),
              '--seconds',
              '${item.seconds}',
              '--expected-region',
              item.region,
              '--registration-radius',
              '1',
              '--minimum-shape-overlap',
              '0.99',
              '--out',
              '${artifacts.path}/$name-$phase-reference',
            ], timeout: const Duration(seconds: 60));
            comparisons.add({
              'case': item.id,
              'cycle': cycle,
              'phase': phase,
              ...jsonDecode(output) as Map<String, dynamic>,
            });
          }
          if (cycle == 0 &&
              const bool.fromEnvironment('VPFL_RESIZE_PIXEL_PHASE')) {
            final normalControls = tester
                .widget<Video>(find.byType(Video))
                .controls;
            for (final (label, alignment, filter) in [
              ('integer-origin', Alignment.topCenter, FilterQuality.none),
              ('center-return', Alignment.center, FilterQuality.none),
              ('center-linear', Alignment.center, FilterQuality.low),
              ('integer-linear', Alignment.topCenter, FilterQuality.low),
            ]) {
              await playback.setTrack(selected);
              await tester.pump(const Duration(milliseconds: 100));
              // Freeze the application sizing callback for this controlled
              // placement experiment, without changing the native frame size.
              tester
                  .state<VideoState>(find.byType(Video))
                  .update(
                    alignment: alignment,
                    filterQuality: filter,
                    controls: (_) => const SizedBox.shrink(),
                  );
              await tester.pump(const Duration(milliseconds: 100));
              final shown = await grab('$name-$label-on');
              await playback.setTrack(SubtitleTrack.no());
              await tester.pump(const Duration(milliseconds: 100));
              tester
                  .state<VideoState>(find.byType(Video))
                  .update(
                    alignment: alignment,
                    filterQuality: filter,
                    controls: (_) => const SizedBox.shrink(),
                  );
              await tester.pump(const Duration(milliseconds: 100));
              final hidden = await grab('$name-$label-off');
              final rect = tester.getRect(find.byType(Texture).first);
              final phaseCrop = [
                (rect.left * ratio).round(),
                (rect.top * ratio).round(),
                (rect.width * ratio).round(),
                (rect.height * ratio).round(),
              ];
              final output = await _command('python3', [
                'scripts/ci/check_subtitle_sharpness.py',
                '--fixture',
                fixture.path,
                '--reference-mode',
                'window',
                '--reference-vo',
                const String.fromEnvironment(
                  'VPFL_REFERENCE_VO',
                  defaultValue: 'gpu',
                ),
                if (item.external != null) ...[
                  '--subtitle-file',
                  '${root.path}/${item.external}',
                ],
                '--window-on',
                shown.path,
                '--window-off',
                hidden.path,
                '--rect',
                ...phaseCrop.map((value) => '$value'),
                '--seconds',
                '${item.seconds}',
                '--expected-region',
                item.region,
                '--registration-radius',
                '1',
                '--minimum-shape-overlap',
                '0',
                '--minimum-ratio',
                '0',
                '--out',
                '${artifacts.path}/$name-$label-reference',
              ], timeout: const Duration(seconds: 60));
              comparisons.add({
                'case': item.id,
                'cycle': cycle,
                'phase': label,
                ...jsonDecode(output) as Map<String, dynamic>,
              });
              debugPrint('PIXEL_PHASE ${item.id} $label $output');
            }
            tester
                .state<VideoState>(find.byType(Video))
                .update(
                  controls: normalControls,
                  filterQuality: FilterQuality.none,
                  alignment: Alignment.center,
                );
            await tester.pump(const Duration(milliseconds: 100));
            // Remounting controls for this optional experiment restarts their
            // visibility timer. Move the pointer away before the next capture.
            await _quietOverlay(tester);
          }
          if (firstLate != null && finalWidth == width && finalHeight == 800) {
            await _command('python3', [
              'scripts/ci/check_subtitle_window.py',
              firstLate.path,
              late.path,
              '--rect',
              ...crop.map((value) => '$value'),
              '--expect',
              'absent',
            ]);
          }
          firstLate = late;
          if (cycle == 1) {
            await playback.setTrack(selected);
            await resize(finalWidth - 1, finalHeight);
            await resize(finalWidth, finalHeight);
            await settle(finalWidth, finalHeight);
            final refreshed = await grab('$name-refreshed');
            await _command('python3', [
              'scripts/ci/check_subtitle_window.py',
              late.path,
              refreshed.path,
              '--rect',
              ...crop.map((value) => '$value'),
              '--expect',
              'absent',
            ]);
          }
          debugPrint(
            'SETTLED ${item.id} cycle=$cycle ${jsonEncode(comparisons.last)}',
          );
        }
      }
    } finally {
      removeNativeListener?.call();
      await File('${artifacts.path}/events.json')
          .writeAsString(jsonEncode(events));
      await File('${artifacts.path}/comparisons.json')
          .writeAsString(jsonEncode(comparisons));
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  });
}
