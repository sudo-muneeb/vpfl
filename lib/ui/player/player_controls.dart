import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/model/real_media_tracks.dart';

import '../core/themes/vpfl_theme_extension.dart';
import '../core/themes/vpfl_typography.dart';

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
    required this.onSetTrack,
    required this.onLoadSubtitleFile,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleFullscreen,
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
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onLoadSubtitleFile;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onToggleFullscreen;

  static const Duration _seekStep = Duration(seconds: 10);
  static const List<double> _rates = [0.5, 0.75, 1, 1.25, 1.5, 2];
  static const double _controlHeight = 48;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return Padding(
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
                            onSetTrack: onSetTrack,
                            playlistMode: playlistMode,
                            playlistModeStream: playlistModeStream,
                            onSetPlaylistMode: onSetPlaylistMode,
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
                          _SubtitleButton(
                            tracks: tracks,
                            tracksStream: tracksStream,
                            onSetTrack: onSetTrack,
                            onLoadSubtitleFile: onLoadSubtitleFile,
                          ),
                          _RateButton(
                            rate: rate,
                            rateStream: rateStream,
                            rates: _rates,
                            onSetRate: onSetRate,
                          ),
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
                          _RepeatButton(
                            mode: playlistMode,
                            stream: playlistModeStream,
                            onSet: onSetPlaylistMode,
                          ),
                          IconButton(
                            tooltip: 'Toggle fullscreen',
                            onPressed: onToggleFullscreen,
                            iconSize: 22,
                            icon: const Icon(Icons.open_in_full_rounded),
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
    );
  }
}

class _SeekBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return StreamBuilder<Duration>(
      stream: durationStream,
      initialData: duration,
      builder: (BuildContext context, AsyncSnapshot<Duration> durationState) {
        final int totalMilliseconds = durationState.data?.inMilliseconds ?? 0;
        return StreamBuilder<Duration>(
          stream: positionStream,
          initialData: position,
          builder:
              (BuildContext context, AsyncSnapshot<Duration> positionState) {
                final int currentMilliseconds =
                    (positionState.data?.inMilliseconds ?? 0).clamp(
                      0,
                      totalMilliseconds,
                    );
                return Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        _formatTime(currentMilliseconds),
                        style: VpflTypography.timecode.copyWith(
                          color: tokens.playerOverlayForeground,
                        ),
                      ),
                    ),
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
                              ? (double value) => onSeek(
                                  Duration(milliseconds: value.round()),
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        _formatTime(totalMilliseconds),
                        textAlign: TextAlign.end,
                        style: VpflTypography.timecode.copyWith(
                          color: tokens.playerOverlayForeground,
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
          initialValue: current,
          onSelected: onSetRate,
          itemBuilder: (BuildContext context) => [
            for (final double value in rates)
              PopupMenuItem<double>(
                value: value,
                child: Text('${_formatRate(value)}×'),
              ),
          ],
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
    required this.onSetTrack,
    required this.onLoadSubtitleFile,
  });

  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onLoadSubtitleFile;

  @override
  Widget build(BuildContext context) => StreamBuilder<Tracks>(
    stream: tracksStream,
    initialData: tracks,
    builder: (context, snapshot) {
      final subtitles = (snapshot.data ?? tracks).subtitle;
      return PopupMenuButton<Object>(
        tooltip: 'Subtitles',
        onSelected: (selection) async {
          if (selection is SubtitleTrack) {
            await onSetTrack(selection);
          } else {
            await onLoadSubtitleFile();
          }
        },
        itemBuilder: (context) => [
          for (final track in [
            SubtitleTrack.auto(),
            SubtitleTrack.no(),
            ...subtitles.where(
              (track) => track.id != 'auto' && track.id != 'no',
            ),
          ])
            PopupMenuItem(
              value: track,
              child: Text(_OverflowMenu._trackLabel(track)),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'load-file',
            child: Text('Load subtitle file…'),
          ),
        ],
        icon: const Icon(Icons.closed_caption_outlined),
      );
    },
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

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.tracks,
    required this.tracksStream,
    required this.onSetTrack,
    required this.playlistMode,
    required this.playlistModeStream,
    required this.onSetPlaylistMode,
    required this.fit,
    required this.onSetFit,
    required this.onScreenshot,
    required this.onShowInfo,
  });

  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Future<void> Function(Object) onSetTrack;
  final PlaylistMode playlistMode;
  final Stream<PlaylistMode> playlistModeStream;
  final Future<void> Function(PlaylistMode) onSetPlaylistMode;
  final BoxFit fit;
  final ValueChanged<BoxFit> onSetFit;
  final Future<void> Function() onScreenshot;
  final VoidCallback onShowInfo;

  @override
  Widget build(BuildContext context) => StreamBuilder<Tracks>(
    stream: tracksStream,
    initialData: tracks,
    builder: (BuildContext context, AsyncSnapshot<Tracks> trackState) =>
        StreamBuilder<PlaylistMode>(
          stream: playlistModeStream,
          initialData: playlistMode,
          builder: (BuildContext context, AsyncSnapshot<PlaylistMode> modeState) {
            final Tracks available = trackState.data ?? tracks;
            final PlaylistMode currentMode = modeState.data ?? playlistMode;
            return PopupMenuButton<_PlayerAction>(
              tooltip: 'More playback options',
              onSelected: (_PlayerAction action) async {
                switch (action.kind) {
                  case _PlayerActionKind.audioTracks:
                    final AudioTrack? track =
                        await _chooseSelection<AudioTrack>(
                          context,
                          'Audio tracks',
                          [
                            for (final track in available.audio)
                              (_trackLabel(track), track),
                          ],
                        );
                    if (track != null) await onSetTrack(track);
                  case _PlayerActionKind.videoTracks:
                    final VideoTrack? track =
                        await _chooseSelection<VideoTrack>(
                          context,
                          'Video tracks',
                          [
                            for (final track in available.video)
                              (_trackLabel(track), track),
                          ],
                        );
                    if (track != null) await onSetTrack(track);
                  case _PlayerActionKind.playlistMode:
                    final PlaylistMode?
                    mode = await _chooseSelection<PlaylistMode>(
                      context,
                      'Repeat mode',
                      [
                        for (final mode in PlaylistMode.values)
                          (
                            '${mode == currentMode ? '✓ ' : ''}${_modeLabel(mode)}',
                            mode,
                          ),
                      ],
                    );
                    if (mode != null) await onSetPlaylistMode(mode);
                  case _PlayerActionKind.fit:
                    final BoxFit? selectedFit = await _chooseSelection<BoxFit>(
                      context,
                      'Video fit',
                      [
                        for (final option in const [
                          BoxFit.contain,
                          BoxFit.cover,
                          BoxFit.fill,
                        ])
                          (
                            '${fit == option ? '✓ ' : ''}${_fitLabel(option)}',
                            option,
                          ),
                      ],
                    );
                    if (selectedFit != null) onSetFit(selectedFit);
                  case _PlayerActionKind.screenshot:
                    await onScreenshot();
                  case _PlayerActionKind.info:
                    onShowInfo();
                }
              },
              itemBuilder: (BuildContext context) => [
                if (RealMediaTracks(available).audio.isNotEmpty)
                  const PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.audioTracks),
                    child: Text('Audio tracks…'),
                  ),
                if (RealMediaTracks(available).video.length > 1)
                  const PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.videoTracks),
                    child: Text('Video tracks…'),
                  ),
                const PopupMenuItem<_PlayerAction>(
                  value: _PlayerAction(_PlayerActionKind.playlistMode),
                  child: Text('Repeat mode…'),
                ),
                const PopupMenuItem<_PlayerAction>(
                  value: _PlayerAction(_PlayerActionKind.fit),
                  child: Text('Video fit…'),
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
              ],
              icon: const Icon(Icons.more_vert),
            );
          },
        ),
  );

  Future<T?> _chooseSelection<T extends Object>(
    BuildContext context,
    String title,
    List<(String, T)> options,
  ) => showDialog<T>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: options.length,
          itemBuilder: (BuildContext context, int index) {
            final (String label, T value) = options[index];
            return ListTile(
              title: Text(label),
              onTap: () => Navigator.of(context).pop(value),
            );
          },
        ),
      ),
    ),
  );

  static String _modeLabel(PlaylistMode mode) => switch (mode) {
    PlaylistMode.none => 'No repeat',
    PlaylistMode.single => 'Repeat one',
    PlaylistMode.loop => 'Repeat queue',
  };

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
    AudioTrack(:final id, :final title, :final language) ||
    SubtitleTrack(
      :final id,
      :final title,
      :final language,
    ) => title ?? language ?? 'Track $id',
    _ => 'Track',
  };
}

enum _PlayerActionKind {
  audioTracks,
  videoTracks,
  playlistMode,
  fit,
  screenshot,
  info,
}

class _PlayerAction {
  const _PlayerAction(this.kind);
  final _PlayerActionKind kind;
}
