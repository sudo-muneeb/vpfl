import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import 'package:vpfl/ui/player/player_screen.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

Future<String> _command(String executable, List<String> arguments) async {
  final result = await Process.run(
    executable,
    arguments,
  ).timeout(const Duration(seconds: 15));
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
  final texture = tester.getRect(find.byType(Texture).first);
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
  int subtitleCount,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (playback.hasVideoOutput &&
        RealMediaTracks(playback.tracks).subtitle.length == subtitleCount &&
        find.byType(Texture).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure(
    'Video/texture/tracks not ready: video=${playback.hasVideoOutput}, '
    'tracks=${RealMediaTracks(playback.tracks).subtitle.length}, '
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

      Future<void> open(String file, int count) async {
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
        await _waitForVideo(tester, playback, count);
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

      try {
        await playback.useNullAudioOutput();
        await tester.pumpWidget(screen('embedded_srt.mkv'));
        await _waitForVideo(tester, playback, 1);
        if (playback.isPlaying) await playback.playOrPause();
        await playback.seek(const Duration(milliseconds: 1500));
        final result = await pair('embedded-srt', 'English SRT');
        expect(result['changed_pixels'] as int, greaterThan(120));
        expect(await playback.nativeSubtitleTrackCount(), 1);

        for (final (file, label, count) in [
          ('embedded_ass.mkv', 'English ASS', 1),
          ('mov_text.mp4', 'eng', 1),
          ('multilingual.mkv', 'English', 3),
        ]) {
          await open(file, count);
          final name = file.replaceAll('.', '-');
          final metrics = await pair(name, label);
          expect(metrics['changed_pixels'] as int, greaterThan(120));
          expect(await playback.nativeSubtitleTrackCount(), count);
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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

        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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
        await _chooseSubtitle(tester, 'Subtitle timing');
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

      await tester.tap(find.byTooltip('Home'));
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
}
