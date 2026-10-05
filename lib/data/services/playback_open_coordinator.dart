import 'dart:async';

/// Serializes source changes and drops requests superseded before they start.
class PlaybackOpenCoordinator {
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  bool _closed = false;

  /// Invalidates queued opens and waits for an in-flight open to finish.
  Future<void> cancelPending() {
    ++_generation;
    return _tail;
  }

  Future<void> close() {
    _closed = true;
    return cancelPending();
  }

  Future<void> run(Future<void> Function() operation) {
    if (_closed) return Future<void>.error(StateError('Player is closed'));
    final int generation = ++_generation;
    final Completer<void> result = Completer<void>();

    _tail = _tail.then((_) async {
      if (generation != _generation) {
        result.complete();
        return;
      }

      try {
        await operation();
        result.complete();
      } on Object catch (error, stackTrace) {
        if (generation == _generation) {
          result.completeError(error, stackTrace);
        } else {
          result.complete();
        }
      }
    });

    return result.future;
  }
}
