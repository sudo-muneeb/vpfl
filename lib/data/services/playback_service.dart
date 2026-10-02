import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Owns the single foreground media player session.
class PlaybackService {
  PlaybackService()
    : _player = Player(
        configuration: const PlayerConfiguration(libass: true, title: 'VPFL'),
      );

  final Player _player;
  late final VideoController _videoController = VideoController(_player);

  /// The video surface controller consumed by the player UI.
  VideoController get videoController => _videoController;

  /// Whether the current item is playing.
  bool get isPlaying => _player.state.playing;

  /// The current playback position.
  Duration get position => _player.state.position;

  /// The loaded media duration.
  Duration get duration => _player.state.duration;

  /// Emits play state changes from the playback engine.
  Stream<bool> get playingStream => _player.stream.playing;

  /// Emits position changes from the playback engine.
  Stream<Duration> get positionStream => _player.stream.position;

  /// Emits duration changes from the playback engine.
  Stream<Duration> get durationStream => _player.stream.duration;

  /// Opens and starts playing a media URI.
  Future<void> open(String uri) => _player.open(Media(uri));

  /// Toggles playback.
  Future<void> playOrPause() => _player.playOrPause();

  /// Seeks to [position].
  Future<void> seek(Duration position) => _player.seek(position);

  /// Releases the media player and its native resources.
  Future<void> dispose() => _player.dispose();
}
