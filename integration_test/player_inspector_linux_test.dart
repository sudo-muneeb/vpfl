import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/ui/app.dart';
import 'package:vpfl/ui/player/player_inspector.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');
  const expectedAudioTracks = int.fromEnvironment(
    'VPFL_TEST_AUDIO_TRACKS',
    defaultValue: -1,
  );
  const expectedSubtitleTracks = int.fromEnvironment(
    'VPFL_TEST_SUBTITLE_TRACKS',
    defaultValue: -1,
  );
  const externalSubtitle = String.fromEnvironment(
    'VPFL_TEST_EXTERNAL_SUBTITLE',
  );

  testWidgets('media and diagnostics stay in a non-modal right inspector', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    final uri = Uri.file(File(source).absolute.path).toString();
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(initialMediaUri: uri, startupError: null),
        ),
      );
      for (var i = 0; i < 80 && !playback.hasVideoOutput; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(playback.hasVideoOutput, isTrue);
      for (
        var i = 0;
        i < 40 && RealMediaTracks(playback.tracks).video.isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final realTracks = RealMediaTracks(playback.tracks);
      expect(realTracks.video, isNotEmpty);
      if (expectedAudioTracks >= 0) {
        expect(realTracks.audio, hasLength(expectedAudioTracks));
      }
      if (expectedSubtitleTracks >= 0) {
        expect(realTracks.subtitle, hasLength(expectedSubtitleTracks));
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getRect(find.byType(Video)).center,
      );
      await mouse.moveTo(
        tester.getRect(find.byType(Video)).bottomCenter - const Offset(0, 40),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info').last);
      await tester.pump();
      expect(find.byType(PlayerInspector), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(Video), findsOneWidget);
      expect(find.text(File(source).uri.pathSegments.last), findsWidgets);
      expect(
        find.textContaining(mediaCodec(realTracks.video.first.codec)!),
        findsWidgets,
      );
      final detailsList = find
          .descendant(
            of: find.byType(PlayerInspector),
            matching: find.byType(ListView),
          )
          .first;
      final detailsScroll = find
          .descendant(of: detailsList, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(detailsScroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(find.text('Subtitles'), findsWidgets);

      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info').last);
      await tester.pump();
      expect(find.byType(PlayerInspector), findsNothing);
      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info').last);
      await tester.pump();

      await tester.tap(find.text('Diagnostics').first);
      await tester.pump();
      expect(find.text('Rendering'), findsOneWidget);
      expect(find.text('Playback rate'), findsOneWidget);

      await tester.tap(find.byTooltip('Close info'));
      await tester.pump();
      expect(find.byType(PlayerInspector), findsNothing);
      expect(find.byType(Video), findsOneWidget);

      await tester.state<VideoState>(find.byType(Video)).enterFullscreen();
      await tester.pump(const Duration(milliseconds: 150));
      await mouse.moveTo(
        tester.getRect(find.byType(Video)).bottomCenter - const Offset(0, 40),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('More playback options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info').last);
      await tester.pump();
      expect(find.byType(PlayerInspector), findsOneWidget);
      await tester.tap(find.byTooltip('Close info'));
      await tester.pump();
      expect(find.byType(PlayerInspector), findsNothing);
      await tester.state<VideoState>(find.byType(Video)).exitFullscreen();

      if (externalSubtitle.isNotEmpty) {
        await playback.loadSubtitleFile(externalSubtitle);
        for (
          var i = 0;
          i < 40 &&
              RealMediaTracks(playback.tracks).subtitle.length <=
                  realTracks.subtitle.length;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          RealMediaTracks(playback.tracks).subtitle.length,
          greaterThan(realTracks.subtitle.length),
        );
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  }, skip: source.isEmpty);
}
