import 'dart:io';

import 'package:drift/native.dart';
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
import 'package:vpfl/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const source = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets('a recoverable codec warning does not abort video playback', (
    tester,
  ) async {
    final uri = Uri.file(File(source).absolute.path).toString();
    final database = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    final playback = container.read(playbackServiceProvider);
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
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(Video), findsOneWidget);
      expect(find.text('VPFL could not open this file.'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await container.read(playbackHistoryRecorderProvider).dispose();
      await playback.dispose();
      await database.close();
      container.dispose();
    }
  }, skip: source.isEmpty);
}
