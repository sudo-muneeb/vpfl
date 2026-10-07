import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/native.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/data/services/playback_service.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets('invalid opens do not advance and a valid video recovers', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('vpfl-open-');
    final before = File('${directory.path}/a-valid.mp4');
    final declaration = File('${directory.path}/a.d.mts');
    final corrupt = File('${directory.path}/b-broken.mp4');
    final valid = File('${directory.path}/c-valid.mp4');
    await declaration.writeAsString('export type X = string;');
    await corrupt.writeAsString('not a video');
    await File(source).copy(before.path);
    await File(source).copy(valid.path);
    final declarationUri = Uri.file(declaration.path).toString();
    final corruptUri = Uri.file(corrupt.path).toString();
    final validUri = Uri.file(valid.path).toString();
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
    final selectedDuringFailure = <String>[];
    final playlistSubscription = playback.playlistStream.listen((queue) {
      if (queue.medias.isNotEmpty && queue.index >= 0) {
        selectedDuringFailure.add(queue.medias[queue.index].uri);
      }
    });
    try {
      await expectLater(
        playback.openWithDirectory(declarationUri),
        throwsA(isA<UnsupportedMediaException>()),
      );
      expect(playback.playlist.medias, isEmpty);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: VpflApp(initialMediaUri: corruptUri, startupError: null),
        ),
      );
      for (
        var i = 0;
        i < 100 &&
            find.text('VPFL could not open this file.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('VPFL could not open this file.'), findsOneWidget);
      expect(playback.isPlaying, isFalse);
      expect(playback.playlist.medias, hasLength(3));
      expect(playback.playlist.index, 1);
      expect(
        selectedDuringFailure.every(
          (uri) => Uri.tryParse(uri)?.pathSegments.last == 'b-broken.mp4',
        ),
        isTrue,
      );

      await tester.tap(find.text('Previous video'));
      for (var i = 0; i < 100 && !playback.hasVideoOutput; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('VPFL could not open this file.'), findsNothing);
      expect(playback.hasVideoOutput, isTrue);
      expect(playback.isPlaying, isTrue);
      expect(playback.playlist.index, 0);

      await playback.openWithDirectory(corruptUri);
      for (
        var i = 0;
        i < 100 &&
            find.text('VPFL could not open this file.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('VPFL could not open this file.'), findsOneWidget);
      expect(playback.playlist.index, 1);

      await tester.tap(find.text('Next video'));
      for (var i = 0; i < 100 && !playback.hasVideoOutput; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('VPFL could not open this file.'), findsNothing);
      expect(playback.hasVideoOutput, isTrue);
      expect(playback.isPlaying, isTrue);
      expect(playback.playlist.index, 2);
      expect(
        Uri.tryParse(playback.playlist.medias[playback.playlist.index].uri)
            ?.pathSegments
            .last,
        Uri.parse(validUri).pathSegments.last,
      );
      await playback.stop();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await playlistSubscription.cancel();
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
      await directory.delete(recursive: true);
    }
  }, skip: source.isEmpty);
}
