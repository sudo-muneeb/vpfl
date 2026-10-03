import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'video_controls_overlay.dart';

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
  StreamSubscription<dynamic>? _playlistSubscription;
  String? _playingUri;
  ValueNotifier<String?>? _renderingModeSource;
  BoxFit _videoFit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackServiceProvider);
    _playingUri = widget.initialMediaUri;
    _playlistSubscription = _playback.playlistStream.listen((queue) {
      if (!mounted ||
          queue.medias.isEmpty ||
          queue.index < 0 ||
          queue.index >= queue.medias.length) {
        return;
      }
      setState(() => _playingUri = queue.medias[queue.index].uri);
    });
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
      _playingUri = uri;
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

  bool get _textEntryHasFocus =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  void _runShortcut(Future<void> Function() action) {
    if (_textEntryHasFocus) return;
    unawaited(action());
  }

  void _toggleFullscreen() {
    final VideoState? videoState = _videoKey.currentState;
    if (videoState != null) _runShortcut(videoState.toggleFullscreen);
  }

  void _handleEscape() {
    if (_textEntryHasFocus) return;
    final VideoState? videoState = _videoKey.currentState;
    if (videoState?.isFullscreen() == true) {
      unawaited(videoState!.exitFullscreen());
    } else {
      widget.onBack();
    }
  }

  Map<ShortcutActivator, VoidCallback> _fullscreenShortcuts(VideoState state) =>
      {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _runShortcut(_playback.playOrPause),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _runShortcut(() => _playback.seekBy(const Duration(seconds: -10))),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _runShortcut(() => _playback.seekBy(const Duration(seconds: 10))),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _runShortcut(() => _playback.setVolume(_playback.volume + 5)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _runShortcut(() => _playback.setVolume(_playback.volume - 5)),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _runShortcut(_playback.toggleMute),
        const SingleActivator(LogicalKeyboardKey.keyF): state.toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): state.exitFullscreen,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickAndOpenFile,
      };

  Future<void> _readRenderingMode() async {
    try {
      final platformController =
          await _playback.videoController.platform.future;
      if (mounted) {
        _renderingModeSource = platformController.renderingMode;
        _renderingModeSource!.addListener(_updateRenderingMode);
        _updateRenderingMode();
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _renderingMode = 'unavailable');
      }
    }
  }

  void _updateRenderingMode() {
    if (mounted) {
      setState(() => _renderingMode = _renderingModeSource?.value);
    }
  }

  @override
  void dispose() {
    unawaited(_playlistSubscription?.cancel());
    _renderingModeSource?.removeListener(_updateRenderingMode);
    super.dispose();
  }

  Future<void> _saveScreenshot() async {
    try {
      final Uint8List? bytes = await _playback.screenshot();
      if (bytes == null) {
        throw StateError('The playback engine returned no image.');
      }
      final FileSaveLocation? destination = await getSaveLocation(
        suggestedName: 'vpfl-screenshot.png',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PNG image', extensions: ['png']),
        ],
      );
      if (destination == null) return;
      await XFile.fromData(
        bytes,
        mimeType: 'image/png',
      ).saveTo(destination.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot saved to ${destination.path}')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save screenshot: $error')),
        );
      }
    }
  }

  void _showMediaInfo() => _showDetailsDialog(
    title: 'Media information',
    rows: [
      ('File', _titleFor(widget.initialMediaUri)),
      ('Location', widget.initialMediaUri ?? 'Unavailable'),
      ('Duration', _formatDuration(_playback.duration)),
      ('Video tracks', '${_playback.tracks.video.length}'),
      ('Audio tracks', '${_playback.tracks.audio.length}'),
      ('Subtitle tracks', '${_playback.tracks.subtitle.length}'),
    ],
  );

  void _showDiagnostics() => _showDetailsDialog(
    title: 'Playback diagnostics',
    rows: [
      ('Video renderer', _renderingMode ?? 'Detecting'),
      ('Playback state', _playback.isPlaying ? 'Playing' : 'Paused'),
      ('Position', _formatDuration(_playback.position)),
      ('Duration', _formatDuration(_playback.duration)),
      ('Playback speed', '${_playback.rate}×'),
      ('Video tracks', '${_playback.tracks.video.length}'),
      ('Audio tracks', '${_playback.tracks.audio.length}'),
      ('Subtitle tracks', '${_playback.tracks.subtitle.length}'),
    ],
  );

  void _showDetailsDialog({
    required String title,
    required List<(String, String)> rows,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (String label, String value) in rows)
                  ListTile(
                    dense: true,
                    title: Text(label),
                    subtitle: SelectableText(value),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Unknown';
    final String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return duration.inHours > 0
        ? '${duration.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
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
      await _waitForVideoRenderer();
      await _playback.openWithDirectory(uri);
      if (resumePosition != null) {
        await _playback.seek(resumePosition);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _mediaError = 'Could not open this media file: $error');
      }
    }
  }

  Future<void> _waitForVideoRenderer() async {
    final platform = await _playback.videoController.platform.future;
    final mode = platform.renderingMode;
    if (mode.value == 'gpu' || mode.value == 'software') return;
    if (mode.value == 'unavailable') {
      throw StateError('No video renderer is available.');
    }
    final completer = Completer<void>();
    void listener() {
      if (mode.value == 'gpu' || mode.value == 'software') {
        if (!completer.isCompleted) completer.complete();
      } else if (mode.value == 'unavailable') {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('No video renderer is available.'),
          );
        }
      }
    }

    mode.addListener(listener);
    try {
      listener();
      await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      mode.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? error = widget.startupError ?? _mediaError;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _runShortcut(_playback.playOrPause),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _runShortcut(() => _playback.seekBy(const Duration(seconds: -10))),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _runShortcut(() => _playback.seekBy(const Duration(seconds: 10))),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _runShortcut(() => _playback.setVolume(_playback.volume + 5)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _runShortcut(() => _playback.setVolume(_playback.volume - 5)),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _runShortcut(_playback.toggleMute),
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickAndOpenFile,
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                title: _titleFor(_playingUri),
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
                          fit: _videoFit,
                          controls: (VideoState state) => VideoControlsOverlay(
                            title: _titleFor(_playingUri),
                            fullscreen: state.isFullscreen(),
                            playlist: _playback.playlist,
                            playlistStream: _playback.playlistStream,
                            onPrevious: _playback.previous,
                            onNext: _playback.next,
                            controls: _buildPlayerControls(
                              onToggleFullscreen: state.toggleFullscreen,
                            ),
                            onExit: state.exitFullscreen,
                            bindings: _fullscreenShortcuts(state),
                          ),
                        )
                      : _EmptyPlayer(error: error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PlayerControls _buildPlayerControls({
    required Future<void> Function() onToggleFullscreen,
  }) => PlayerControls(
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
    playlistMode: _playback.playlistMode,
    playlistModeStream: _playback.playlistModeStream,
    onSetPlaylistMode: _playback.setPlaylistMode,
    fit: _videoFit,
    onSetFit: (BoxFit fit) => setState(() => _videoFit = fit),
    onScreenshot: _saveScreenshot,
    onShowMediaInfo: _showMediaInfo,
    onShowDiagnostics: _showDiagnostics,
    tracks: _playback.tracks,
    tracksStream: _playback.tracksStream,
    onSetTrack: _playback.setTrack,
    onSeekBy: _playback.seekBy,
    onPrevious: _playback.previous,
    onNext: _playback.next,
    onToggleFullscreen: onToggleFullscreen,
  );

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
