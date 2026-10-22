import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;

import '../model/real_media_tracks.dart';
import 'media_source_identity.dart';

/// The fields shown for one explicit Details request. Nothing is cached.
class MediaMetadata {
  const MediaMetadata({
    required this.fileName,
    required this.absolutePath,
    required this.sizeBytes,
    required this.modified,
    required this.duration,
    required this.container,
    required this.video,
  });

  final String fileName;
  final String absolutePath;
  final int sizeBytes;
  final DateTime modified;
  final Duration? duration;
  final String? container;
  final List<VideoStreamMetadata> video;
}

class VideoStreamMetadata {
  const VideoStreamMetadata({
    this.codec,
    this.width,
    this.height,
    this.frameRate,
  });

  final String? codec;
  final int? width;
  final int? height;
  final double? frameRate;
}

/// A coherent snapshot of one media_kit player's public and native state.
class MediaBackendSnapshot {
  const MediaBackendSnapshot({
    required this.tracks,
    required this.duration,
    required this.videoParams,
    this.selectedVideoId = 'auto',
    this.container,
  });

  final Tracks tracks;
  final Duration duration;
  final VideoParams videoParams;
  final String selectedVideoId;
  final String? container;
}

/// A cancellation signal owned by a single Details interaction.
class MetadataCancellation {
  final Completer<void> _canceled = Completer<void>();

  bool get isCanceled => _canceled.isCompleted;
  Future<void> get whenCanceled => _canceled.future;

  void cancel() {
    if (!_canceled.isCompleted) _canceled.complete();
  }

  void throwIfCanceled() {
    if (isCanceled) throw const MetadataCanceledException();
  }
}

class MetadataCanceledException implements Exception {
  const MetadataCanceledException();
}

/// A disposable, audio/video-output-free inspection session.
abstract class MetadataInspectionSession {
  Future<MediaBackendSnapshot> inspect(
    String uri,
    MetadataCancellation cancellation,
  );

  Future<void> dispose();
}

/// Reads metadata only after a user requests Details.
class MediaMetadataService {
  MediaMetadataService({
    this.activeUri,
    this.activeSnapshot,
    MetadataInspectionSession Function()? createSession,
    this.requestTimeout = const Duration(seconds: 20),
    this.disposeTimeout = const Duration(seconds: 5),
  }) : _createSession = createSession ?? MediaKitInspectionSession.new;

  final String? Function()? activeUri;
  final Future<MediaBackendSnapshot?> Function(String)? activeSnapshot;
  final MetadataInspectionSession Function() _createSession;
  final Duration requestTimeout;
  final Duration disposeTimeout;
  MetadataCancellation? _currentRequest;
  Future<void> _inspectionTail = Future<void>.value();

  Future<MediaMetadata> inspect(
    String filePath, {
    MetadataCancellation? cancellation,
  }) async {
    final request = cancellation ?? MetadataCancellation();
    _currentRequest?.cancel();
    _currentRequest = request;
    try {
      final file = File(filePath).absolute;
      final stat = await file.stat().timeout(const Duration(seconds: 5));
      request.throwIfCanceled();
      if (stat.type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Video file is missing or inaccessible',
          file.path,
        );
      }
      final uri = canonicalMediaUri(file.path);
      final MediaBackendSnapshot backend;
      final readActiveUri = activeUri;
      final readActiveSnapshot = activeSnapshot;
      if (readActiveSnapshot != null &&
          readActiveUri != null &&
          readActiveUri() == uri) {
        final snapshot = await readActiveSnapshot(uri).timeout(requestTimeout);
        request.throwIfCanceled();
        if (snapshot == null) {
          throw StateError('The playing video changed while reading details.');
        }
        backend = snapshot;
      } else {
        final previous = _inspectionTail;
        final finished = Completer<void>();
        _inspectionTail = finished.future;
        try {
          await previous;
          request.throwIfCanceled();
          final session = _createSession();
          try {
            backend = await session
                .inspect(uri, request)
                .timeout(requestTimeout);
          } on Object {
            request.cancel();
            rethrow;
          } finally {
            await session.dispose().timeout(disposeTimeout);
          }
        } finally {
          finished.complete();
        }
      }
      request.throwIfCanceled();
      final tracks = RealMediaTracks(backend.tracks);
      final primaryVideo = tracks.activeVideo(backend.selectedVideoId);
      final orderedVideo = [
        ?primaryVideo,
        for (final track in tracks.video)
          if (!identical(track, primaryVideo)) track,
      ];
      return MediaMetadata(
        fileName: path.basename(file.path),
        absolutePath: file.path,
        sizeBytes: stat.size,
        modified: stat.modified,
        duration: backend.duration > Duration.zero ? backend.duration : null,
        container: backend.container,
        video: [
          for (final track in orderedVideo)
            VideoStreamMetadata(
              codec: mediaCodec(track.codec),
              width:
                  track.w ??
                  (identical(track, primaryVideo)
                      ? backend.videoParams.w
                      : null),
              height:
                  track.h ??
                  (identical(track, primaryVideo)
                      ? backend.videoParams.h
                      : null),
              frameRate:
                  track.fps != null && track.fps!.isFinite && track.fps! > 0
                  ? track.fps
                  : null,
            ),
        ],
      );
    } finally {
      if (identical(_currentRequest, request)) _currentRequest = null;
    }
  }
}

/// Uses a separate mpv player without a controller, texture, or playback.
class MediaKitInspectionSession implements MetadataInspectionSession {
  MediaKitInspectionSession()
    : _player = Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          muted: true,
          title: 'VPFL media inspection',
        ),
      );

  final Player _player;

  @override
  Future<MediaBackendSnapshot> inspect(
    String uri,
    MetadataCancellation cancellation,
  ) async {
    final ready = Completer<void>();
    String? error;
    bool hasTracks(Tracks tracks) {
      final real = RealMediaTracks(tracks);
      return real.video.isNotEmpty || real.audio.isNotEmpty;
    }

    void checkReady() {
      if (hasTracks(_player.state.tracks) &&
          _player.state.duration > Duration.zero &&
          !ready.isCompleted) {
        ready.complete();
      }
    }

    final tracksSubscription = _player.stream.tracks.listen(
      (_) => checkReady(),
    );
    final durationSubscription = _player.stream.duration.listen(
      (_) => checkReady(),
    );
    final errorSubscription = _player.stream.error.listen((message) {
      error = message;
      if (!ready.isCompleted) ready.complete();
    });
    try {
      cancellation.throwIfCanceled();
      await _player
          .open(Media(uri), play: false)
          .timeout(const Duration(seconds: 5));
      checkReady();
      var timedOut = false;
      if (!ready.isCompleted && error == null) {
        try {
          await Future.any([ready.future, cancellation.whenCanceled])
              .timeout(const Duration(seconds: 10));
        } on TimeoutException {
          // A valid stream may have no reported duration. Keep its available
          // properties, but never wait indefinitely for an absent value.
          timedOut = true;
        }
      }
      cancellation.throwIfCanceled();
      if (error != null) throw StateError('Could not inspect video: $error');
      if (!hasTracks(_player.state.tracks)) {
        if (timedOut) throw TimeoutException('No media streams became ready.');
        throw StateError(
          'The file contains no readable audio or video streams.',
        );
      }
      String? container;
      final platform = _player.platform;
      if (platform is NativePlayer) {
        try {
          container = await platform
              .getProperty('file-format')
              .timeout(const Duration(seconds: 3));
        } on Object {
          // Container naming is optional in older mpv builds.
        }
      }
      cancellation.throwIfCanceled();
      return MediaBackendSnapshot(
        tracks: _player.state.tracks,
        duration: _player.state.duration,
        videoParams: _player.state.videoParams,
        selectedVideoId: _player.state.track.video.id,
        container: container,
      );
    } finally {
      await tracksSubscription.cancel();
      await durationSubscription.cancel();
      await errorSubscription.cancel();
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
