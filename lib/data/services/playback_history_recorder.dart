import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../repositories/playback_history_repository.dart';
import 'playback_service.dart';
import 'thumbnail_service.dart';
import 'lifecycle_trace.dart';

/// Stores only sessions that reach the playing state and periodically saves
/// their resume position.
class PlaybackHistoryRecorder {
  /// Seconds of natural playback before VPFL may keep a frame as artwork.
  static const Duration thumbnailAfter = Duration(seconds: 10);

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
  String? _recordedUri;
  String? _startingUri;
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
        : _canonicalUri(playlist.medias[playlist.index].uri);
    if (nextUri == _uri) return;
    _queueProgressSave();
    _uri = nextUri;
    _recordedUri = null;
    _position = _playback.position;
    _duration = _playback.duration;
    _lastSavedPositionMs = 0;
    if (_playback.isPlaying) {
      _track(_recordStarted());
    }
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
        (position.inMilliseconds - _lastSavedPositionMs).abs() < 5000) {
      return;
    }
    _lastSavedPositionMs = position.inMilliseconds;
    _queueProgressSave();
  }

  /// Keeps the frame from natural playback as artwork. It never seeks, and
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
    if (uri == null || uri == _recordedUri || uri == _startingUri) return;
    _startingUri = uri;
    if (!await settings.getBool('historyEnabled', defaultValue: true) ||
        _disposed) {
      _startingUri = null;
      return;
    }

    _recordedUri = uri;
    try {
      await history.recordStarted(
        uri: uri,
        displayName: _displayName(uri),
        duration: _duration,
      );
      _lastSavedPositionMs = _position.inMilliseconds;
    } on Object {
      _recordedUri = null;
    } finally {
      if (_startingUri == uri) _startingUri = null;
    }
  }

  void _queueProgressSave() {
    final String? uri = _recordedUri;
    if (uri == null) return;
    final Duration position = _position;
    final Duration duration = _duration;
    _writes = _writes
        .then((_) async {
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

  static String _canonicalUri(String uri) {
    final Uri? parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.scheme == 'file') {
      return Uri.file(parsed.toFilePath()).normalizePath().toString();
    }
    if (parsed == null || parsed.scheme.isEmpty) {
      return Uri.file(File(uri).absolute.path).normalizePath().toString();
    }
    return uri;
  }
}
