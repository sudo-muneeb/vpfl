import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/services/media_metadata_service.dart';
import 'package:vpfl/data/services/media_source_identity.dart';

const _snapshot = MediaBackendSnapshot(
  tracks: Tracks(
    video: [
      VideoTrack('auto', null, null),
      VideoTrack(
        '1',
        'Main picture',
        'eng',
        codec: 'h264',
        w: 1920,
        h: 1080,
        fps: 24,
      ),
      VideoTrack('no', null, null),
    ],
    audio: [
      AudioTrack('auto', null, null),
      AudioTrack(
        '2',
        null,
        'eng',
        codec: 'aac',
        channels: 'stereo',
        samplerate: 48000,
      ),
      AudioTrack('no', null, null),
    ],
  ),
  duration: Duration(minutes: 2),
  videoParams: VideoParams(),
  container: 'matroska',
);

class _FakeSession implements MetadataInspectionSession {
  _FakeSession(this.onInspect);

  final Future<MediaBackendSnapshot> Function(String, MetadataCancellation)
  onInspect;
  bool disposed = false;

  @override
  Future<MediaBackendSnapshot> inspect(
    String uri,
    MetadataCancellation cancellation,
  ) => onInspect(uri, cancellation);

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late Directory root;
  late File file;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vpfl-metadata-test-');
    file = File('${root.path}/a film.mkv');
    await file.writeAsBytes([1, 2, 3, 4]);
  });
  tearDown(() => root.delete(recursive: true));

  test('inspects one requested file and normalizes real tracks', () async {
    final sessions = <_FakeSession>[];
    final service = MediaMetadataService(
      createSession: () {
        final session = _FakeSession((uri, cancellation) async {
          expect(uri, canonicalMediaUri(file.path));
          expect(cancellation.isCanceled, false);
          return _snapshot;
        });
        sessions.add(session);
        return session;
      },
    );
    expect(sessions, isEmpty);

    final metadata = await service.inspect(file.path);

    expect(metadata.fileName, 'a film.mkv');
    expect(metadata.absolutePath, file.absolute.path);
    expect(metadata.sizeBytes, 4);
    expect(metadata.duration, const Duration(minutes: 2));
    expect(metadata.container, 'matroska');
    expect(metadata.video, hasLength(1));
    expect(metadata.video.single.codec, 'H.264');
    expect(metadata.video.single.width, 1920);
    expect(metadata.video.single.frameRate, 24);
    expect(sessions, hasLength(1));
    expect(sessions.single.disposed, true);
  });

  test('uses the foreground snapshot without creating an inspector', () async {
    var sessions = 0;
    var activeReads = 0;
    final service = MediaMetadataService(
      activeUri: () => canonicalMediaUri(file.path),
      activeSnapshot: (uri) async {
        activeReads += 1;
        expect(uri, canonicalMediaUri(file.path));
        return _snapshot;
      },
      createSession: () {
        sessions += 1;
        throw StateError('Inspector must not be created for active media');
      },
    );

    final result = await service.inspect(file.path);
    expect(result.video.single.codec, 'H.264');
    expect(activeReads, 1);
    expect(sessions, 0);
  });

  test(
    'rejects a switched foreground source rather than returning stale data',
    () async {
      final response = Completer<MediaBackendSnapshot?>();
      final service = MediaMetadataService(
        activeUri: () => canonicalMediaUri(file.path),
        activeSnapshot: (uri) => response.future,
        createSession: () =>
            throw StateError('Unexpected temporary inspection'),
      );
      final pending = service.inspect(file.path);
      await Future<void>.delayed(Duration.zero);
      response.complete(null);

      await expectLater(pending, throwsA(isA<StateError>()));
    },
  );

  test('new requests cancel and clean up the previous inspector', () async {
    final entered = Completer<void>();
    final sessions = <_FakeSession>[];
    final service = MediaMetadataService(
      createSession: () {
        final index = sessions.length;
        final session = _FakeSession((uri, cancellation) async {
          if (index == 0) {
            entered.complete();
            await cancellation.whenCanceled;
            throw const MetadataCanceledException();
          }
          return _snapshot;
        });
        sessions.add(session);
        return session;
      },
    );
    final first = service.inspect(file.path);
    await entered.future;
    final second = service.inspect(file.path);

    await expectLater(first, throwsA(isA<MetadataCanceledException>()));
    final metadata = await second;
    expect(metadata.fileName, 'a film.mkv');
    expect(sessions, hasLength(2));
    expect(sessions.every((session) => session.disposed), true);
  });

  test('missing files fail before a player is created', () async {
    var sessions = 0;
    final service = MediaMetadataService(
      createSession: () {
        sessions += 1;
        throw StateError('Unexpected player creation');
      },
    );

    await expectLater(
      service.inspect('${root.path}/missing.mkv'),
      throwsA(isA<FileSystemException>()),
    );
    expect(sessions, 0);
  });

  test(
    'selects the active real track over cover art and synthetic choices',
    () async {
      const multiple = MediaBackendSnapshot(
        tracks: Tracks(
          video: [
            VideoTrack('auto', null, null),
            VideoTrack('cover', null, null, image: true, codec: 'mjpeg'),
            VideoTrack('1', null, null, codec: 'vp9', w: 640, h: 360),
            VideoTrack(
              '2',
              null,
              null,
              codec: 'h264',
              w: 1280,
              h: 720,
              fps: 30000 / 1001,
            ),
            VideoTrack('no', null, null),
          ],
        ),
        duration: Duration(seconds: 8),
        videoParams: VideoParams(),
        selectedVideoId: '2',
      );
      final service = MediaMetadataService(
        createSession: () =>
            _FakeSession((uri, cancellation) async => multiple),
      );

      final details = await service.inspect(file.path);
      expect(details.video, hasLength(2));
      expect(details.video.first.codec, 'H.264');
      expect(details.video.first.width, 1280);
      expect(details.video.first.frameRate, closeTo(29.97, 0.01));
      expect(details.video.last.codec, 'VP9');
    },
  );

  test('failed and timed-out sessions are canceled and disposed', () async {
    final sessions = <_FakeSession>[];
    MetadataCancellation? timeoutRequest;
    final service = MediaMetadataService(
      requestTimeout: const Duration(milliseconds: 20),
      createSession: () {
        final index = sessions.length;
        final session = _FakeSession((uri, cancellation) {
          if (index == 0) return Future.error(StateError('backend failed'));
          timeoutRequest = cancellation;
          return Completer<MediaBackendSnapshot>().future;
        });
        sessions.add(session);
        return session;
      },
    );

    await expectLater(service.inspect(file.path), throwsA(isA<StateError>()));
    await expectLater(
      service.inspect(file.path),
      throwsA(isA<TimeoutException>()),
    );
    expect(sessions, hasLength(2));
    expect(sessions.every((session) => session.disposed), true);
    expect(timeoutRequest?.isCanceled, true);
  });

  test('repeated requests read changed file facts without a cache', () async {
    var sessions = 0;
    final service = MediaMetadataService(
      createSession: () {
        sessions += 1;
        return _FakeSession((uri, cancellation) async => _snapshot);
      },
    );
    expect((await service.inspect(file.path)).sizeBytes, 4);
    await file.writeAsBytes([1, 2, 3, 4, 5, 6]);
    expect((await service.inspect(file.path)).sizeBytes, 6);
    expect(sessions, 2);
  });
}
