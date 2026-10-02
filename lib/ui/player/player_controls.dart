import 'package:flutter/material.dart';

/// Playback controls that subscribe only to the engine state they display.
class PlayerControls extends StatelessWidget {
  const PlayerControls({
    required this.duration,
    required this.durationStream,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeek,
    required this.position,
    required this.positionStream,
    required this.playingStream,
    super.key,
  });

  final Duration duration;
  final Stream<Duration> durationStream;
  final bool isPlaying;
  final Future<void> Function() onPlayPause;
  final Future<void> Function(Duration) onSeek;
  final Duration position;
  final Stream<Duration> positionStream;
  final Stream<bool> playingStream;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          StreamBuilder<Duration>(
            stream: durationStream,
            initialData: duration,
            builder: (BuildContext context, AsyncSnapshot<Duration> duration) {
              final int totalMilliseconds = duration.data?.inMilliseconds ?? 0;
              return StreamBuilder<Duration>(
                stream: positionStream,
                initialData: position,
                builder:
                    (BuildContext context, AsyncSnapshot<Duration> position) {
                      final int currentMilliseconds =
                          (position.data?.inMilliseconds ?? 0).clamp(
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
                                  ? (double value) => onSeek(
                                      Duration(milliseconds: value.round()),
                                    )
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
          ),
          StreamBuilder<bool>(
            stream: playingStream,
            initialData: isPlaying,
            builder: (BuildContext context, AsyncSnapshot<bool> playing) {
              final bool isPlaying = playing.data ?? false;
              return IconButton(
                tooltip: isPlaying ? 'Pause' : 'Play',
                onPressed: onPlayPause,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(int milliseconds) {
    final Duration duration = Duration(milliseconds: milliseconds);
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
