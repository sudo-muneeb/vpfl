import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;

import 'media_format_policy.dart';
import 'lifecycle_trace.dart';
import 'playback_open_coordinator.dart';
import 'queue_progression.dart';

/// Owns the single foreground media player session.
class PlaybackService {
  PlaybackService()
    : _player = Player(
        configuration: const PlayerConfiguration(libass: true, title: 'VPFL'),
      ) {
    _nativeErrorSubscription = _player.stream.error.listen((message) {
      stderr.writeln('VPFL playback error: $message');
      _errorController.add(message);
    });
    _nativePlaylistSubscription = _player.stream.playlist.listen((playlist) {
      if (_directoryQueue == null && !_playlistController.isClosed) {
        _playlistController.add(playlist);
      }
    });
    _completionSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        unawaited(_onCompleted());
      } else {
        // Seeking or pressing Play at EOF starts another playthrough of the
        // same source without selecting a new queue index.
        _handledCompletionGeneration = -1;
      }
    });
    LifecycleTrace.event(
      'player.create',
      session: sessionId,
      detail: 'object=${identityHashCode(_player)}',
    );
  }

  static int _nextSessionId = 0;
  final int sessionId = ++_nextSessionId;

  final Player _player;
  late final StreamSubscription<String> _nativeErrorSubscription;
  final StreamController<Playlist> _playlistController =
      StreamController<Playlist>.broadcast(sync: true);
  late final StreamSubscription<Playlist> _nativePlaylistSubscription;
  late final StreamSubscription<bool> _completionSubscription;
  final QueueProgression _progression = QueueProgression();
  final StreamController<bool> _shuffleController =
      StreamController<bool>.broadcast(sync: true);
  final StreamController<PlaylistMode> _playlistModeController =
      StreamController<PlaylistMode>.broadcast(sync: true);
  final StreamController<String> _errorController =
      StreamController<String>.broadcast(sync: true);
  final StreamController<int> _sourceOpenController =
      StreamController<int>.broadcast(sync: true);
  Playlist? _directoryQueue;
  final PlaybackOpenCoordinator _openCoordinator = PlaybackOpenCoordinator();
  late final VideoController _videoController = _createVideoController();
  bool _videoControllerCreated = false;

  VideoController _createVideoController() {
    _videoControllerCreated = true;
    LifecycleTrace.event('video_controller.create', session: sessionId);
    return VideoController(_player);
  }

  Future<void>? _disposeFuture;
  bool _closed = false;
  int _requestGeneration = 0;
  int _handledCompletionGeneration = -1;
  bool _sourceReady = false;

  /// The video surface controller consumed by the player UI.
  VideoController get videoController => _videoController;

  /// Whether the current item is playing.
  bool get isPlaying => _player.state.playing;

  /// Whether the current media reached its natural end.
  bool get isCompleted => _player.state.completed;

  /// The current playback position.
  Duration get position => _player.state.position;

  /// The loaded media duration.
  Duration get duration => _player.state.duration;

  /// Whether mpv has produced video dimensions for the current source.
  bool get hasVideoOutput =>
      (_player.state.width ?? 0) > 0 && (_player.state.height ?? 0) > 0;

  /// Current playback rate.
  double get rate => _player.state.rate;

  /// Current volume from 0 to 100.
  double get volume => _player.state.volume;

  /// Whether queue shuffle is enabled.
  bool get shuffle => _progression.shuffle;

  /// Current playlist repeat behavior.
  PlaylistMode get playlistMode => _progression.repeat;
  bool get canNext => _progression.canNext;
  bool get canPrevious => _progression.canPrevious;

  /// Current queue and its selected index.
  Playlist get playlist => _directoryQueue ?? _player.state.playlist;

  /// Available audio, subtitle, and video tracks for the current media.
  Tracks get tracks => _player.state.tracks;

  VideoParams get videoParams => _player.state.videoParams;
  AudioParams get audioParams => _player.state.audioParams;

  /// Currently selected tracks.
  Track get selectedTracks => _player.state.track;

  /// Emits play state changes from the playback engine.
  Stream<bool> get playingStream => _player.stream.playing;

  /// Emits position changes from the playback engine.
  Stream<Duration> get positionStream => _player.stream.position;

  /// Emits duration changes from the playback engine.
  Stream<Duration> get durationStream => _player.stream.duration;

  /// Emits playback-rate changes.
  Stream<double> get rateStream => _player.stream.rate;

  /// Emits volume changes.
  Stream<double> get volumeStream => _player.stream.volume;

  /// Emits shuffle-state changes.
  Stream<bool> get shuffleStream => _shuffleController.stream;

  /// Emits playlist repeat behavior changes.
  Stream<PlaylistMode> get playlistModeStream => _playlistModeController.stream;

  /// Emits queue changes and the active queue index.
  Stream<Playlist> get playlistStream => _playlistController.stream;

  /// Decoder/open errors reported asynchronously by media_kit.
  Stream<String> get errorStream => _errorController.stream;

  /// Emits when a selected source actually starts opening, including replays.
  Stream<int> get sourceOpenStream => _sourceOpenController.stream;

  /// Uses libmpv's null sink for headless video tests with no sound device.
  /// Audio tracks remain discoverable for codec checks in [tracks].
  Future<void> useNullAudioOutput() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('ao', 'null');
    }
  }

  /// Emits available track changes for the active media.
  Stream<Tracks> get tracksStream => _player.stream.tracks;
  Stream<VideoParams> get videoParamsStream => _player.stream.videoParams;
  Stream<AudioParams> get audioParamsStream => _player.stream.audioParams;

  /// Native-only diagnostic, queried when the inspector is visible.
  Future<String?> hardwareDecoder() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return null;
    try {
      final value = await platform.getProperty('hwdec-current');
      return value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  /// Emits selected track changes.
  Stream<Track> get selectedTracksStream => _player.stream.track;

  /// Opens and starts playing a media URI.
  Future<void> open(String uri) {
    _rejectUnsupportedLocalUri(uri);
    final request = ++_requestGeneration;
    _sourceReady = false;
    return _openQueueSelection(Playlist([Media(uri)]), request);
  }

  void _rejectUnsupportedLocalUri(String uri) {
    final source = Uri.tryParse(uri);
    if (source == null) throw UnsupportedMediaException();
    if (source.scheme.isNotEmpty && source.scheme != 'file') return;
    final filePath = source.scheme == 'file' ? source.toFilePath() : uri;
    if (!MediaFormatPolicy.mayOpenExplicitly(filePath)) {
      LifecycleTrace.event(
        'media.open.failed',
        session: sessionId,
        detail: 'reason=unsupported-or-invalid',
      );
      throw UnsupportedMediaException();
    }
  }

  Future<void> _openPlayer(Playable media, String uri) async {
    final name = Uri.tryParse(uri)?.pathSegments.lastOrNull ?? 'media';
    LifecycleTrace.event(
      'player.open.begin',
      session: sessionId,
      detail: 'file=${Uri.encodeComponent(name)}',
    );
    await _player.open(media);
    LifecycleTrace.event('player.open.complete', session: sessionId);
  }

  Future<void> _openQueueSelection(Playlist queue, int generation) {
    return _enqueueOpen(() async {
      if (_closed || generation != _requestGeneration) return;
      _setQueue(queue);
      final media = queue.medias[queue.index];
      _sourceOpenController.add(generation);
      await _openPlayer(media, media.uri);
      if (!_closed && generation == _requestGeneration) _sourceReady = true;
    });
  }

  void _setQueue(Playlist queue) {
    _directoryQueue = queue;
    _progression.reset(queue.medias.length, queue.index);
    _playlistController.add(queue);
    _shuffleController.add(_progression.shuffle);
  }

  Future<void> _onCompleted() async {
    final generation = _requestGeneration;
    if (_closed ||
        !_sourceReady ||
        _handledCompletionGeneration == generation) {
      return;
    }
    // A damaged file can signal EOF after yielding a few frames. Only
    // advance when playback reached the source's advertised duration.
    await Future<void>.delayed(Duration.zero);
    if (_closed ||
        !_sourceReady ||
        generation != _requestGeneration ||
        _handledCompletionGeneration == generation ||
        !_player.state.completed ||
        duration <= Duration.zero ||
        position + const Duration(milliseconds: 250) < duration) {
      return;
    }
    _handledCompletionGeneration = generation;
    if (_progression.repeat == PlaylistMode.none && !_progression.canNext) {
      return;
    }
    final transition = _navigate(_progression.complete);
    final transitionGeneration = _requestGeneration;
    try {
      await transition;
    } on Object catch (error, stackTrace) {
      stderr.writeln('VPFL automatic queue open failed: $error\n$stackTrace');
      if (_closed || transitionGeneration != _requestGeneration) return;
      if (!_errorController.isClosed) _errorController.add(error.toString());
    }
  }

  Future<void> _enqueueOpen(Future<void> Function() operation) => _closed
      ? Future<void>.error(StateError('Player is closed'))
      : _openCoordinator.run(operation);

  void _clearDirectoryQueue() {
    if (_directoryQueue == null) return;
    _directoryQueue = null;
    _sourceReady = false;
    _progression.clear();
    _shuffleController.add(false);
    if (!_playlistController.isClosed) {
      _playlistController.add(_player.state.playlist);
    }
  }

  /// Opens nearby video files as a queue so edge controls can navigate them.
  /// A file picker grant may only cover one file; in that case open it alone.
  Future<void> openWithDirectory(String uri) async {
    if (_closed) throw StateError('Player is closed');
    _rejectUnsupportedLocalUri(uri);
    final request = ++_requestGeneration;
    _sourceReady = false;
    final source = Uri.tryParse(uri);
    if (source == null || source.scheme != 'file') {
      return open(uri);
    }
    final selected = source.toFilePath();
    FileSystemEntityType selectedType;
    try {
      selectedType = (await File(selected).stat()).type;
    } on FileSystemException {
      selectedType = FileSystemEntityType.notFound;
    }
    if (selectedType != FileSystemEntityType.file) {
      LifecycleTrace.event(
        'media.open.failed',
        session: sessionId,
        detail: 'reason=unsupported-or-invalid',
      );
      throw UnsupportedMediaException();
    }
    final siblings = <String>[];
    try {
      await for (final entity in Directory(
        path.dirname(selected),
      ).list(followLinks: false)) {
        if (siblings.length >= 2000) break;
        if (entity is File &&
            MediaFormatPolicy.mayScan(entity.path) &&
            await MediaFormatPolicy.hasTransportStreamSignature(entity)) {
          siblings.add(entity.path);
        }
      }
    } on FileSystemException {
      if (request != _requestGeneration || _closed) return;
      return _openQueueSelection(Playlist([Media(uri)]), request);
    }
    if (request != _requestGeneration || _closed) return;
    if (!siblings.contains(selected)) siblings.add(selected);
    if (siblings.length < 2) {
      return _openQueueSelection(Playlist([Media(uri)]), request);
    }
    siblings.sort(
      (a, b) => path
          .basename(a)
          .toLowerCase()
          .compareTo(path.basename(b).toLowerCase()),
    );
    final queue = Playlist(
      siblings.map((file) => Media(Uri.file(file).toString())).toList(),
      index: siblings.indexOf(selected),
    );
    // Keep the directory for manual next/previous navigation. Passing the
    // entire queue to mpv makes it auto-skip a file that fails to decode.
    return _openQueueSelection(queue, request);
  }

  /// Opens a queue and starts at [startIndex].
  Future<void> openQueue(List<String> uris, {int startIndex = 0}) {
    if (uris.isEmpty) {
      throw ArgumentError.value(uris, 'uris', 'Queue cannot be empty.');
    }
    RangeError.checkValidIndex(startIndex, uris, 'startIndex');
    for (final uri in uris) {
      _rejectUnsupportedLocalUri(uri);
    }
    final Playlist queue = Playlist(
      uris.map(Media.new).toList(growable: false),
      index: startIndex,
    );
    final request = ++_requestGeneration;
    _sourceReady = false;
    return _openQueueSelection(queue, request);
  }

  /// Toggles playback.
  Future<void> playOrPause() async {
    LifecycleTrace.event(
      isPlaying ? 'player.pause' : 'player.play',
      session: sessionId,
    );
    await _player.playOrPause();
  }

  /// Seeks to [position].
  Future<void> seek(Duration position) => _player.seek(position);

  /// Seeks relative to the current position, clamped to the media duration.
  Future<void> seekBy(Duration offset) {
    final Duration target = position + offset;
    final Duration clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    return _player.seek(clamped);
  }

  /// Moves to the next item when the queue contains multiple items.
  Future<void> next() async {
    if (_closed || !_progression.canNext) return;
    await _navigate(_progression.next);
  }

  /// Moves to the previous item when the queue contains multiple items.
  Future<void> previous() async {
    if (_closed || !_progression.canPrevious) return;
    await _navigate(_progression.previous);
  }

  Future<void> _navigate(int? Function() select) {
    final request = ++_requestGeneration;
    _sourceReady = false;
    return _enqueueOpen(() async {
      if (_closed || request != _requestGeneration) return;
      final queue = _directoryQueue;
      if (queue == null) return;
      final index = select();
      if (index == null) return;
      final media = queue.medias[index];
      _directoryQueue = Playlist(queue.medias, index: index);
      _playlistController.add(_directoryQueue!);
      _sourceOpenController.add(request);
      await _openPlayer(media, media.uri);
      if (!_closed && request == _requestGeneration) _sourceReady = true;
    });
  }

  /// Sets volume, clamped to media_kit's 0–100 range.
  Future<void> setVolume(double value) =>
      _player.setVolume(value.clamp(0, 100));

  /// Toggles between muted and full volume.
  Future<void> toggleMute() => setVolume(volume == 0 ? 100 : 0);

  /// Sets playback speed.
  Future<void> setRate(double value) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Playback rate must be positive.',
      );
    }
    return _player.setRate(value);
  }

  /// Toggles shuffle; a one-item queue always remains unshuffled.
  Future<void> setShuffle(bool value) async {
    _progression.setShuffle(value);
    _shuffleController.add(_progression.shuffle);
    if (_directoryQueue case final queue?) _playlistController.add(queue);
  }

  /// Sets repeat behavior for the current queue.
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    _progression.repeat = mode;
    _playlistModeController.add(mode);
    if (_directoryQueue case final queue?) _playlistController.add(queue);
  }

  /// Captures the current frame using the playback engine.
  Future<Uint8List?> screenshot() =>
      _player.screenshot(format: 'image/png', includeLibassSubtitles: true);

  /// Selects a video, audio, or subtitle track.
  Future<void> setTrack(Object track) => switch (track) {
    VideoTrack value => _player.setVideoTrack(value),
    AudioTrack value => _player.setAudioTrack(value),
    SubtitleTrack value => _player.setSubtitleTrack(value),
    _ => Future<void>.error(ArgumentError.value(track, 'track')),
  };

  /// Adds and selects a local SRT, ASS, SSA, or WebVTT subtitle track.
  Future<void> loadSubtitleFile(String filePath) async {
    if (!await File(filePath).exists()) {
      throw FileSystemException('Subtitle file does not exist', filePath);
    }
    final extension = path
        .extension(filePath)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!MediaFormatPolicy.supportedSubtitleExtensions.contains(extension)) {
      throw ArgumentError.value(
        filePath,
        'filePath',
        'Unsupported subtitle format',
      );
    }
    await _player.setSubtitleTrack(
      SubtitleTrack.uri(
        Uri.file(filePath).toString(),
        title: path.basename(filePath),
      ),
    );
  }

  /// Stops the foreground session while retaining the one player for reuse.
  Future<void> stop() async {
    if (_closed) return;
    ++_requestGeneration;
    _sourceReady = false;
    _clearDirectoryQueue();
    LifecycleTrace.event('player.stop.begin', session: sessionId);
    final request = _requestGeneration;
    await _openCoordinator.cancelPending();
    if (request == _requestGeneration && !_closed) await _player.stop();
    LifecycleTrace.event('player.stop.complete', session: sessionId);
  }

  /// Stops a failed source without discarding its directory navigation queue.
  Future<void> stopFailedMedia() {
    ++_requestGeneration;
    _sourceReady = false;
    return _enqueueOpen(() => _player.stop());
  }

  /// Releases the player; media_kit releases VideoController via its callback.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    LifecycleTrace.event('player.dispose.begin', session: sessionId);
    _closed = true;
    ++_requestGeneration;
    _sourceReady = false;
    await _openCoordinator.close();
    if (_videoControllerCreated) {
      LifecycleTrace.event(
        'video_controller.dispose.begin',
        session: sessionId,
      );
    }
    await _player.dispose();
    await _nativeErrorSubscription.cancel();
    await _nativePlaylistSubscription.cancel();
    await _completionSubscription.cancel();
    await _playlistController.close();
    await _shuffleController.close();
    await _playlistModeController.close();
    await _errorController.close();
    await _sourceOpenController.close();
    if (_videoControllerCreated) {
      LifecycleTrace.event(
        'video_controller.dispose.complete',
        session: sessionId,
      );
    }
    LifecycleTrace.event('player.dispose.complete', session: sessionId);
  }
}

class UnsupportedMediaException implements Exception {
  @override
  String toString() => 'VPFL could not open this file.';
}
