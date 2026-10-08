import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/model/real_media_tracks.dart';

void main() {
  test('selection options do not count as media streams', () {
    final empty = RealMediaTracks(const Tracks());
    expect(empty.video, isEmpty);
    expect(empty.audio, isEmpty);
    expect(empty.subtitle, isEmpty);

    final one = RealMediaTracks(
      const Tracks(
        video: [
          VideoTrack('auto', null, null),
          VideoTrack('no', null, null),
          VideoTrack('1', null, null, codec: 'h264'),
        ],
        audio: [
          AudioTrack('auto', null, null),
          AudioTrack('no', null, null),
          AudioTrack('2', null, null, codec: 'aac'),
        ],
      ),
    );
    expect(one.video, hasLength(1));
    expect(one.audio, hasLength(1));
    expect(one.subtitle, isEmpty);
  });

  test('multiple streams retain external subtitles but exclude cover art', () {
    final tracks = RealMediaTracks(
      Tracks(
        video: const [
          VideoTrack('auto', null, null),
          VideoTrack('1', 'Cover', null, image: true),
          VideoTrack('2', 'Album art', null, albumart: true),
          VideoTrack('3', 'Main', null),
          VideoTrack('4', 'Alternate', null),
        ],
        audio: const [
          AudioTrack('auto', null, null),
          AudioTrack('1', 'English', 'eng'),
          AudioTrack('2', 'French', 'fra'),
        ],
        subtitle: [
          SubtitleTrack.auto(),
          SubtitleTrack.no(),
          const SubtitleTrack('3', 'Embedded', 'eng'),
          SubtitleTrack.uri('file:///tmp/example.srt', title: 'External'),
        ],
      ),
    );
    expect(tracks.video.map((track) => track.id), ['3', '4']);
    expect(tracks.audio, hasLength(2));
    expect(tracks.subtitle, hasLength(2));
    expect(tracks.subtitle.last.uri, isTrue);
  });

  test('technical summary omits unknown values', () {
    expect(mediaTechnicalSummary(null, null, null), isNull);
    expect(
      mediaTechnicalSummary('h264', 1920, 1080, fps: 30),
      'H.264 · 1920 × 1080 · 30 fps',
    );
  });

  test('active track follows selection and respects Off', () {
    final tracks = RealMediaTracks(
      const Tracks(
        video: [
          VideoTrack('auto', null, null),
          VideoTrack('1', null, null, codec: 'vp8', isDefault: true),
          VideoTrack('2', null, null, codec: 'h264'),
        ],
        audio: [
          AudioTrack('auto', null, null),
          AudioTrack('1', null, null, codec: 'aac'),
          AudioTrack('2', null, null, codec: 'opus'),
        ],
      ),
    );
    expect(tracks.activeVideo('auto')?.id, '1');
    expect(tracks.activeVideo('2')?.codec, 'h264');
    expect(tracks.activeVideo('no'), isNull);
    expect(tracks.activeAudio('2')?.codec, 'opus');
    expect(tracks.activeAudio('no'), isNull);
  });
}
