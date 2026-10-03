import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/ui/player/player_controls.dart';

void main() {
  testWidgets('play control calls the playback action', (tester) async {
    bool toggled = false;
    await tester.pumpWidget(
      _app(_controls(onPlayPause: () async => toggled = true)),
    );

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('icon-only controls expose accessible labels', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_controls()));

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Seek backward 10 seconds'), findsOneWidget);
    expect(find.byTooltip('Seek forward 10 seconds'), findsOneWidget);
    expect(find.byTooltip('More playback options'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('seek control is disabled without a media duration', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_controls(duration: Duration.zero)));

    final Slider slider = tester.widget(find.byType(Slider).first);
    expect(slider.onChanged, isNull);
  });

  testWidgets('relative seek buttons request ten seconds', (tester) async {
    final List<Duration> seeks = [];
    await tester.pumpWidget(
      _app(_controls(onSeekBy: (value) async => seeks.add(value))),
    );

    await tester.tap(find.byTooltip('Seek forward 10 seconds'));
    await tester.tap(find.byTooltip('Seek backward 10 seconds'));

    expect(seeks, [const Duration(seconds: 10), const Duration(seconds: -10)]);
  });

  testWidgets('rate menu sends the selected playback rate', (tester) async {
    double? selectedRate;
    await tester.pumpWidget(
      _app(_controls(onSetRate: (value) async => selectedRate = value)),
    );

    await tester.tap(find.byTooltip('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));

    expect(selectedRate, 1.5);
  });

  testWidgets('overflow menu exposes media tracks', (tester) async {
    Object? selectedTrack;
    const Tracks tracks = Tracks(
      audio: [
        AudioTrack('auto', null, null),
        AudioTrack('no', null, null),
        AudioTrack('2', 'Alternate', 'eng'),
      ],
    );
    await tester.pumpWidget(
      _app(
        _controls(
          tracks: tracks,
          onSetTrack: (value) async => selectedTrack = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio tracks…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alternate'));

    expect(selectedTrack, const AudioTrack('2', 'Alternate', 'eng'));
  });

  testWidgets('overflow menu changes repeat mode and video fit', (
    tester,
  ) async {
    PlaylistMode? selectedMode;
    BoxFit? selectedFit;
    await tester.pumpWidget(
      _app(
        _controls(
          onSetPlaylistMode: (value) async => selectedMode = value,
          onSetFit: (value) => selectedFit = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat mode…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat one'));
    await tester.pumpAndSettle();
    expect(selectedMode, PlaylistMode.single);

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video fit…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill and crop'));
    await tester.pumpAndSettle();
    expect(selectedFit, BoxFit.cover);
  });

  testWidgets('overflow menu exposes screenshot, media info, and diagnostics', (
    tester,
  ) async {
    bool screenshotRequested = false;
    bool mediaInfoRequested = false;
    bool diagnosticsRequested = false;
    await tester.pumpWidget(
      _app(
        _controls(
          onScreenshot: () async => screenshotRequested = true,
          onShowMediaInfo: () => mediaInfoRequested = true,
          onShowDiagnostics: () => diagnosticsRequested = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save screenshot…'));
    await tester.pumpAndSettle();
    expect(screenshotRequested, isTrue);

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media information'));
    await tester.pumpAndSettle();
    expect(mediaInfoRequested, isTrue);

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playback diagnostics'));
    await tester.pumpAndSettle();
    expect(diagnosticsRequested, isTrue);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

PlayerControls _controls({
  Duration duration = const Duration(minutes: 2),
  Tracks tracks = const Tracks(),
  Future<void> Function()? onPlayPause,
  Future<void> Function(Duration)? onSeekBy,
  Future<void> Function(double)? onSetRate,
  Future<void> Function(Object)? onSetTrack,
  Future<void> Function(PlaylistMode)? onSetPlaylistMode,
  ValueChanged<BoxFit>? onSetFit,
  Future<void> Function()? onScreenshot,
  VoidCallback? onShowMediaInfo,
  VoidCallback? onShowDiagnostics,
}) => PlayerControls(
  duration: duration,
  durationStream: const Stream<Duration>.empty(),
  isPlaying: false,
  onPlayPause: onPlayPause ?? () async {},
  onSeek: (_) async {},
  onSeekBy: onSeekBy ?? (_) async {},
  position: const Duration(seconds: 5),
  positionStream: const Stream<Duration>.empty(),
  playingStream: const Stream<bool>.empty(),
  rate: 1,
  rateStream: const Stream<double>.empty(),
  onSetRate: onSetRate ?? (_) async {},
  volume: 100,
  volumeStream: const Stream<double>.empty(),
  onSetVolume: (_) async {},
  playlist: const Playlist([]),
  playlistStream: const Stream<Playlist>.empty(),
  shuffle: false,
  shuffleStream: const Stream<bool>.empty(),
  onSetShuffle: (_) async {},
  playlistMode: PlaylistMode.none,
  playlistModeStream: const Stream<PlaylistMode>.empty(),
  onSetPlaylistMode: onSetPlaylistMode ?? (_) async {},
  fit: BoxFit.contain,
  onSetFit: onSetFit ?? (_) {},
  onScreenshot: onScreenshot ?? () async {},
  onShowMediaInfo: onShowMediaInfo ?? () {},
  onShowDiagnostics: onShowDiagnostics ?? () {},
  tracks: tracks,
  tracksStream: const Stream<Tracks>.empty(),
  onSetTrack: onSetTrack ?? (_) async {},
  onPrevious: () async {},
  onNext: () async {},
  onToggleFullscreen: () async {},
);
