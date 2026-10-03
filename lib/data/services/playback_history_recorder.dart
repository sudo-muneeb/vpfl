import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../repositories/playback_history_repository.dart';
import 'playback_service.dart';

/// Stores only sessions that reach the playing state and periodically saves
/// their resume position.
class PlaybackHistoryRecorder {
  PlaybackHistoryRecorder({
    required PlaybackService playback,
    required this.history,
    required this.settings,
  }) : _playback = playback {
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
  late final StreamSubscription<Playlist> _playlistSubscription;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  String? _uri;
  String? _recordedUri;
  String? _startingUri;
  int _lastSavedPositionMs = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Future<void> _writes = Future<void>.value();
  Future<void>? _disposeFuture;

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
      unawaited(_recordStarted());
    }
  }

  void _onPlaying(bool playing) {
    if (playing) {
      unawaited(_recordStarted());
    } else {
      _queueProgressSave();
    }
  }

  void _onPosition(Duration position) {
    _position = position;
    if (_recordedUri == null ||
        (position.inMilliseconds - _lastSavedPositionMs).abs() < 5000) {
      return;
    }
    _lastSavedPositionMs = position.inMilliseconds;
    _queueProgressSave();
  }

  void _onDuration(Duration duration) {
    _duration = duration;
  }

  Future<void> _recordStarted() async {
    final String? uri = _uri;
    if (uri == null || uri == _recordedUri || uri == _startingUri) return;
    _startingUri = uri;
    if (!await settings.getBool('historyEnabled', defaultValue: true)) {
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
    _queueProgressSave();
    await Future.wait([
      _playlistSubscription.cancel(),
      _playingSubscription.cancel(),
      _positionSubscription.cancel(),
      _durationSubscription.cancel(),
    ]);
    await _writes;
  }

  static String _displayName(String uri) {
    final Uri? parsed = Uri.tryParse(uri);
    final String path = parsed?.path ?? uri;
    final List<String> segments = path
        .split('/')
        .where((String e) => e.isNotEmpty)
        .toList();
    return segments.isEmpty ? uri : Uri.decodeComponent(segments.last);
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
