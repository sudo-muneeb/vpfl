import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/services/playback_service.dart';

/// Evidence captured synchronously when media_kit reports mpv's EOF property.
class CompletionEvent {
  const CompletionEvent({
    required this.generation,
    required this.queueSource,
    required this.playerSource,
    required this.position,
    required this.duration,
  });

  final int generation;
  final String? queueSource;
  final String? playerSource;
  final Duration position;
  final Duration duration;
}

class CompletionAttempt {
  const CompletionAttempt(this.source, this.generation, this.eventCount);

  final String source;
  final int generation;
  final int eventCount;

  bool accepts(CompletionEvent event) =>
      event.generation == generation &&
      event.queueSource == source &&
      event.playerSource == source &&
      event.duration > Duration.zero &&
      event.position + const Duration(milliseconds: 250) >= event.duration;

  bool reachedBy(Iterable<CompletionEvent> events) =>
      events.skip(eventCount).any(accepts);
}

class CompletionObserver {
  CompletionObserver(this._playback) {
    _completionSubscription = _playback.videoController.player.stream.completed
        .listen((completed) {
          if (!completed) return;
          final queue = _playback.playlist;
          final playerQueue = _playback.videoController.player.state.playlist;
          _events.add(
            CompletionEvent(
              generation: _playback.sourceGeneration,
              queueSource: _selectedSource(queue),
              playerSource: _selectedSource(playerQueue),
              position: _playback.position,
              duration: _playback.duration,
            ),
          );
        });
  }

  final PlaybackService _playback;
  final List<CompletionEvent> _events = [];
  late final StreamSubscription<bool> _completionSubscription;

  static String? _selectedSource(Playlist playlist) {
    final index = playlist.index;
    return index >= 0 && index < playlist.medias.length
        ? playlist.medias[index].uri
        : null;
  }

  CompletionAttempt begin(String source) {
    if (_selectedSource(_playback.playlist) != source ||
        _selectedSource(_playback.videoController.player.state.playlist) !=
            source) {
      throw StateError('Wrong source active before completion: $source');
    }
    return CompletionAttempt(
      source,
      _playback.sourceGeneration,
      _events.length,
    );
  }

  bool reached(CompletionAttempt attempt) => attempt.reachedBy(_events);

  Future<void> dispose() async {
    await _completionSubscription.cancel();
  }
}
