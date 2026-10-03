import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/playback_service_provider.dart';
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: VpflApp(
          initialMediaUri: Uri.file(File(testVideoPath).absolute.path)
              .toString(),
          startupError: null,
        ),
      ),
    );

    final playback = container.read(playbackServiceProvider);
    final Duration firstPosition = await playback.positionStream
        .firstWhere((Duration position) => position > Duration.zero)
        .timeout(eventTimeout);
    expect(firstPosition, greaterThan(Duration.zero));
    final Duration duration = playback.duration;
    expect(duration, greaterThan(const Duration(seconds: 10)));

    const Duration seekTarget = Duration(seconds: 10);
    final Future<Duration> seekEvent = playback.positionStream
        .firstWhere((Duration position) => position >= seekTarget)
        .timeout(eventTimeout);
    await playback.seek(seekTarget);
    expect(await seekEvent, greaterThanOrEqualTo(seekTarget));

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

    final String mediaUri = Uri.file(File(testVideoPath).absolute.path)
        .toString();
    final Future<int> nextQueueItem = playback.playlistStream
        .firstWhere((Playlist queue) => queue.index == 1)
        .then((Playlist queue) => queue.index)
        .timeout(eventTimeout);
    await playback.openQueue([mediaUri, mediaUri]);
    await playback.next();
    expect(await nextQueueItem, 1);

    container.dispose();
  }, skip: testVideoPath.isEmpty);
}
