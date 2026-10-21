import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/model/real_media_tracks.dart';
import '../../data/services/subtitle_delay.dart';

import '../core/themes/vpfl_theme_extension.dart';
import '../core/themes/vpfl_typography.dart';
import 'player_menu_style.dart';

/// Event-driven playback controls. Each stream only rebuilds the control that
/// displays its value, keeping position updates away from the rest of the UI.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    required this.duration,
    required this.durationStream,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSeekBy,
    required this.position,
    required this.positionStream,
    required this.playingStream,
    required this.rate,
    required this.rateStream,
    required this.onSetRate,
    required this.volume,
    required this.volumeStream,
    required this.onSetVolume,
    required this.playlist,
    required this.playlistStream,
    required this.shuffle,
    required this.shuffleStream,
    required this.onSetShuffle,
    required this.playlistMode,
    required this.playlistModeStream,
    required this.onSetPlaylistMode,
    required this.fit,
    required this.onSetFit,
    required this.onScreenshot,
    required this.onShowInfo,
    required this.tracks,
    required this.tracksStream,
    required this.selectedTracks,
    required this.selectedTracksStream,
    required this.onSetTrack,
    required this.onLoadSubtitleFile,
    required this.subtitleDelayMilliseconds,
    required this.subtitleDelayStream,
    required this.onAdjustSubtitleDelay,
    required this.onResetSubtitleDelay,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleFullscreen,
    required this.fullscreen,
    super.key,
  });

  final Duration duration;
  final Stream<Duration> durationStream;
  final bool isPlaying;
  final Future<void> Function() onPlayPause;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(Duration) onSeekBy;
  final Duration position;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;
  final double rate;
  final Stream<double> rateStream;
  final Future<void> Function(double) onSetRate;
  final double volume;
  final Stream<double> volumeStream;
  final Future<void> Function(double) onSetVolume;
  final Playlist playlist;
  final Stream<Playlist> playlistStream;
  final bool shuffle;
  final Stream<bool> shuffleStream;
  final Future<void> Function(bool) onSetShuffle;
  final PlaylistMode playlistMode;
  final Stream<PlaylistMode> playlistModeStream;
  final Future<void> Function(PlaylistMode) onSetPlaylistMode;
  final BoxFit fit;
  final ValueChanged<BoxFit> onSetFit;
  final Future<void> Function() onScreenshot;
  final VoidCallback onShowInfo;
  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Track selectedTracks;
  final Stream<Track> selectedTracksStream;
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onLoadSubtitleFile;
  final int Function() subtitleDelayMilliseconds;
  final Stream<int> subtitleDelayStream;
  final Future<void> Function(int) onAdjustSubtitleDelay;
  final Future<void> Function() onResetSubtitleDelay;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onToggleFullscreen;
  final bool fullscreen;

  static const Duration _seekStep = Duration(seconds: 10);
  static const List<double> _rates = [0.5, 0.75, 1, 1.25, 1.5, 2];
  static const double _controlHeight = 48;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return Theme(
      data: Theme.of(context)
          .copyWith(popupMenuTheme: PlayerMenuStyle.popupTheme(context)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SeekBar(
              duration: duration,
              durationStream: durationStream,
              position: position,
              positionStream: positionStream,
              onSeek: onSeek,
            ),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 860;
                final bool narrow = constraints.maxWidth < 600;
                return SizedBox(
                  height: _controlHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _OverflowMenu(
                              tracks: tracks,
                              tracksStream: tracksStream,
                              selectedTracks: selectedTracks,
                              selectedTracksStream: selectedTracksStream,
                              onSetTrack: onSetTrack,
                              onLoadSubtitleFile: onLoadSubtitleFile,
                              subtitleDelayMilliseconds:
                                  subtitleDelayMilliseconds,
                              subtitleDelayStream: subtitleDelayStream,
                              onAdjustSubtitleDelay: onAdjustSubtitleDelay,
                              onResetSubtitleDelay: onResetSubtitleDelay,
                              onSetRate: onSetRate,
                              rate: rate,
                              rateStream: rateStream,
                              rates: _rates,
                              narrow: narrow,
                              fit: fit,
                              onSetFit: onSetFit,
                              onScreenshot: onScreenshot,
                              onShowInfo: onShowInfo,
                            ),
                            _VolumeControl(
                              volume: volume,
                              volumeStream: volumeStream,
                              onSetVolume: onSetVolume,
                              showSlider: !compact,
                            ),
                            if (!narrow) ...[
                              _SubtitleButton(
                                tracks: tracks,
                                tracksStream: tracksStream,
                                selectedTracks: selectedTracks,
                                selectedTracksStream: selectedTracksStream,
                                onSetTrack: onSetTrack,
                                onLoadSubtitleFile: onLoadSubtitleFile,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Seek backward 10 seconds',
                            onPressed: () => onSeekBy(-_seekStep),
                            iconSize: 23,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(Icons.replay_10_rounded),
                          ),
                          StreamBuilder<bool>(
                            stream: playingStream,
                            initialData: isPlaying,
                            builder: (context, snapshot) => IconButton.filled(
                              tooltip: (snapshot.data ?? isPlaying)
                                  ? 'Pause'
                                  : 'Play',
                              onPressed: onPlayPause,
                              iconSize: 27,
                              constraints: const BoxConstraints.tightFor(
                                width: 46,
                                height: 46,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: tokens.playerControlSurface,
                                foregroundColor: tokens.playerControlForeground,
                              ),
                              icon: Icon(
                                (snapshot.data ?? isPlaying)
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Seek forward 10 seconds',
                            onPressed: () => onSeekBy(_seekStep),
                            iconSize: 23,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(Icons.forward_10_rounded),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!narrow)
                              _RateButton(
                                rate: rate,
                                rateStream: rateStream,
                                rates: _rates,
                                onSetRate: onSetRate,
                              ),
                            _ShuffleButton(
                              shuffle: shuffle,
                              stream: shuffleStream,
                              playlist: playlist,
                              playlistStream: playlistStream,
                              onSet: onSetShuffle,
                            ),
                            _RepeatButton(
                              mode: playlistMode,
                              stream: playlistModeStream,
                              onSet: onSetPlaylistMode,
                            ),
                            IconButton(
                              tooltip: fullscreen
                                  ? 'Exit Fullscreen'
                                  : 'Enter Fullscreen',
                              onPressed: onToggleFullscreen,
                              iconSize: 22,
                              icon: Icon(
                                fullscreen
                                    ? Icons.close_fullscreen_rounded
                                    : Icons.open_in_full_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.duration,
    required this.durationStream,
    required this.position,
    required this.positionStream,
    required this.onSeek,
  });

  final Duration duration;
  final Stream<Duration> durationStream;
  final Duration position;
  final Stream<Duration> positionStream;
  final Future<void> Function(Duration) onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _showRemaining = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return StreamBuilder<Duration>(
      stream: widget.durationStream,
      initialData: widget.duration,
      builder: (BuildContext context, AsyncSnapshot<Duration> durationState) {
        final durationMilliseconds = durationState.data?.inMilliseconds ?? 0;
        final int totalMilliseconds = durationMilliseconds.isNegative
            ? 0
            : durationMilliseconds;
        final timeStyle = VpflTypography.timecode.copyWith(
          color: tokens.playerOverlayForeground,
        );
        final widthLayout = TextPainter(
          text: TextSpan(
            text:
                '−${_formatTime(totalMilliseconds)} / ${_formatTime(totalMilliseconds)}',
            style: timeStyle,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final timeWidth = widthLayout.width.ceilToDouble();
        widthLayout.dispose();
        return StreamBuilder<Duration>(
          stream: widget.positionStream,
          initialData: widget.position,
          builder: (BuildContext context, AsyncSnapshot<Duration> positionState) {
            final int currentMilliseconds =
                (positionState.data?.inMilliseconds ?? 0).clamp(
                  0,
                  totalMilliseconds,
                );
            final int remainingMilliseconds =
                totalMilliseconds - currentMilliseconds;
            return Row(
              children: [
                Tooltip(
                  message: _showRemaining
                      ? 'Show elapsed time'
                      : 'Show remaining time',
                  child: Semantics(
                    button: true,
                    label: _showRemaining
                        ? 'Playback time remaining'
                        : 'Playback time elapsed',
                    value:
                        '${_formatTime(_showRemaining ? remainingMilliseconds : currentMilliseconds)} '
                        '${_showRemaining ? 'remaining' : 'elapsed'} of '
                        '${_formatTime(totalMilliseconds)} total',
                    child: InkWell(
                      onTap: () =>
                          setState(() => _showRemaining = !_showRemaining),
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: timeWidth,
                        height: 44,
                        child: Center(
                          child: Text(
                            '${_showRemaining && totalMilliseconds > 0 ? '−' : ''}'
                            '${_formatTime(_showRemaining ? remainingMilliseconds : currentMilliseconds)} / '
                            '${_formatTime(totalMilliseconds)}',
                            style: timeStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: tokens.playbackProgress,
                      inactiveTrackColor: tokens.playerOverlayForeground
                          .withValues(alpha: 0.35),
                      thumbColor: tokens.playbackProgress,
                      overlayColor: tokens.playbackProgress.withValues(
                        alpha: 0.18,
                      ),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      min: 0,
                      max: totalMilliseconds > 0
                          ? totalMilliseconds.toDouble()
                          : 1,
                      value: currentMilliseconds.toDouble(),
                      onChanged: totalMilliseconds > 0 ? (_) {} : null,
                      onChangeEnd: totalMilliseconds > 0
                          ? (double value) => widget.onSeek(
                              Duration(milliseconds: value.round()),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _formatTime(int milliseconds) {
    final Duration duration = Duration(milliseconds: milliseconds);
    final String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.rate,
    required this.rateStream,
    required this.rates,
    required this.onSetRate,
  });

  final double rate;
  final Stream<double> rateStream;
  final List<double> rates;
  final Future<void> Function(double) onSetRate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: rateStream,
      initialData: rate,
      builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
        final double current = snapshot.data ?? rate;
        return PopupMenuButton<double>(
          tooltip: 'Playback speed',
          clipBehavior: Clip.antiAlias,
          initialValue: current,
          onSelected: onSetRate,
          itemBuilder: (BuildContext context) =>
              PlayerMenuStyle.frostedPopupItems<double>([
                for (final double value in rates)
                  PopupMenuItem<double>(
                    value: value,
                    child: Text(
                      '${_formatRate(value)}×',
                      style: TextStyle(
                        color: current == value
                            ? Theme.of(context)
                                  .extension<VpflThemeExtension>()!
                                  .playbackProgress
                            : null,
                      ),
                    ),
                  ),
              ]),
          child: Tooltip(
            message: 'Playback speed: ${_formatRate(current)}×',
            child: SizedBox(
              width: 62,
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed_rounded, size: 21),
                  const SizedBox(width: 3),
                  Text(
                    '${_formatRate(current)}×',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatRate(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({
    required this.volume,
    required this.volumeStream,
    required this.onSetVolume,
    required this.showSlider,
  });

  final double volume;
  final Stream<double> volumeStream;
  final Future<void> Function(double) onSetVolume;
  final bool showSlider;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: volumeStream,
      initialData: volume,
      builder: (BuildContext context, AsyncSnapshot<double> snapshot) {
        final double value = (snapshot.data ?? volume).clamp(0, 100);
        final IconData icon = value == 0
            ? Icons.volume_off
            : value < 50
            ? Icons.volume_down
            : Icons.volume_up;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: value == 0 ? 'Unmute' : 'Mute',
              onPressed: () => onSetVolume(value == 0 ? 100 : 0),
              icon: Icon(icon),
            ),
            if (showSlider)
              SizedBox(
                width: 125,
                child: Slider(
                  min: 0,
                  max: 100,
                  value: value,
                  label: '${value.round()}%',
                  semanticFormatterCallback: (value) =>
                      'Volume ${value.round()} percent',
                  onChanged: (value) => unawaited(onSetVolume(value)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubtitleButton extends StatelessWidget {
  const _SubtitleButton({
    required this.tracks,
    required this.tracksStream,
    required this.selectedTracks,
    required this.selectedTracksStream,
    required this.onSetTrack,
    required this.onLoadSubtitleFile,
  });

  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Track selectedTracks;
  final Stream<Track> selectedTracksStream;
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onLoadSubtitleFile;

  @override
  Widget build(BuildContext context) => StreamBuilder<Track>(
    stream: selectedTracksStream,
    initialData: selectedTracks,
    builder: (context, selection) => StreamBuilder<Tracks>(
      stream: tracksStream,
      initialData: tracks,
      builder: (context, snapshot) {
        final subtitles = (snapshot.data ?? tracks).subtitle;
        final requested = (selection.data ?? selectedTracks).subtitle;
        return PopupMenuButton<Object>(
          tooltip: 'Subtitles',
          clipBehavior: Clip.antiAlias,
          onSelected: (choice) async {
            if (choice is SubtitleTrack) {
              await onSetTrack(choice);
            } else {
              await onLoadSubtitleFile();
            }
          },
          itemBuilder: (context) => PlayerMenuStyle.frostedPopupItems<Object>([
            for (final track in [
              SubtitleTrack.auto(),
              SubtitleTrack.no(),
              ...subtitles.where(
                (track) => track.id != 'auto' && track.id != 'no',
              ),
            ])
              CheckedPopupMenuItem<Object>(
                value: track,
                checked: requested.id == track.id,
                child: Text(
                  _OverflowMenu._trackLabel(track),
                  style: TextStyle(
                    color: requested.id == track.id
                        ? Theme.of(context)
                              .extension<VpflThemeExtension>()!
                              .playbackProgress
                        : null,
                  ),
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<Object>(
              value: 'load-file',
              child: Text('Load subtitle file…'),
            ),
          ]),
          icon: const Icon(Icons.closed_caption_outlined),
        );
      },
    ),
  );
}

class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({
    required this.shuffle,
    required this.stream,
    required this.playlist,
    required this.playlistStream,
    required this.onSet,
  });

  final bool shuffle;
  final Stream<bool> stream;
  final Playlist playlist;
  final Stream<Playlist> playlistStream;
  final Future<void> Function(bool) onSet;

  @override
  Widget build(BuildContext context) => StreamBuilder<Playlist>(
    stream: playlistStream,
    initialData: playlist,
    builder: (context, queueSnapshot) => StreamBuilder<bool>(
      stream: stream,
      initialData: shuffle,
      builder: (context, shuffleSnapshot) {
        final available = (queueSnapshot.data ?? playlist).medias.length > 1;
        final enabled = available && (shuffleSnapshot.data ?? shuffle);
        return IconButton(
          tooltip: !available
              ? 'Shuffle unavailable for one video'
              : enabled
              ? 'Shuffle on. Click to disable'
              : 'Shuffle off. Click to enable',
          onPressed: available ? () => onSet(!enabled) : null,
          icon: Icon(
            Icons.shuffle_rounded,
            color: enabled ? Theme.of(context).colorScheme.primary : null,
          ),
        );
      },
    ),
  );
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({
    required this.mode,
    required this.stream,
    required this.onSet,
  });

  final PlaylistMode mode;
  final Stream<PlaylistMode> stream;
  final Future<void> Function(PlaylistMode) onSet;

  @override
  Widget build(BuildContext context) => StreamBuilder<PlaylistMode>(
    stream: stream,
    initialData: mode,
    builder: (context, snapshot) {
      final current = snapshot.data ?? mode;
      final next = switch (current) {
        PlaylistMode.none => PlaylistMode.single,
        PlaylistMode.single => PlaylistMode.loop,
        PlaylistMode.loop => PlaylistMode.none,
      };
      return IconButton(
        tooltip: switch (current) {
          PlaylistMode.none => 'Repeat off. Click to repeat this video',
          PlaylistMode.single => 'Repeat this video. Click to repeat queue',
          PlaylistMode.loop => 'Repeat queue. Click to turn off',
        },
        onPressed: () => onSet(next),
        icon: Icon(
          current == PlaylistMode.single
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          color: current == PlaylistMode.none
              ? null
              : Theme.of(context).colorScheme.primary,
        ),
      );
    },
  );
}

Future<void> _showSubtitleDelayDialog(
  BuildContext context,
  int initialMilliseconds,
  Stream<int> changes,
  Future<void> Function(int) adjust,
  Future<void> Function() reset,
) => showDialog<void>(
  context: context,
  builder: (context) => Theme(
    data: PlayerMenuStyle.dialogTheme(context),
    child: AlertDialog(
      title: const Text('Subtitle timing'),
      content: StreamBuilder<int>(
        stream: changes,
        initialData: initialMilliseconds,
        builder: (context, snapshot) {
          final milliseconds = snapshot.data ?? initialMilliseconds;
          return SizedBox(
            width: 310,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Positive values show subtitles later.'),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Show subtitles 100 ms earlier',
                      onPressed: milliseconds <= -5000
                          ? null
                          : () => unawaited(adjust(-100)),
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        subtitleDelayLabel(milliseconds),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Show subtitles 100 ms later',
                      onPressed: milliseconds >= 5000
                          ? null
                          : () => unawaited(adjust(100)),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(reset()),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  ),
);

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.tracks,
    required this.tracksStream,
    required this.selectedTracks,
    required this.selectedTracksStream,
    required this.onSetTrack,
    required this.onLoadSubtitleFile,
    required this.subtitleDelayMilliseconds,
    required this.subtitleDelayStream,
    required this.onAdjustSubtitleDelay,
    required this.onResetSubtitleDelay,
    required this.onSetRate,
    required this.rate,
    required this.rateStream,
    required this.rates,
    required this.narrow,
    required this.fit,
    required this.onSetFit,
    required this.onScreenshot,
    required this.onShowInfo,
  });

  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Track selectedTracks;
  final Stream<Track> selectedTracksStream;
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onLoadSubtitleFile;
  final int Function() subtitleDelayMilliseconds;
  final Stream<int> subtitleDelayStream;
  final Future<void> Function(int) onAdjustSubtitleDelay;
  final Future<void> Function() onResetSubtitleDelay;
  final Future<void> Function(double) onSetRate;
  final double rate;
  final Stream<double> rateStream;
  final List<double> rates;
  final bool narrow;
  final BoxFit fit;
  final ValueChanged<BoxFit> onSetFit;
  final Future<void> Function() onScreenshot;
  final VoidCallback onShowInfo;

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
    stream: rateStream,
    initialData: rate,
    builder: (context, rateState) => StreamBuilder<Track>(
      stream: selectedTracksStream,
      initialData: selectedTracks,
      builder: (context, selectionState) => StreamBuilder<Tracks>(
        stream: tracksStream,
        initialData: tracks,
        builder: (BuildContext context, AsyncSnapshot<Tracks> trackState) {
          final Tracks available = trackState.data ?? tracks;
          return PopupMenuButton<_PlayerAction>(
            tooltip: 'More playback options',
            clipBehavior: Clip.antiAlias,
            onSelected: (_PlayerAction action) async {
              switch (action.kind) {
                case _PlayerActionKind.subtitles:
                  final Object? selected = await _chooseSubtitleSelection(
                    context,
                  );
                  if (selected is SubtitleTrack) {
                    await onSetTrack(selected);
                  } else if (selected == 'load-file') {
                    await onLoadSubtitleFile();
                  }
                case _PlayerActionKind.subtitleTiming:
                  await _showSubtitleDelayDialog(
                    context,
                    subtitleDelayMilliseconds(),
                    subtitleDelayStream,
                    onAdjustSubtitleDelay,
                    onResetSubtitleDelay,
                  );
                case _PlayerActionKind.rate:
                  final double? selected = await _chooseSelection<double>(
                    context,
                    'Playback speed',
                    [
                      for (final value in rates)
                        ('${_RateButton._formatRate(value)}×', value),
                    ],
                    selected: rateState.data ?? rate,
                  );
                  if (selected != null) await onSetRate(selected);
                case _PlayerActionKind.videoTracks:
                  final VideoTrack? track = await _chooseSelection<VideoTrack>(
                    context,
                    'Video tracks',
                    [
                      for (final track in available.video)
                        (_trackLabel(track), track),
                    ],
                    selected: (selectionState.data ?? selectedTracks).video,
                  );
                  if (track != null) await onSetTrack(track);
                case _PlayerActionKind.screenshot:
                  await onScreenshot();
                case _PlayerActionKind.info:
                  onShowInfo();
              }
            },
            itemBuilder: (BuildContext context) =>
                PlayerMenuStyle.frostedPopupItems<_PlayerAction>([
                  if (narrow) ...[
                    const PopupMenuItem<_PlayerAction>(
                      value: _PlayerAction(_PlayerActionKind.subtitles),
                      child: Text('Subtitles…'),
                    ),
                    const PopupMenuItem<_PlayerAction>(
                      value: _PlayerAction(_PlayerActionKind.rate),
                      child: Text('Playback speed…'),
                    ),
                  ],
                  const PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.subtitleTiming),
                    child: Text('Subtitle timing…'),
                  ),
                  if (RealMediaTracks(available).audio.isNotEmpty)
                    PopupMenuItem<_PlayerAction>(
                      enabled: false,
                      padding: EdgeInsets.zero,
                      child: MenuAnchor(
                        style: PlayerMenuStyle.menu(context),
                        alignmentOffset: const Offset(4, 0),
                        menuChildren: PlayerMenuStyle.frostedMenuChildren([
                          for (final track in available.audio)
                            MenuItemButton(
                              style: PlayerMenuStyle.item(
                                context,
                                selected:
                                    track ==
                                    (selectionState.data ?? selectedTracks)
                                        .audio,
                              ),
                              leadingIcon:
                                  track ==
                                      (selectionState.data ?? selectedTracks)
                                          .audio
                                  ? const Icon(Icons.check, size: 18)
                                  : const SizedBox(width: 18),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await onSetTrack(track);
                              },
                              child: Text(_trackLabel(track)),
                            ),
                        ]),
                        builder: (context, controller, child) => TextButton(
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .extension<VpflThemeExtension>()!
                                .playerOverlayForeground,
                            minimumSize: const Size(190, 48),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: Theme.of(context).textTheme.bodyMedium,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Audio tracks'),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (RealMediaTracks(available).video.length > 1)
                    const PopupMenuItem<_PlayerAction>(
                      value: _PlayerAction(_PlayerActionKind.videoTracks),
                      child: Text('Video tracks…'),
                    ),
                  PopupMenuItem<_PlayerAction>(
                    enabled: false,
                    padding: EdgeInsets.zero,
                    child: MenuAnchor(
                      style: PlayerMenuStyle.menu(context),
                      alignmentOffset: const Offset(4, 0),
                      menuChildren: PlayerMenuStyle.frostedMenuChildren([
                        for (final option in const [
                          BoxFit.contain,
                          BoxFit.cover,
                          BoxFit.fill,
                        ])
                          MenuItemButton(
                            style: PlayerMenuStyle.item(
                              context,
                              selected: fit == option,
                            ),
                            leadingIcon: fit == option
                                ? const Icon(Icons.check, size: 18)
                                : const SizedBox(width: 18),
                            onPressed: () {
                              onSetFit(option);
                              Navigator.of(context).pop();
                            },
                            child: Text(_fitLabel(option)),
                          ),
                      ]),
                      builder: (context, controller, child) => TextButton(
                        onPressed: () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context)
                              .extension<VpflThemeExtension>()!
                              .playerOverlayForeground,
                          minimumSize: const Size(190, 48),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: Theme.of(context).textTheme.bodyMedium,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Video fit'),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.screenshot),
                    child: Text('Save screenshot…'),
                  ),
                  const PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.info),
                    child: Text('Info'),
                  ),
                ]),
            icon: const Icon(Icons.more_vert),
          );
        },
      ),
    ),
  );

  Future<Object?> _chooseSubtitleSelection(BuildContext context) =>
      showDialog<Object>(
        context: context,
        builder: (context) => Theme(
          data: PlayerMenuStyle.dialogTheme(context),
          child: StreamBuilder<Track>(
            stream: selectedTracksStream,
            initialData: selectedTracks,
            builder: (context, selectedState) => StreamBuilder<Tracks>(
              stream: tracksStream,
              initialData: tracks,
              builder: (context, availableState) {
                final requested =
                    (selectedState.data ?? selectedTracks).subtitle;
                final subtitles = (availableState.data ?? tracks).subtitle;
                final options = [
                  SubtitleTrack.auto(),
                  SubtitleTrack.no(),
                  ...subtitles.where(
                    (track) => track.id != 'auto' && track.id != 'no',
                  ),
                ];
                return AlertDialog(
                  title: const Text('Subtitles'),
                  content: SizedBox(
                    width: 360,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length + 1,
                      itemBuilder: (context, index) {
                        if (index == options.length) {
                          return ListTile(
                            title: const Text('Load subtitle file…'),
                            onTap: () => Navigator.of(context).pop('load-file'),
                          );
                        }
                        final track = options[index];
                        return ListTile(
                          selected: requested.id == track.id,
                          selectedColor: Theme.of(context)
                              .extension<VpflThemeExtension>()!
                              .playbackProgress,
                          leading: requested.id == track.id
                              ? const Icon(Icons.check)
                              : const SizedBox(width: 24),
                          title: Text(_trackLabel(track)),
                          onTap: () => Navigator.of(context).pop(track),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

  Future<T?> _chooseSelection<T extends Object>(
    BuildContext context,
    String title,
    List<(String, T)> options, {
    T? selected,
  }) => showDialog<T>(
    context: context,
    builder: (BuildContext context) => Theme(
      data: PlayerMenuStyle.dialogTheme(context),
      child: AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (BuildContext context, int index) {
              final (String label, T value) = options[index];
              return ListTile(
                selected: value == selected,
                selectedColor: Theme.of(context)
                    .extension<VpflThemeExtension>()!
                    .playbackProgress,
                leading: value == selected
                    ? const Icon(Icons.check)
                    : const SizedBox(width: 24),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              );
            },
          ),
        ),
      ),
    ),
  );

  static String _fitLabel(BoxFit fit) => switch (fit) {
    BoxFit.contain => 'Fit',
    BoxFit.cover => 'Fill and crop',
    BoxFit.fill => 'Stretch',
    _ => 'Fit',
  };

  static String _trackLabel(Object track) => switch (track) {
    VideoTrack(id: 'auto') ||
    AudioTrack(id: 'auto') ||
    SubtitleTrack(id: 'auto') => 'Auto',
    VideoTrack(id: 'no') ||
    AudioTrack(id: 'no') ||
    SubtitleTrack(id: 'no') => 'Off',
    VideoTrack(:final id, :final title, :final language) ||
    AudioTrack(
      :final id,
      :final title,
      :final language,
    ) => title ?? language ?? 'Track $id',
    SubtitleTrack(:final id, :final title, :final language) => _metadataLabel(
      id,
      title,
      language,
    ),
    _ => 'Track',
  };

  static String _metadataLabel(String id, String? title, String? language) {
    final name = title?.trim();
    final lang = language?.trim();
    if (name != null && name.isNotEmpty) {
      if (lang != null &&
          lang.isNotEmpty &&
          lang.toLowerCase() != name.toLowerCase()) {
        return '$name · $lang';
      }
      return name;
    }
    return lang != null && lang.isNotEmpty ? lang : 'Track $id';
  }
}

enum _PlayerActionKind {
  subtitles,
  subtitleTiming,
  rate,
  videoTracks,
  screenshot,
  info,
}

class _PlayerAction {
  const _PlayerAction(this.kind);
  final _PlayerActionKind kind;
}
