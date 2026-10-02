import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/player/player_controls.dart';

void main() {
  testWidgets('play control calls the playback action', (tester) async {
    bool toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerControls(
            duration: const Duration(minutes: 2),
            durationStream: const Stream<Duration>.empty(),
            isPlaying: false,
            onPlayPause: () async => toggled = true,
            onSeek: (_) async {},
            position: const Duration(seconds: 5),
            positionStream: const Stream<Duration>.empty(),
            playingStream: const Stream<bool>.empty(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('seek control is disabled without a media duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerControls(
            duration: Duration.zero,
            durationStream: const Stream<Duration>.empty(),
            isPlaying: false,
            onPlayPause: () async {},
            onSeek: (_) async {},
            position: Duration.zero,
            positionStream: const Stream<Duration>.empty(),
            playingStream: const Stream<bool>.empty(),
          ),
        ),
      ),
    );

    final Slider slider = tester.widget(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });
}
