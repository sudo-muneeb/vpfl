import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

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
    required this.onShowMediaInfo,
    required this.onShowDiagnostics,
    required this.tracks,
    required this.tracksStream,
    required this.onSetTrack,
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
  final VoidCallback onShowMediaInfo;
  final VoidCallback onShowDiagnostics;
  final Tracks tracks;
  final Stream<Tracks> tracksStream;
  final Future<void> Function(Object) onSetTrack;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onToggleFullscreen;

  static const Duration _seekStep = Duration(seconds: 10);
  static const List<double> _rates = [0.5, 0.75, 1, 1.25, 1.5, 2];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          _SeekBar(
            duration: duration,
            durationStream: durationStream,
            position: position,
            positionStream: positionStream,
            onSeek: onSeek,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              _QueueButton(
                playlist: playlist,
                playlistStream: playlistStream,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              IconButton(
                tooltip: 'Seek backward 10 seconds',
                onPressed: () => onSeekBy(-_seekStep),
                icon: const Icon(Icons.replay_10),
              ),
              StreamBuilder<bool>(
                stream: playingStream,
                initialData: isPlaying,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  final bool playing = snapshot.data ?? isPlaying;
                  return IconButton(
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: onPlayPause,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  );
                },
              ),
              IconButton(
                tooltip: 'Seek forward 10 seconds',
                onPressed: () => onSeekBy(_seekStep),
                icon: const Icon(Icons.forward_10),
              ),
              _RateButton(
                rate: rate,
                rateStream: rateStream,
                rates: _rates,
                onSetRate: onSetRate,
              ),
              _VolumeControl(
                volume: volume,
                volumeStream: volumeStream,
                onSetVolume: onSetVolume,
              ),
              _ShuffleButton(
                playlist: playlist,
                playlistStream: playlistStream,
                shuffle: shuffle,
                shuffleStream: shuffleStream,
                onSetShuffle: onSetShuffle,
              ),
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
                onShowMediaInfo: onShowMediaInfo,
                onShowDiagnostics: onShowDiagnostics,
              ),
              IconButton(
                tooltip: 'Toggle fullscreen',
                onPressed: onToggleFullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
            ],
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
                      width: 54,
                      child: Text(_formatTime(currentMilliseconds)),
                    ),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: totalMilliseconds > 0
                            ? totalMilliseconds.toDouble()
                            : 1,
                        value: currentMilliseconds.toDouble(),
                        onChanged: totalMilliseconds > 0 ? (_) {} : null,
                        onChangeEnd: totalMilliseconds > 0
                            ? (double value) =>
                                  onSeek(Duration(milliseconds: value.round()))
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        _formatTime(totalMilliseconds),
                        textAlign: TextAlign.end,
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
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _QueueButton extends StatelessWidget {
  const _QueueButton({
    required this.playlist,
    required this.playlistStream,
    required this.onPrevious,
    required this.onNext,
  });

  final Playlist playlist;
  final Stream<Playlist> playlistStream;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Playlist>(
      stream: playlistStream,
      initialData: playlist,
      builder: (BuildContext context, AsyncSnapshot<Playlist> snapshot) {
        if ((snapshot.data ?? playlist).medias.length < 2) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous video',
              onPressed: onPrevious,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: 'Next video',
              onPressed: onNext,
              icon: const Icon(Icons.skip_next),
            ),
          ],
        );
      },
    );
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text('${_formatRate(current)}×'),
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
  });

  final double volume;
  final Stream<double> volumeStream;
  final Future<void> Function(double) onSetVolume;

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
            SizedBox(
              width: 84,
              child: Slider(
                min: 0,
                max: 100,
                value: value,
                onChanged: (_) {},
                onChangeEnd: onSetVolume,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({
    required this.playlist,
    required this.playlistStream,
    required this.shuffle,
    required this.shuffleStream,
    required this.onSetShuffle,
  });

  final Playlist playlist;
  final Stream<Playlist> playlistStream;
  final bool shuffle;
  final Stream<bool> shuffleStream;
  final Future<void> Function(bool) onSetShuffle;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Playlist>(
      stream: playlistStream,
      initialData: playlist,
      builder: (BuildContext context, AsyncSnapshot<Playlist> playlistState) {
        if ((playlistState.data ?? playlist).medias.length < 2) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<bool>(
          stream: shuffleStream,
          initialData: shuffle,
          builder: (BuildContext context, AsyncSnapshot<bool> shuffleState) {
            final bool enabled = shuffleState.data ?? shuffle;
            return IconButton(
              tooltip: enabled ? 'Disable shuffle' : 'Enable shuffle',
              onPressed: () => onSetShuffle(!enabled),
              icon: Icon(
                Icons.shuffle,
                color: enabled ? Theme.of(context).colorScheme.primary : null,
              ),
            );
          },
        );
      },
    );
  }
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
    required this.onShowMediaInfo,
    required this.onShowDiagnostics,
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
  final VoidCallback onShowMediaInfo;
  final VoidCallback onShowDiagnostics;

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
                  case _PlayerActionKind.track:
                    await onSetTrack(action.value!);
                  case _PlayerActionKind.playlistMode:
                    await onSetPlaylistMode(action.value! as PlaylistMode);
                  case _PlayerActionKind.fit:
                    onSetFit(action.value! as BoxFit);
                  case _PlayerActionKind.screenshot:
                    await onScreenshot();
                  case _PlayerActionKind.mediaInfo:
                    onShowMediaInfo();
                  case _PlayerActionKind.diagnostics:
                    onShowDiagnostics();
                }
              },
              itemBuilder: (BuildContext context) => [
                if (available.audio.isNotEmpty) ...[
                  const PopupMenuItem<_PlayerAction>(
                    enabled: false,
                    child: Text('AUDIO'),
                  ),
                  for (final AudioTrack track in available.audio)
                    PopupMenuItem<_PlayerAction>(
                      value: _PlayerAction(_PlayerActionKind.track, track),
                      child: Text(_trackLabel(track)),
                    ),
                ],
                if (available.subtitle.isNotEmpty) ...[
                  const PopupMenuItem<_PlayerAction>(
                    enabled: false,
                    child: Text('SUBTITLES'),
                  ),
                  for (final SubtitleTrack track in available.subtitle)
                    PopupMenuItem<_PlayerAction>(
                      value: _PlayerAction(_PlayerActionKind.track, track),
                      child: Text(_trackLabel(track)),
                    ),
                ],
                const PopupMenuItem<_PlayerAction>(
                  enabled: false,
                  child: Text('PLAYBACK'),
                ),
                for (final PlaylistMode mode in PlaylistMode.values)
                  PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.playlistMode, mode),
                    child: Text(
                      '${currentMode == mode ? '✓ ' : ''}${_modeLabel(mode)}',
                    ),
                  ),
                const PopupMenuItem<_PlayerAction>(
                  enabled: false,
                  child: Text('VIDEO'),
                ),
                for (final BoxFit option in const [
                  BoxFit.contain,
                  BoxFit.cover,
                  BoxFit.fill,
                ])
                  PopupMenuItem<_PlayerAction>(
                    value: _PlayerAction(_PlayerActionKind.fit, option),
                    child: Text(
                      '${fit == option ? '✓ ' : ''}${_fitLabel(option)}',
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<_PlayerAction>(
                  value: _PlayerAction(_PlayerActionKind.screenshot),
                  child: Text('Save screenshot…'),
                ),
                const PopupMenuItem<_PlayerAction>(
                  value: _PlayerAction(_PlayerActionKind.mediaInfo),
                  child: Text('Media information'),
                ),
                const PopupMenuItem<_PlayerAction>(
                  value: _PlayerAction(_PlayerActionKind.diagnostics),
                  child: Text('Playback diagnostics'),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            );
          },
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
  track,
  playlistMode,
  fit,
  screenshot,
  mediaInfo,
  diagnostics,
}

class _PlayerAction {
  const _PlayerAction(this.kind, [this.value]);
  final _PlayerActionKind kind;
  final Object? value;
}
