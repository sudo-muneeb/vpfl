import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
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

  testWidgets('overflow menu exposes screenshot and one info action', (
    tester,
  ) async {
    bool screenshotRequested = false;
    bool infoRequested = false;
    await tester.pumpWidget(
      _app(
        _controls(
          onScreenshot: () async => screenshotRequested = true,
          onShowInfo: () => infoRequested = true,
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
    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(infoRequested, isTrue);
  });

  testWidgets('volume slider has usable travel and sends 0 to 100 values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final values = <double>[];
    await tester.pumpWidget(
      _app(
        _controls(volume: 35, onSetVolume: (value) async => values.add(value)),
      ),
    );
    final volumeSlider = find.byType(Slider).last;
    expect(tester.widget<Slider>(volumeSlider).value, 35);
    expect(tester.getSize(volumeSlider).width, 125);
    await tester.drag(volumeSlider, const Offset(35, 0));
    await tester.pump();
    expect(values, isNotEmpty);
    expect(values.every((value) => value >= 0 && value <= 100), isTrue);
    await tester.tap(find.byTooltip('Mute'));
    expect(values.last, 0);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: VpflTheme.dark,
  home: Scaffold(body: child),
);

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
  VoidCallback? onShowInfo,
  double volume = 100,
  Future<void> Function(double)? onSetVolume,
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
  volume: volume,
  volumeStream: const Stream<double>.empty(),
  onSetVolume: onSetVolume ?? (_) async {},
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
  onShowInfo: onShowInfo ?? () {},
  tracks: tracks,
  tracksStream: const Stream<Tracks>.empty(),
  onSetTrack: onSetTrack ?? (_) async {},
  onLoadSubtitleFile: () async {},
  onPrevious: () async {},
  onNext: () async {},
  onToggleFullscreen: () async {},
);
