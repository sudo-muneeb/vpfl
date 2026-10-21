import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme.dart';
import 'package:vpfl/ui/core/themes/vpfl_theme_extension.dart';
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
    expect(
      tester
          .widget<ListTile>(
            find.ancestor(of: find.text('1×'), matching: find.byType(ListTile)),
          )
          .selected,
      isTrue,
    );
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

  testWidgets('left time display toggles elapsed and remaining time', (
    tester,
  ) async {
    final positionChanges = StreamController<Duration>.broadcast(sync: true);
    addTearDown(positionChanges.close);
    await tester.pumpWidget(
      _app(_controls(positionStream: positionChanges.stream)),
    );

    final time = find.text('00:05 / 02:00');
    expect(time, findsOneWidget);
    expect(find.text('00:05'), findsNothing);
    expect(find.text('02:00'), findsNothing);
    expect(
      tester.getRect(time).right,
      lessThan(tester.getRect(find.byType(Slider).first).left),
    );
    expect(find.byTooltip('Show remaining time'), findsOneWidget);

    await tester.tap(time);
    await tester.pump();
    expect(find.text('−01:55 / 02:00'), findsOneWidget);
    expect(find.byTooltip('Show elapsed time'), findsOneWidget);

    positionChanges.add(const Duration(minutes: 2));
    await tester.pump();
    expect(find.text('−00:00 / 02:00'), findsOneWidget);

    await tester.tap(find.text('−00:00 / 02:00'));
    await tester.pump();
    expect(find.text('02:00 / 02:00'), findsOneWidget);
  });

  testWidgets('multi-day time toggle keeps seek track in place', (
    tester,
  ) async {
    for (final (duration, total, remaining) in [
      (
        const Duration(days: 2, hours: 3, minutes: 4, seconds: 5),
        '51:04:05',
        '50:04:05',
      ),
      (
        const Duration(days: 12, hours: 3, minutes: 4, seconds: 5),
        '291:04:05',
        '290:04:05',
      ),
    ]) {
      final positions = StreamController<Duration>.broadcast(sync: true);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          _controls(
            duration: duration,
            position: const Duration(hours: 1),
            positionStream: positions.stream,
          ),
        ),
      );
      expect(find.text('1:00:00 / $total'), findsOneWidget);
      final slider = find.byType(Slider).first;
      final initialTrack = tester.getRect(slider);

      await tester.tap(find.text('1:00:00 / $total'));
      await tester.pump();
      expect(find.text('−$remaining / $total'), findsOneWidget);
      expect(tester.getRect(slider), initialTrack);

      positions.add(duration - const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('−00:03 / $total'), findsOneWidget);
      expect(tester.getRect(slider), initialTrack);
      await positions.close();
    }
  });

  testWidgets('speed sits in the right control group at desktop width', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_controls()));

    final speed = tester.getRect(find.byTooltip('Playback speed'));
    final forward = tester.getRect(find.byTooltip('Seek forward 10 seconds'));
    final shuffle = tester.getRect(
      find.byTooltip('Shuffle unavailable for one video'),
    );
    expect(forward.right, lessThanOrEqualTo(speed.left));
    expect(speed.right, lessThanOrEqualTo(shuffle.left));
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
    expect(find.byType(BackdropFilter), findsWidgets);
    final menuContext = tester.element(find.text('1.5×'));
    final menuColor = PopupMenuTheme.of(menuContext).color!;
    expect(menuColor, const Color(0xB3000000));
    expect(PopupMenuTheme.of(menuContext).menuPadding, EdgeInsets.zero);
    final firstBlur = find.byType(BackdropFilter).first;
    final popupSurface = find
        .ancestor(of: firstBlur, matching: find.byType(Material))
        .first;
    expect(tester.getRect(firstBlur).top, tester.getRect(popupSurface).top);
    final popupShape =
        PopupMenuTheme.of(menuContext).shape! as RoundedRectangleBorder;
    expect(popupShape.side, BorderSide.none);
    final selectedItem = tester.widget<PopupMenuItem<double>>(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<double> && widget.value == 1,
      ),
    );
    expect(
      (selectedItem.child as Text).style?.color,
      VpflTheme.dark.extension<VpflThemeExtension>()!.playbackProgress,
    );
    await tester.tap(find.text('1.5×'));

    expect(selectedRate, 1.5);
  });

  testWidgets('audio tracks open beside the main menu and select a track', (
    tester,
  ) async {
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
    await tester.tap(find.text('Audio tracks'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(find.text('Save screenshot…'), findsOneWidget);
    expect(
      tester.getRect(find.text('Alternate')).left,
      greaterThan(tester.getRect(find.text('Audio tracks')).right),
    );
    final submenu = tester.widget<MenuAnchor>(
      find.ancestor(
        of: find.text('Alternate'),
        matching: find.byType(MenuAnchor),
      ),
    );
    final submenuShape =
        submenu.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(submenuShape.side, BorderSide.none);
    expect(submenu.style!.padding!.resolve({}), EdgeInsets.zero);
    final auto = tester.widget<MenuItemButton>(
      find.ancestor(
        of: find.text('Auto'),
        matching: find.byType(MenuItemButton),
      ),
    );
    expect(auto.leadingIcon, isA<Icon>());
    await tester.tap(find.text('Alternate'));
    await tester.pumpAndSettle();

    expect(selectedTrack, const AudioTrack('2', 'Alternate', 'eng'));
    expect(find.text('Save screenshot…'), findsNothing);
  });

  testWidgets('audio track menu is absent without a real audio stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _controls(
          tracks: const Tracks(
            audio: [
              AudioTrack('auto', null, null),
              AudioTrack('no', null, null),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    expect(find.text('Audio tracks'), findsNothing);
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
    await tester.tap(find.text('Video fit'));
    await tester.pumpAndSettle();
    expect(find.text('Save screenshot…'), findsOneWidget);
    expect(
      tester.getRect(find.text('Fill and crop')).left,
      greaterThan(tester.getRect(find.text('Video fit')).right),
    );
    await tester.tap(find.text('Fill and crop'));
    await tester.pumpAndSettle();
    expect(selectedFit, BoxFit.cover);
    expect(find.text('Save screenshot…'), findsNothing);
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
    final frostedRows = find.byType(BackdropFilter);
    final popupSurface = find
        .ancestor(of: frostedRows.first, matching: find.byType(Material))
        .first;
    expect(
      tester.getRect(frostedRows.first).top,
      tester.getRect(popupSurface).top,
    );
    expect(
      tester.getRect(frostedRows.last).bottom,
      tester.getRect(popupSurface).bottom,
    );
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

  testWidgets('CC menu labels tracks and checks the requested selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final english = SubtitleTrack('1', 'English', 'eng');
    final selected = StreamController<Track>.broadcast(sync: true);
    final available = StreamController<Tracks>.broadcast(sync: true);
    addTearDown(selected.close);
    addTearDown(available.close);
    final chosen = <String>[];
    final loaded = <String>[];
    await tester.pumpWidget(
      _app(
        _controls(
          tracks: Tracks(
            subtitle: [
              SubtitleTrack.auto(),
              SubtitleTrack.no(),
              english,
              const SubtitleTrack('2', null, 'urd'),
              const SubtitleTrack('3', null, null),
            ],
          ),
          tracksStream: available.stream,
          selectedTracksStream: selected.stream,
          onSetTrack: (track) async => chosen.add((track as SubtitleTrack).id),
          onLoadSubtitleFile: () async => loaded.add('load'),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    expect(find.text('English · eng'), findsOneWidget);
    expect(find.text('urd'), findsOneWidget);
    expect(find.text('Track 3'), findsOneWidget);
    var items = tester.widgetList<CheckedPopupMenuItem<Object>>(
      find.byType(CheckedPopupMenuItem<Object>),
    );
    expect(
      items
          .singleWhere((item) => (item.value as SubtitleTrack).id == 'auto')
          .checked,
      isTrue,
    );
    await tester.tap(
      find.ancestor(
        of: find.text('English · eng'),
        matching: find.byType(CheckedPopupMenuItem<Object>),
      ),
    );
    await tester.pumpAndSettle();
    expect(chosen, ['1']);

    selected.add(Track(subtitle: english));
    await tester.pump();
    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    items = tester.widgetList<CheckedPopupMenuItem<Object>>(
      find.byType(CheckedPopupMenuItem<Object>),
    );
    expect(
      items
          .singleWhere((item) => (item.value as SubtitleTrack).id == '1')
          .checked,
      isTrue,
    );
    expect(
      items
          .singleWhere((item) => (item.value as SubtitleTrack).id == 'auto')
          .checked,
      isFalse,
    );
    await tester.tap(find.text('Load subtitle file…'));
    await tester.pumpAndSettle();
    expect(loaded, ['load']);

    available.add(const Tracks());
    selected.add(const Track());
    await tester.pump();
    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    expect(find.text('English · eng'), findsNothing);
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets('compact CC dialog updates tracks and selects Off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final available = StreamController<Tracks>.broadcast(sync: true);
    addTearDown(available.close);
    String? selected;
    await tester.pumpWidget(
      _app(
        _controls(
          tracksStream: available.stream,
          onSetTrack: (track) async => selected = (track as SubtitleTrack).id,
        ),
      ),
    );
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtitles…'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    available.add(
      Tracks(
        subtitle: [
          SubtitleTrack.auto(),
          SubtitleTrack.no(),
          const SubtitleTrack('4', 'Japanese', 'jpn'),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Japanese · jpn'), findsOneWidget);
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(selected, 'no');
  });

  testWidgets('subtitle timing displays native updates and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = StreamController<int>.broadcast(sync: true);
    addTearDown(changes.close);
    final steps = <int>[];
    var current = 0;
    await tester.pumpWidget(
      _app(
        _controls(
          subtitleDelayStream: changes.stream,
          subtitleDelayValue: () => current,
          onAdjustSubtitleDelay: (step) async {
            steps.add(step);
            current += step;
            changes.add(current);
          },
          onResetSubtitleDelay: () async {
            current = 0;
            changes.add(current);
          },
        ),
      ),
    );
    await tester.tap(find.byTooltip('Subtitles'));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle timing…'), findsNothing);
    await tester.tapAt(const Offset(800, 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtitle timing…'));
    await tester.pumpAndSettle();
    expect(find.text('0 ms'), findsOneWidget);
    await tester.tap(find.byTooltip('Show subtitles 100 ms later'));
    await tester.pump();
    expect(find.text('+100 ms'), findsOneWidget);
    await tester.tap(find.byTooltip('Show subtitles 100 ms earlier'));
    await tester.pump();
    expect(steps, [100, -100]);
    current = -300;
    changes.add(current);
    await tester.pump();
    expect(find.text('−300 ms'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('0 ms'), findsOneWidget);
    current = 5000;
    changes.add(current);
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtitle timing…'));
    await tester.pumpAndSettle();
    expect(find.text('+5000 ms'), findsOneWidget);
  });

  testWidgets('compact overflow opens subtitle timing beside subtitles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_controls(subtitleDelayMilliseconds: -200)));
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtitles…'));
    await tester.pumpAndSettle();
    expect(find.text('Subtitle timing…'), findsNothing);
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More playback options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subtitle timing…'));
    await tester.pumpAndSettle();
    expect(find.text('−200 ms'), findsOneWidget);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: VpflTheme.dark,
  home: Scaffold(body: child),
);

PlayerControls _controls({
  Duration duration = const Duration(minutes: 2),
  Duration position = const Duration(seconds: 5),
  Stream<Duration> positionStream = const Stream<Duration>.empty(),
  Tracks tracks = const Tracks(),
  Stream<Tracks> tracksStream = const Stream<Tracks>.empty(),
  Track selectedTracks = const Track(),
  Stream<Track> selectedTracksStream = const Stream<Track>.empty(),
  Future<void> Function()? onPlayPause,
  Future<void> Function(Duration)? onSeekBy,
  Future<void> Function(double)? onSetRate,
  Future<void> Function(Object)? onSetTrack,
  Future<void> Function()? onLoadSubtitleFile,
  int subtitleDelayMilliseconds = 0,
  int Function()? subtitleDelayValue,
  Stream<int> subtitleDelayStream = const Stream<int>.empty(),
  Future<void> Function(int)? onAdjustSubtitleDelay,
  Future<void> Function()? onResetSubtitleDelay,
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
  position: position,
  positionStream: positionStream,
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
  tracksStream: tracksStream,
  selectedTracks: selectedTracks,
  selectedTracksStream: selectedTracksStream,
  onSetTrack: onSetTrack ?? (_) async {},
  onLoadSubtitleFile: onLoadSubtitleFile ?? () async {},
  subtitleDelayMilliseconds:
      subtitleDelayValue ?? () => subtitleDelayMilliseconds,
  subtitleDelayStream: subtitleDelayStream,
  onAdjustSubtitleDelay: onAdjustSubtitleDelay ?? (_) async {},
  onResetSubtitleDelay: onResetSubtitleDelay ?? () async {},
  onPrevious: () async {},
  onNext: () async {},
  onToggleFullscreen: onToggleFullscreen ?? () async {},
  fullscreen: fullscreen,
);
