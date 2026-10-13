import 'dart:math';

import 'package:media_kit/media_kit.dart';

/// Index-based traversal of a VPFL queue. The media player receives one item.
class QueueProgression {
  QueueProgression({Random? random}) : _random = random ?? Random();

  final Random _random;
  int length = 0;
  int index = 0;
  bool shuffle = false;
  PlaylistMode repeat = PlaylistMode.none;
  List<int> _remaining = [];
  final Set<int> _seenInCycle = {};
  final List<int> _history = [];
  int _historyPosition = 0;

  void clear() {
    length = 0;
    index = 0;
    shuffle = false;
    _remaining.clear();
    _seenInCycle.clear();
    _history.clear();
    _historyPosition = 0;
  }

  void reset(int count, int selected) {
    assert(count > 0 && selected >= 0 && selected < count);
    length = count;
    index = selected;
    if (count < 2) shuffle = false;
    _seenInCycle
      ..clear()
      ..add(selected);
    _history
      ..clear()
      ..add(selected);
    _historyPosition = 0;
    _makeRemaining();
  }

  void setShuffle(bool enabled) {
    final value = enabled && length > 1;
    if (shuffle == value) return;
    shuffle = value;
    _discardForwardHistory();
    _makeRemaining();
  }

  bool get canPrevious => _historyPosition > 0 || (!shuffle && index > 0);

  bool get canNext =>
      length > 1 &&
      (_historyPosition < _history.length - 1 ||
          (shuffle
              ? _remaining.isNotEmpty || repeat == PlaylistMode.loop
              : index < length - 1 || repeat == PlaylistMode.loop));

  /// Natural completion repeats one; manual Next always moves to another item.
  int? complete() {
    if (length == 0) return null;
    if (repeat == PlaylistMode.single) return index;
    if (length == 1 && repeat == PlaylistMode.loop) return index;
    return next();
  }

  int? next() {
    if (!canNext) return null;
    if (_historyPosition < _history.length - 1) {
      index = _history[++_historyPosition];
      return index;
    }
    if (shuffle) {
      final newCycle = _remaining.isEmpty;
      if (newCycle) _makeNewCycle();
      index = _remaining.removeAt(0);
      if (newCycle) _seenInCycle.clear();
    } else {
      final wraps = index + 1 == length;
      index = wraps ? 0 : index + 1;
      if (wraps) _seenInCycle.clear();
    }
    _seenInCycle.add(index);
    _appendHistory(index);
    return index;
  }

  int? previous() {
    if (_historyPosition > 0) {
      index = _history[--_historyPosition];
      return index;
    }
    if (!shuffle && index > 0) {
      _history.insert(0, --index);
      return index;
    }
    return null;
  }

  void _makeRemaining() {
    _remaining = [
      for (var i = 0; i < length; i++)
        if (!_seenInCycle.contains(i)) i,
    ];
    if (shuffle) _remaining.shuffle(_random);
  }

  void _makeNewCycle() {
    _remaining = [for (var i = 0; i < length; i++) i]..shuffle(_random);
    if (length > 1 && _remaining.first == index) {
      final swap = 1 + _random.nextInt(length - 1);
      final first = _remaining[0];
      _remaining[0] = _remaining[swap];
      _remaining[swap] = first;
    }
  }

  void _discardForwardHistory() {
    _history.removeRange(_historyPosition + 1, _history.length);
  }

  void _appendHistory(int selected) {
    _discardForwardHistory();
    _history.add(selected);
    _historyPosition = _history.length - 1;
    if (_history.length > 256) {
      _history.removeAt(0);
      --_historyPosition;
    }
  }
}
