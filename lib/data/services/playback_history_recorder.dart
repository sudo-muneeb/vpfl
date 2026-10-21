import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../repositories/playback_history_repository.dart';
import 'playback_service.dart';
import 'thumbnail_service.dart';
import 'lifecycle_trace.dart';
import 'media_source_identity.dart';

/// Stores only sessions that reach the playing state and periodically saves
/// their resume position.
class PlaybackHistoryRecorder {
  /// Playback position before VPFL may keep a frame as artwork.
  static const Duration thumbnailAfter = Duration(seconds: 10);
  static const Duration saveInterval = Duration(seconds: 5);

  PlaybackHistoryRecorder({
    required PlaybackService playback,
    required this.history,
    required this.settings,
    this.thumbnails,
  }) : _playback = playback {
    LifecycleTrace.event(
      'stream.subscribe',
      session: playback.sessionId,
      detail: 'history=4',
    );
    _playlistSubscription = playback.playlistStream.listen(_onPlaylist);
    _playingSubscription = playback.playingStream.listen(_onPlaying);
    _positionSubscription = playback.positionStream.listen(_onPosition);
    _durationSubscription = playback.durationStream.listen(_onDuration);
    _position = playback.position;
    _duration = playback.duration;
    _onPlaylist(playback.playlist);
  }

  final PlaybackService _playback;
  final PlaybackHistoryRepository history;
  final SettingsRepository settings;
  final ThumbnailService? thumbnails;
  late final StreamSubscription<Playlist> _playlistSubscription;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  String? _uri;
  int? _queueIndex;
  int _sessionGeneration = 0;
  String? _recordedUri;
  String? _startingUri;
  int? _startingGeneration;
  Future<void>? _recordedStartWrite;
  String? _capturedUri;
  int _lastSavedPositionMs = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Future<void> _writes = Future<void>.value();
  Future<void>? _disposeFuture;
  final Set<Future<void>> _backgroundTasks = {};
  bool _disposed = false;

  void _track(Future<void> task) {
    final guarded = task.catchError((Object error, StackTrace stackTrace) {});
    _backgroundTasks.add(guarded);
    unawaited(guarded.whenComplete(() => _backgroundTasks.remove(guarded)));
  }

  void _onPlaylist(Playlist playlist) {
    final String? nextUri = playlist.medias.isEmpty
        ? null
        : canonicalMediaUri(playlist.medias[playlist.index].uri);
    final generation = _playback.sourceGeneration;
    if (nextUri == _uri &&
        playlist.index == _queueIndex &&
        generation == _sessionGeneration) {
      return;
    }
    _queueProgressSave();
    _uri = nextUri;
    _queueIndex = playlist.index;
    _sessionGeneration = generation;
    _recordedUri = null;
    _recordedStartWrite = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastSavedPositionMs = 0;
  }

  void _onPlaying(bool playing) {
    if (playing) {
      _track(_recordStarted());
    } else {
      _queueProgressSave();
    }
  }

  void _onPosition(Duration position) {
    _position = position;
    _maybeCaptureFrame(position);
    if (_recordedUri == null ||
        (position.inMilliseconds - _lastSavedPositionMs).abs() <
            saveInterval.inMilliseconds) {
      return;
    }
    _lastSavedPositionMs = position.inMilliseconds;
    _queueProgressSave();
  }

  /// Keeps a frame from active playback as artwork. It never seeks, and
  /// it runs once per session for each file that has no thumbnail yet.
  void _maybeCaptureFrame(Duration position) {
    final String? uri = _recordedUri;
    if (thumbnails == null ||
        uri == null ||
        uri == _capturedUri ||
        position < thumbnailAfter ||
        !_playback.isPlaying ||
        !uri.startsWith('file:')) {
      return;
    }
    _capturedUri = uri;
    LifecycleTrace.event('thumbnail.task.begin', session: _playback.sessionId);
    _track(_captureFrame(uri));
  }

  Future<void> _captureFrame(String uri) async {
    try {
      if (!await settings.getBool('historyEnabled', defaultValue: true)) return;
      if (_disposed) return;
      final ThumbnailService service = thumbnails!;
      final String path = Uri.parse(uri).toFilePath();
      if (await service.resolve(path) != null) return;
      if (_disposed) return;
      final frame = await _playback.screenshot();
      // The user may have switched media while the frame was being read.
      if (_disposed || frame == null || frame.isEmpty || _uri != uri) return;
      await service.captureFrame(path, frame);
    } on Object {
      // Artwork is optional; playback and history must not depend on it.
    } finally {
      LifecycleTrace.event('thumbnail.task.end', session: _playback.sessionId);
    }
  }

  void _onDuration(Duration duration) {
    _duration = duration;
  }

  Future<void> _recordStarted() async {
    if (_disposed) return;
    final String? uri = _uri;
    final generation = _sessionGeneration;
    if (uri == null ||
        uri == _recordedUri ||
        (uri == _startingUri && generation == _startingGeneration)) {
      return;
    }
    _startingUri = uri;
    _startingGeneration = generation;
    try {
      if (!await settings.getBool('historyEnabled', defaultValue: true) ||
          _disposed ||
          _uri != uri ||
          _sessionGeneration != generation) {
        return;
      }
      final startWrite = history.recordStarted(
        uri: uri,
        displayName: _displayName(uri),
        duration: _duration,
      );
      _recordedStartWrite = startWrite;
      _recordedUri = uri;
      await startWrite;
      if (_uri == uri && _sessionGeneration == generation) {
        _lastSavedPositionMs = _position.inMilliseconds;
      }
    } on Object {
      if (_uri == uri && _sessionGeneration == generation) {
        _recordedUri = null;
      }
    } finally {
      if (_startingUri == uri && _startingGeneration == generation) {
        _startingUri = null;
        _startingGeneration = null;
      }
    }
  }

  void _queueProgressSave() {
    final String? uri = _recordedUri;
    final startWrite = _recordedStartWrite;
    if (uri == null ||
        startWrite == null ||
        !_playback.canSaveProgressFor(_sessionGeneration)) {
      return;
    }
    final Duration position = _position;
    final Duration duration = _duration;
    _writes = _writes
        .then((_) async {
          try {
            await startWrite;
          } on Object {
            return;
          }
          if (!await settings.getBool('historyEnabled', defaultValue: true)) {
            return;
          }
          await history.saveProgress(
            uri: uri,
            position: position,
            duration: duration,
          );
        })
        .onError((Object error, StackTrace stackTrace) {});
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _queueProgressSave();
    await Future.wait([
      _playlistSubscription.cancel(),
      _playingSubscription.cancel(),
      _positionSubscription.cancel(),
      _durationSubscription.cancel(),
    ]);
    LifecycleTrace.event(
      'stream.cancel',
      session: _playback.sessionId,
      detail: 'history=4',
    );
    await Future.wait(_backgroundTasks.toList());
    await _writes;
  }

  static String _displayName(String uri) {
    final Uri? parsed = Uri.tryParse(uri);
    final String path = parsed?.path ?? uri;
    final List<String> segments = path
        .split('/')
        .where((String e) => e.isNotEmpty)
        .toList();
    // Uri.path is already decoded; decoding again breaks Unicode names.
    return segments.isEmpty ? uri : segments.last;
  }
}
