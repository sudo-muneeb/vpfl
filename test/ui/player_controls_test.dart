import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('shuffle sits beside repeat and is disabled for one item', (
    tester,
  ) async {
    bool? selected;
    final shuffleChanges = StreamController<bool>.broadcast(sync: true);
    addTearDown(shuffleChanges.close);
    await tester.pumpWidget(
      _app(
        _controls(
          playlist: Playlist([Media('file:///one.mp4')]),
          onSetShuffle: (value) async => selected = value,
        ),
      ),
    );
    expect(find.byTooltip('Shuffle unavailable for one video'), findsOneWidget);
    final shuffleButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.shuffle_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(shuffleButton.onPressed, isNull);
    expect(selected, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _app(
        _controls(
          playlist: Playlist([
            Media('file:///one.mp4'),
            Media('file:///two.mp4'),
          ]),
          shuffleStream: shuffleChanges.stream,
          onSetShuffle: (value) async {
            selected = value;
            shuffleChanges.add(value);
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('Shuffle off. Click to enable'));
    await tester.pump();
    expect(selected, isTrue);
    expect(find.byTooltip('Shuffle on. Click to disable'), findsOneWidget);
    await tester.tap(find.byTooltip('Shuffle on. Click to disable'));
    await tester.pump();
    expect(selected, isFalse);
    final shuffleCenter = tester.getCenter(find.byIcon(Icons.shuffle_rounded));
    final repeatCenter = tester.getCenter(find.byIcon(Icons.repeat_rounded));
    expect(shuffleCenter.dx, lessThan(repeatCenter.dx));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _app(
        _controls(
          playlist: Playlist([
            Media('file:///one.mp4'),
            Media('file:///two.mp4'),
          ]),
          shuffle: true,
        ),
      ),
    );
    expect(find.byTooltip('Shuffle on. Click to disable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact controls keep shuffle clear of transport buttons', (
    tester,
  ) async {
    double? selectedRate;
    tester.view.physicalSize = const Size(480, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        _controls(
          onSetRate: (value) async => selectedRate = value,
          playlist: Playlist([
            Media('file:///one.mp4'),
            Media('file:///two.mp4'),
          ]),
        ),
      ),
    );

    final overflow = tester.getRect(find.byTooltip('More playback options'));
    final backward = tester.getRect(find.byTooltip('Seek backward 10 seconds'));
    final forward = tester.getRect(find.byTooltip('Seek forward 10 seconds'));
    final shuffle = tester.getRect(
      find.byTooltip('Shuffle off. Click to enable'),
    );
    expect(overflow.right, lessThanOrEqualTo(backward.left));
    expect(forward.right, lessThanOrEqualTo(shuffle.left));
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    expect(find.text('Subtitles…'), findsOneWidget);
    expect(find.text('Playback speed…'), findsOneWidget);
    await tester.tap(find.text('Playback speed…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(selectedRate, 1.5);
    expect(tester.takeException(), isNull);
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

  testWidgets('overflow omits repeat while the visible button still cycles', (
    tester,
  ) async {
    PlaylistMode? selectedMode;
    BoxFit? selectedFit;
    final modeChanges = StreamController<PlaylistMode>.broadcast(sync: true);
    addTearDown(modeChanges.close);
    await tester.pumpWidget(
      _app(
        _controls(
          playlistModeStream: modeChanges.stream,
          onSetPlaylistMode: (value) async {
            selectedMode = value;
            modeChanges.add(value);
          },
          onSetFit: (value) => selectedFit = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    expect(find.text('Repeat mode…'), findsNothing);
    expect(find.text('Save screenshot…'), findsOneWidget);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Repeat off. Click to repeat this video'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Repeat off. Click to repeat this video'));
    expect(selectedMode, PlaylistMode.single);
    await tester.pump();
    await tester.tap(
      find.byTooltip('Repeat this video. Click to repeat queue'),
    );
    expect(selectedMode, PlaylistMode.loop);
    await tester.pump();
    await tester.tap(find.byTooltip('Repeat queue. Click to turn off'));
    expect(selectedMode, PlaylistMode.none);

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video fit…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill and crop'));
    await tester.pumpAndSettle();
    expect(selectedFit, BoxFit.cover);
  });

  testWidgets('fullscreen icon and tooltip follow the supplied window state', (
    tester,
  ) async {
    var toggles = 0;
    Widget controls(bool fullscreen) => _app(
      _controls(
        fullscreen: fullscreen,
        onToggleFullscreen: () async => toggles++,
      ),
    );

    await tester.pumpWidget(controls(false));
    expect(find.byTooltip('Enter Fullscreen'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Enter Fullscreen'));
    expect(toggles, 1);

    await tester.pumpWidget(controls(true));
    expect(find.byTooltip('Exit Fullscreen'), findsOneWidget);
    expect(find.byIcon(Icons.close_fullscreen_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Exit Fullscreen'));
    expect(toggles, 2);

    await tester.pumpWidget(controls(false));
    expect(find.byTooltip('Enter Fullscreen'), findsOneWidget);
  });

  testWidgets('keyboard fullscreen change updates button state', (
    tester,
  ) async {
    var fullscreen = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: VpflTheme.dark,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyF): () =>
                    setState(() => fullscreen = !fullscreen),
              },
              child: Focus(
                autofocus: true,
                child: _controls(fullscreen: fullscreen),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Enter Fullscreen'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(find.byTooltip('Exit Fullscreen'), findsOneWidget);
    expect(find.byIcon(Icons.close_fullscreen_rounded), findsOneWidget);
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
  Stream<PlaylistMode> playlistModeStream = const Stream<PlaylistMode>.empty(),
  ValueChanged<BoxFit>? onSetFit,
  bool fullscreen = false,
  Future<void> Function()? onToggleFullscreen,
  Future<void> Function()? onScreenshot,
  VoidCallback? onShowInfo,
  double volume = 100,
  Future<void> Function(double)? onSetVolume,
  Playlist playlist = const Playlist([]),
  bool shuffle = false,
  Future<void> Function(bool)? onSetShuffle,
  Stream<bool> shuffleStream = const Stream<bool>.empty(),
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
  playlist: playlist,
  playlistStream: const Stream<Playlist>.empty(),
  shuffle: shuffle,
  shuffleStream: shuffleStream,
  onSetShuffle: onSetShuffle ?? (_) async {},
  playlistMode: PlaylistMode.none,
  playlistModeStream: playlistModeStream,
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
  onToggleFullscreen: onToggleFullscreen ?? () async {},
  fullscreen: fullscreen,
);
