import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/playback_service_provider.dart';
import '../../data/services/playback_service.dart';
import '../core/themes/vpfl_theme_extension.dart';
import 'player_controls.dart';

/// Minimal playback surface used for the Linux compatibility baseline.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.initialMediaUri,
    required this.startupError,
    super.key,
  });

  final String? initialMediaUri;
  final String? startupError;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  late final PlaybackService _playback;
  String? _mediaError;
  String? _renderingMode;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackServiceProvider);
    unawaited(_readRenderingMode());
    if (widget.initialMediaUri case final String uri) {
      unawaited(_openMedia(uri));
    }
  }

  Future<void> _readRenderingMode() async {
    try {
      final platformController =
          await _playback.videoController.platform.future;
      if (mounted) {
        setState(() {
          _renderingMode = platformController.renderingMode.value;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _renderingMode = 'unavailable');
      }
    }
  }

  Future<void> _openMedia(String uri) async {
    try {
      await _playback.open(uri);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _mediaError = 'Could not open this media file: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = widget.startupError ?? _mediaError;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _PlayerTitleBar(
              title: _titleFor(widget.initialMediaUri),
              renderingMode: widget.initialMediaUri == null
                  ? null
                  : _renderingMode,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Theme.of(context)
                    .extension<VpflThemeExtension>()!
                    .playerBackground,
                alignment: Alignment.center,
                child: error == null && widget.initialMediaUri != null
                    ? Video(
                        key: _videoKey,
                        controller: _playback.videoController,
                        controls: NoVideoControls,
                      )
                    : _EmptyPlayer(error: error),
              ),
            ),
            if (widget.initialMediaUri != null && error == null)
              PlayerControls(
                duration: _playback.duration,
                durationStream: _playback.durationStream,
                isPlaying: _playback.isPlaying,
                onPlayPause: _playback.playOrPause,
                onSeek: _playback.seek,
                position: _playback.position,
                positionStream: _playback.positionStream,
                playingStream: _playback.playingStream,
                rate: _playback.rate,
                rateStream: _playback.rateStream,
                onSetRate: _playback.setRate,
                volume: _playback.volume,
                volumeStream: _playback.volumeStream,
                onSetVolume: _playback.setVolume,
                playlist: _playback.playlist,
                playlistStream: _playback.playlistStream,
                shuffle: _playback.shuffle,
                shuffleStream: _playback.shuffleStream,
                onSetShuffle: _playback.setShuffle,
                tracks: _playback.tracks,
                tracksStream: _playback.tracksStream,
                onSetTrack: _playback.setTrack,
                onSeekBy: _playback.seekBy,
                onPrevious: _playback.previous,
                onNext: _playback.next,
                onToggleFullscreen: () async {
                  await _videoKey.currentState?.toggleFullscreen();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _titleFor(String? uri) {
    if (uri == null) {
      return 'VPFL';
    }
    final List<String> segments = Uri.parse(uri).pathSegments;
    return segments.isEmpty ? 'VPFL' : Uri.decodeComponent(segments.last);
  }
}

class _PlayerTitleBar extends StatelessWidget {
  const _PlayerTitleBar({required this.title, required this.renderingMode});

  final String title;
  final String? renderingMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.movie_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (renderingMode != null || title != 'VPFL') ...[
              const SizedBox(width: 16),
              Text(switch (renderingMode) {
                'gpu' => 'GPU rendering',
                'software' => 'Software rendering',
                'unavailable' => 'Renderer unavailable',
                _ => 'Detecting renderer…',
              }, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, size: 56, color: foreground),
          const SizedBox(height: 16),
          Text(
            error ?? 'Open a video with `vpfl <file>`',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
