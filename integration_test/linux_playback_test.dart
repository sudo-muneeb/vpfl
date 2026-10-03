import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/model/app_database.dart';
import 'package:vpfl/data/playback_service_provider.dart';
import 'package:vpfl/data/playback_history_recorder_provider.dart';
import 'package:vpfl/data/persistence_providers.dart';
import 'package:vpfl/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  const Duration eventTimeout = Duration(seconds: 20);
  const String testVideoPath = String.fromEnvironment('VPFL_TEST_VIDEO');

  testWidgets('Linux playback advances, seeks, and pauses a local video', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    final String mediaUri = Uri.file(File(testVideoPath).absolute.path)
        .toString();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: VpflApp(initialMediaUri: mediaUri, startupError: null),
      ),
    );

    final playback = container.read(playbackServiceProvider);
    final Duration firstPosition = await playback.positionStream
        .firstWhere((Duration position) => position > Duration.zero)
        .timeout(eventTimeout);
    expect(firstPosition, greaterThan(Duration.zero));
    final Duration duration = playback.duration;
    expect(duration, greaterThan(const Duration(seconds: 10)));
    final history = container.read(playbackHistoryRepositoryProvider);
    final rows = history
        .watchRecent()
        .firstWhere((items) => items.any((item) => item.uri == mediaUri))
        .timeout(eventTimeout);
    final PlaybackHistory recorded = (await rows).singleWhere(
      (item) => item.uri == mediaUri,
    );
    expect(recorded.watchCount, greaterThan(0));

    const Duration seekTarget = Duration(seconds: 10);
    final savedPosition = history
        .watchRecent()
        .firstWhere(
          (items) => items.any(
            (item) => item.uri == mediaUri && item.positionMs >= 10000,
          ),
        )
        .timeout(eventTimeout);
    final Future<Duration> seekEvent = playback.positionStream
        .firstWhere((Duration position) => position >= seekTarget)
        .timeout(eventTimeout);
    await playback.seek(seekTarget);
    expect(await seekEvent, greaterThanOrEqualTo(seekTarget));
    final savedRows = await savedPosition;
    expect(
      await history.resumePosition(mediaUri),
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
    expect(savedRows.any((item) => item.uri == mediaUri), isTrue);

    final Future<bool> pausedEvent = playback.playingStream
        .firstWhere((bool isPlaying) => !isPlaying)
        .timeout(eventTimeout);
    await playback.playOrPause();
    expect(await pausedEvent, isFalse);

    final Future<double> rateEvent = playback.rateStream
        .firstWhere((double rate) => rate == 1.25)
        .timeout(eventTimeout);
    await playback.setRate(1.25);
    expect(await rateEvent, 1.25);

    final Future<double> volumeEvent = playback.volumeStream
        .firstWhere((double volume) => volume == 35)
        .timeout(eventTimeout);
    await playback.setVolume(35);
    expect(await volumeEvent, 35);

    final Future<int> nextQueueItem = playback.playlistStream
        .firstWhere((Playlist queue) => queue.index == 1)
        .then((Playlist queue) => queue.index)
        .timeout(eventTimeout);
    await playback.openQueue([mediaUri, mediaUri]);
    await playback.next();
    expect(await nextQueueItem, 1);

    await container.read(playbackHistoryRecorderProvider).dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  }, skip: testVideoPath.isEmpty);
}
