import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/player/player_screen.dart';

const _fixturesPath = String.fromEnvironment('VPFL_SUBTITLE_FIXTURES');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  testWidgets('picker reports a rejected subtitle and keeps video available', (
    tester,
  ) async {
    final root = Directory('$_fixturesPath/subtitle-suite');
    expect(root.existsSync(), isTrue);
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    var chosenPath = '${root.path}/external/malformed.srt';
    Completer<String?>? pendingChoice;
    try {
      await playback.useNullAudioOutput();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: VpflTheme.dark,
            home: PlayerScreen(
              initialMediaUri: File('${root.path}/plain.mp4').absolute.uri
                  .toString(),
              startupError: null,
              onOpenMedia: (_) {},
              onBack: () {},
              themeMode: ThemeMode.dark,
              onThemeModeChanged: (_) {},
              historyEnabled: false,
              resumeEnabled: false,
              onHistoryEnabledChanged: (_) {},
              onResumeEnabledChanged: (_) {},
              subtitleFilePicker: () =>
                  pendingChoice?.future ?? Future.value(chosenPath),
            ),
          ),
        ),
      );
      for (var i = 0; i < 80 && !playback.hasVideoOutput; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(playback.hasVideoOutput, isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(
        location: tester.getRect(find.byType(Video)).center,
      );

      Future<void> chooseFile() async {
        await mouse.moveTo(
          tester.getRect(find.byType(Video)).bottomCenter - const Offset(0, 40),
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Subtitles'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load subtitle file…'));
        await tester.pump();
      }

      await chooseFile();
      const message =
          'Could not load this subtitle file. It may be invalid or unsupported.';
      for (var i = 0; i < 80 && find.text(message).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(message), findsOneWidget);
      expect(await playback.nativeSubtitleTrackCount(), 0);
      expect(playback.selectedTracks.subtitle.id, 'auto');
      expect(playback.hasVideoOutput, isTrue);

      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      chosenPath = '${root.path}/external/english.srt';
      await chooseFile();
      for (
        var i = 0;
        i < 80 &&
            (playback.selectedTracks.subtitle.id == 'auto' ||
                playback.selectedTracks.subtitle.uri);
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(await playback.nativeSubtitleTrackCount(), 1);
      expect(
        playback.selectedTracks.subtitle.id,
        await playback.effectiveSubtitleId(),
      );

      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      pendingChoice = Completer<String?>();
      await chooseFile();
      await playback.open(
        File('${root.path}/plain.mp4').absolute.uri.toString(),
      );
      expect(await playback.nativeSubtitleTrackCount(), 0);
      pendingChoice.complete('${root.path}/external/english.ass');
      await tester.pump(const Duration(milliseconds: 200));
      expect(await playback.nativeSubtitleTrackCount(), 0);
      expect(playback.selectedTracks.subtitle.id, 'auto');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  });
}
