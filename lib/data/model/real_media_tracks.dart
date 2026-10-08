import 'package:media_kit/media_kit.dart';

/// Streams in the file, excluding media_kit's selection options and cover art.
class RealMediaTracks {
  RealMediaTracks(Tracks tracks)
    : video = tracks.video
          .where(
            (track) =>
                !_selectionOption(track.id) &&
                track.image != true &&
                track.albumart != true,
          )
          .toList(growable: false),
      audio = tracks.audio
          .where((track) => !_selectionOption(track.id))
          .toList(growable: false),
      subtitle = tracks.subtitle
          .where((track) => !_selectionOption(track.id))
          .toList(growable: false);

  final List<VideoTrack> video;
  final List<AudioTrack> audio;
  final List<SubtitleTrack> subtitle;

  VideoTrack? activeVideo(String selectedId) {
    if (selectedId == 'no') return null;
    for (final track in video) {
      if (track.id == selectedId) return track;
    }
    for (final track in video) {
      if (track.isDefault == true) return track;
    }
    return video.firstOrNull;
  }

  AudioTrack? activeAudio(String selectedId) {
    if (selectedId == 'no') return null;
    for (final track in audio) {
      if (track.id == selectedId) return track;
    }
    for (final track in audio) {
      if (track.isDefault == true) return track;
    }
    return audio.firstOrNull;
  }

  static bool _selectionOption(String id) => id == 'auto' || id == 'no';
}

String? mediaCodec(String? codec) {
  if (codec == null || codec.isEmpty) return null;
  return switch (codec.toLowerCase()) {
    'h264' => 'H.264',
    'hevc' || 'h265' => 'H.265',
    'av1' => 'AV1',
    'vp9' => 'VP9',
    'vp8' => 'VP8',
    'aac' => 'AAC',
    'opus' => 'Opus',
    _ => codec.toUpperCase(),
  };
}

String? mediaResolution(int? width, int? height) =>
    width != null && width > 0 && height != null && height > 0
    ? '$width × $height'
    : null;

String? mediaTechnicalSummary(
  String? codec,
  int? width,
  int? height, {
  double? fps,
}) {
  final values = <String>[
    ?mediaCodec(codec),
    ?mediaResolution(width, height),
    if (fps != null && fps.isFinite && fps > 0)
      '${fps.toStringAsFixed(fps == fps.roundToDouble() ? 0 : 2)} fps',
  ];
  return values.isEmpty ? null : values.join(' · ');
}
