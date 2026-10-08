import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/playback_service_provider.dart';
import '../../data/model/real_media_tracks.dart';
import '../../data/default_app_prompt_provider.dart';
import '../../data/playback_history_recorder_provider.dart';
import '../../data/persistence_providers.dart';
import '../../data/services/media_file_picker.dart';
import '../../data/services/playback_service.dart';
import '../../data/services/lifecycle_trace.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/themes/vpfl_theme_extension.dart';
import '../settings/default_app_controls.dart';
import 'player_controls.dart';
import 'player_inspector.dart';
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
  final FocusNode _shortcutFocus = FocusNode(debugLabel: 'Player shortcuts');
  late final PlaybackService _playback;
  String? _mediaError;
  String? _renderingMode;
  StreamSubscription<dynamic>? _playlistSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Tracks>? _tracksSubscription;
  StreamSubscription<Track>? _selectedTracksSubscription;
  Timer? _errorProbe;
  String? _playingUri;
  int? _selectedQueueIndex;
  int _errorGeneration = 0;
  int _playGeneration = 0;
  int _openGeneration = 0;
  int _countedGeneration = 0;
  ValueNotifier<String?>? _renderingModeSource;
  BoxFit _videoFit = BoxFit.contain;
  final ValueNotifier<InspectorMode?> _inspectorMode = ValueNotifier(null);

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
      final String uri = queue.medias[queue.index].uri;
      if (uri != _playingUri) ++_openGeneration;
      if (uri != _playingUri || queue.index != _selectedQueueIndex) {
        _resetMediaError();
        _playGeneration += 1;
      }
      _selectedQueueIndex = queue.index;
      setState(() => _playingUri = uri);
    });
    _playingSubscription = _playback.playingStream.listen((playing) {
      if (playing) _recordPromptPlayIfNeeded();
    });
    _errorSubscription = _playback.errorStream.listen(_handlePlayerError);
    _tracksSubscription = _playback.tracksStream.listen((_) {
      if (mounted) setState(() {});
    });
    _selectedTracksSubscription = _playback.selectedTracksStream.listen((_) {
      if (mounted) setState(() {});
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
      _focusShortcuts();
      unawaited(_openMedia(uri));
    }
  }

  void _focusShortcuts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _shortcutFocus.requestFocus();
      }
    });
  }

  void _resetMediaError() {
    _errorProbe?.cancel();
    ++_errorGeneration;
    _mediaError = null;
  }

  void _handlePlayerError(String _) {
    if (!mounted || _playingUri == null || _mediaError != null) return;
    // media_kit forwards mpv decoder log messages as errors, including
    // recoverable hardware-decoder failures. Wait for actual video or playback
    // progress before deciding that the source cannot be opened.
    final generation = _errorGeneration;
    _errorProbe?.cancel();
    _errorProbe = Timer(const Duration(seconds: 3), () {
      if (!mounted || generation != _errorGeneration) return;
      if (_playback.hasVideoOutput || _playback.position > Duration.zero) {
        return;
      }
      _showMediaError('VPFL could not open this file.');
    });
  }

  void _showMediaError(String message) {
    if (!mounted) return;
    _errorProbe?.cancel();
    LifecycleTrace.event(
      'media.open.failed',
      session: _playback.sessionId,
      detail: 'reason=unsupported-or-invalid',
    );
    setState(() => _mediaError = message);
    unawaited(_stopFailedMedia());
  }

  Future<void> _stopFailedMedia() async {
    try {
      await _playback.stopFailedMedia();
    } on Object catch (error, stackTrace) {
      stderr.writeln('VPFL could not stop failed media: $error\n$stackTrace');
    }
  }

  Future<void> _navigate(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      stderr.writeln(
        'VPFL could not open the selected video: $error\n$stackTrace',
      );
      _showMediaError('Could not open this media file: $error');
    }
  }

  Future<void> _previousVideo() => _navigate(_playback.previous);
  Future<void> _nextVideo() => _navigate(_playback.next);

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

  Future<void> _pickSubtitleFile() async {
    try {
      final String? path = await pickSubtitlePath();
      if (path == null) return;
      await _playback.loadSubtitleFile(path);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load subtitles: $error')),
        );
      }
    }
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
    if (_inspectorMode.value != null) {
      _inspectorMode.value = null;
      return;
    }
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
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
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
    ++_openGeneration;
    _errorProbe?.cancel();
    _shortcutFocus.dispose();
    _inspectorMode.dispose();
    unawaited(_playlistSubscription?.cancel());
    unawaited(_playingSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    unawaited(_tracksSubscription?.cancel());
    unawaited(_selectedTracksSubscription?.cancel());
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

  void _toggleInfo() => _inspectorMode.value = _inspectorMode.value == null
      ? InspectorMode.media
      : null;

  String? _titleTooltip() {
    final uri = _playingUri;
    if (uri == null) return null;
    final parsed = Uri.tryParse(uri);
    final location = parsed?.scheme == 'file' ? parsed!.toFilePath() : uri;
    final tracks = RealMediaTracks(_playback.tracks);
    final video = tracks.activeVideo(_playback.selectedTracks.video.id);
    final summary = video == null
        ? null
        : mediaTechnicalSummary(video.codec, video.w, video.h, fps: video.fps);
    return summary == null ? location : '$location\n$summary';
  }

  Future<void> _openMedia(String uri) async {
    final int openGeneration = ++_openGeneration;
    _resetMediaError();
    _playGeneration += 1;
    Duration? resumePosition;
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final bool resumeEnabled = await settings.getBool(
        'resumeEnabled',
        defaultValue: true,
      );
      if (!mounted || openGeneration != _openGeneration) return;
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
      if (!mounted || openGeneration != _openGeneration) return;
      await _playback.openWithDirectory(uri);
      if (!mounted || openGeneration != _openGeneration) return;
      if (_playback.isPlaying) _recordPromptPlayIfNeeded();
      if (resumePosition != null) {
        await _playback.seek(resumePosition);
      }
    } on Object catch (error, stackTrace) {
      stderr.writeln('VPFL could not open $uri: $error\n$stackTrace');
      if (mounted && openGeneration == _openGeneration) {
        _showMediaError(
          error is UnsupportedMediaException
              ? 'VPFL could not open this file.'
              : 'Could not open this media file: $error',
        );
      }
    }
  }

  void _recordPromptPlayIfNeeded() {
    if (!mounted || _playGeneration == _countedGeneration) return;
    _countedGeneration = _playGeneration;
    unawaited(ref.read(defaultAppPromptProvider).recordPlay());
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
      child: Focus(
        focusNode: _shortcutFocus,
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                AppTopBar(
                  title: _titleFor(_playingUri),
                  titleTooltip: _titleTooltip(),
                  themeMode: widget.themeMode,
                  onOpenFile: _pickAndOpenFile,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onBack: widget.onBack,
                  renderingMode: widget.initialMediaUri == null
                      ? null
                      : _renderingMode,
                ),
                DefaultAppPromptBanner(
                  service: ref.read(defaultAppPromptProvider),
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
                            controls: (VideoState state) =>
                                VideoControlsOverlay(
                                  title: _titleFor(_playingUri),
                                  fullscreen: state.isFullscreen(),
                                  playlist: _playback.playlist,
                                  playlistStream: _playback.playlistStream,
                                  onPrevious: _previousVideo,
                                  onNext: _nextVideo,
                                  inspectorMode: _inspectorMode,
                                  inspectorBuilder: (mode, uri) =>
                                      PlayerInspector(
                                        playback: _playback,
                                        uri: uri ?? _playingUri,
                                        renderingMode: _renderingMode,
                                        mode: mode,
                                        onModeChanged: (value) =>
                                            _inspectorMode.value = value,
                                        onClose: () =>
                                            _inspectorMode.value = null,
                                      ),
                                  controls: _buildPlayerControls(
                                    onToggleFullscreen: state.toggleFullscreen,
                                  ),
                                  onExit: state.exitFullscreen,
                                  bindings: _fullscreenShortcuts(state),
                                ),
                          )
                        : _EmptyPlayer(
                            error: error,
                            playlist: _playback.playlist,
                            playlistStream: _playback.playlistStream,
                            onPrevious: _previousVideo,
                            onNext: _nextVideo,
                          ),
                  ),
                ),
              ],
            ),
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
    onShowInfo: _toggleInfo,
    tracks: _playback.tracks,
    tracksStream: _playback.tracksStream,
    onSetTrack: _playback.setTrack,
    onLoadSubtitleFile: _pickSubtitleFile,
    onSeekBy: _playback.seekBy,
    onPrevious: _previousVideo,
    onNext: _nextVideo,
    onToggleFullscreen: onToggleFullscreen,
  );

  String _titleFor(String? uri) {
    if (uri == null) {
      return 'VPFL';
    }
    final List<String> segments = Uri.parse(uri).pathSegments;
    // Uri.pathSegments is already decoded; decoding again rejects some
    // Unicode filenames.
    return segments.isEmpty ? 'VPFL' : segments.last;
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer({
    required this.error,
    required this.playlist,
    required this.playlistStream,
    required this.onPrevious,
    required this.onNext,
  });

  final String? error;
  final Playlist playlist;
  final Stream<Playlist> playlistStream;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

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
          if (error != null) ...[
            const SizedBox(height: 24),
            StreamBuilder<Playlist>(
              stream: playlistStream,
              initialData: playlist,
              builder: (context, snapshot) {
                final queue = snapshot.data ?? playlist;
                if (queue.medias.length < 2) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: queue.index > 0 ? onPrevious : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      label: const Text('Previous video'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: queue.index < queue.medias.length - 1
                          ? onNext
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Next video'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
