import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/playback_service_provider.dart';
import '../../data/playback_history_recorder_provider.dart';
import '../../data/persistence_providers.dart';
import '../../data/services/media_file_picker.dart';
import '../../data/services/playback_service.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/themes/vpfl_theme_extension.dart';
import '../settings/settings_screen.dart';
import 'player_controls.dart';

/// Minimal playback surface used for the Linux compatibility baseline.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.initialMediaUri,
    required this.startupError,
    required this.onOpenMedia,
    required this.onBack,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.historyEnabled,
    required this.resumeEnabled,
    required this.onHistoryEnabledChanged,
    required this.onResumeEnabledChanged,
    super.key,
  });

  final String? initialMediaUri;
  final String? startupError;
  final ValueChanged<String> onOpenMedia;
  final VoidCallback onBack;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool historyEnabled;
  final bool resumeEnabled;
  final ValueChanged<bool> onHistoryEnabledChanged;
  final ValueChanged<bool> onResumeEnabledChanged;

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
    ref.read(playbackHistoryRecorderProvider);
    unawaited(_readRenderingMode());
    if (widget.initialMediaUri case final String uri) {
      unawaited(_openMedia(uri));
    }
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? uri = widget.initialMediaUri;
    if (oldWidget.initialMediaUri != uri && uri != null) {
      _mediaError = null;
      unawaited(_openMedia(uri));
    }
  }

  Future<void> _pickAndOpenFile() async {
    try {
      final String? uri = await pickVideoUri();
      if (uri == null) return;
      widget.onOpenMedia(uri);
      if (uri == widget.initialMediaUri) unawaited(_openMedia(uri));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the file picker: $error')),
        );
      }
    }
  }

  void _showSettings() {
    ThemeMode themeMode = widget.themeMode;
    bool historyEnabled = widget.historyEnabled;
    bool resumeEnabled = widget.resumeEnabled;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SizedBox(
          width: 620,
          height: 560,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) =>
                SettingsScreen(
                  themeMode: themeMode,
                  onThemeModeChanged: (ThemeMode value) {
                    widget.onThemeModeChanged(value);
                    setDialogState(() => themeMode = value);
                  },
                  historyEnabled: historyEnabled,
                  resumeEnabled: resumeEnabled,
                  onHistoryEnabledChanged: (bool value) {
                    widget.onHistoryEnabledChanged(value);
                    setDialogState(() => historyEnabled = value);
                  },
                  onResumeEnabledChanged: (bool value) {
                    widget.onResumeEnabledChanged(value);
                    setDialogState(() => resumeEnabled = value);
                  },
                ),
          ),
        ),
      ),
    );
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
    Duration? resumePosition;
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final bool resumeEnabled = await settings.getBool(
        'resumeEnabled',
        defaultValue: true,
      );
      resumePosition = resumeEnabled
          ? await ref
                .read(playbackHistoryRepositoryProvider)
                .resumePosition(uri)
          : null;
    } on Object catch (_) {
      // A storage failure must not prevent playback.
    }

    try {
      await _playback.open(uri);
      if (resumePosition != null) {
        await _playback.seek(resumePosition);
      }
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
            AppTopBar(
              title: _titleFor(widget.initialMediaUri),
              themeMode: widget.themeMode,
              onOpenFile: _pickAndOpenFile,
              onOpenSettings: _showSettings,
              onThemeModeChanged: widget.onThemeModeChanged,
              onBack: widget.onBack,
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
