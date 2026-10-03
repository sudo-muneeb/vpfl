import 'dart:async';

/// Serializes source changes and drops requests superseded before they start.
class PlaybackOpenCoordinator {
  Future<void> _tail = Future<void>.value();
  int _generation = 0;

  Future<void> run(Future<void> Function() operation) {
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
